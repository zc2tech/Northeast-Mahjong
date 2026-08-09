using Engine;
using Gee;

public class GameRenderView : View3D, IGameRenderer
{
    public GameRenderContext context { get; private set; }
    protected RenderTile[] tiles { get { return scene.tiles; } }
    protected RenderPlayer[] players { get { return scene.players; } }

    protected GameScene scene;  // Changed from private to protected for ReplayGameView access
    private RenderTile? mouse_down_tile;
    private ArrayList<TileSelectionGroup>? select_groups = null;

    private Sound hover_sound;

    private GameStartInfo game_start;
    private RoundStartInfo info;
    protected int observer_index;  // Changed from private to protected for ReplayGameView
    private int dealer_index;
    private Options options;
    private RoundScoreState score;
    private ServerSettings settings;
    private bool is_replay;

    private WorldCamera camera;
    private WorldObject target;
    protected WorldObject observe_object;  // Changed from private to protected for ReplayGameView

    public signal void game_loaded();
    private bool has_loaded = false;

    private float camera_save_timer = 0;
    private bool camera_settings_dirty = false;

    private bool is_paused = false;

    public GameRenderView(int observer_index, int dealer_index, GameStartInfo game_start, RoundStartInfo info, Options options, RoundScoreState score, ServerSettings settings, bool is_replay = false)
    {
        this.observer_index = observer_index;
        this.dealer_index = dealer_index;
        this.game_start = game_start;
        this.info = info;
        this.options = options;
        this.score = score;
        this.settings = settings;
        this.is_replay = is_replay;
    }

    public override void added()
    {
        // TODO: Improve this
        float tile_scale = 2.6f;
        RenderTile t = new RenderTile();
        world.add_object(t);
        Vec3 tile_size = t.obb.mul_scalar(tile_scale);
        world.remove_object(t);

        context = new GameRenderContext(game_start.timings, tile_scale, tile_size, observer_index, dealer_index, info.wall_index, settings.reveal_all_tiles == OnOffEnum.ON, is_replay);
        observer_index = observer_index != -1 ? observer_index : 0;

        scene = new GameScene(context, observer_index, options, store.audio_player, score);

        world.add_object(scene);

        var observer = scene.players[observer_index];
        observe_object = new WorldObject();
        observer.add_object(observe_object);

        observe_object.add_object(new WorldLight(){ intensity = 18, position = Vec3(  0, 20, 30) });
        observe_object.add_object(new WorldLight(){ intensity = 12, position = Vec3( 30, 10,  0) });
        observe_object.add_object(new WorldLight(){ intensity = 12, position = Vec3(-30, 10,  0) });
        observe_object.add_object(new WorldLight(){ intensity =  1, position = Vec3(  0,  8,  0) });
        // Add extra light to illuminate hand tiles (closer to player view)
        observe_object.add_object(new WorldLight(){ intensity = 10, position = Vec3(  0, 15, 15) });

        target = new WorldObject();
        observe_object.add_object(target);
        target.position = Vec3(0, 2, 0);

        camera = new TargetWorldCamera(target);
        observe_object.add_object(camera);
        world.active_camera = camera;
        camera.position = Vec3(0, 2, 4);
        camera.view_angle = 79;

        float camera_animation_time = 3;

        WorldObjectAnimation camera_animation = new WorldObjectAnimation(new AnimationTime.preset(camera_animation_time));
        camera_animation.do_absolute_position(new LinearPath3D(Vec3(0, options.camera_height, 10)));
        camera_animation.curve = new SCurve(0.5f);
        camera.animate(camera_animation, true);

        WorldObjectAnimation target_animation = new WorldObjectAnimation(new AnimationTime.preset(camera_animation_time));
        target_animation.do_absolute_position(new LinearPath3D(Vec3(0, options.target_height, 0)));
        target_animation.curve = new SCurve(0.5f);
        target.animate(target_animation, true);

        buffer_action(new RenderActionDelay(new AnimationTime.preset(0.5f)));
        buffer_action(new RenderActionSplitDeadWall(context.server_times.split_wall));

        hover_sound = store.audio_player.load_sound("mouse_over");

        foreach (RenderTile tile in scene.tiles)
        {
            tile.on_mouse_over.connect(tile_hover);
            tile.on_focus_lost.connect(tile_unhover);
        }
        world.do_picking = true;

        for (int i = 0; i < 16; i++)
            buffer_action(new RenderActionInitialDraw(context.server_times.initial_draw, players[(i + dealer_index) % 4], i < 12 ? 4 : 1));

        // Flip the dead wall mark tile using the tile ID from the server
        buffer_action(new RenderActionFlipDeadWallMark(info.dead_wall_mark_tile_id));
    }

    protected override void process(DeltaArgs args)
    {
        if (!has_loaded)
        {
            has_loaded = true;
            game_loaded();
        }

        // Auto-save camera settings after 5 seconds of no changes
        if (camera_settings_dirty)
        {
            camera_save_timer += args.delta;
            if (camera_save_timer >= 5.0f)
            {
                options.save();
                camera_settings_dirty = false;
                camera_save_timer = 0;
            }
        }
    }

    protected override void key_press(KeyArgs key)
    {
        if (key.keycode == KeyCode.NUM_1)
        {
            camera.position = camera.position.plus(Vec3(0, 0.1f, 0));
            options.camera_height = camera.position.y;
            camera_settings_dirty = true;
            camera_save_timer = 0;
        }
        else if (key.keycode == KeyCode.NUM_2)
        {
            camera.position = camera.position.plus(Vec3(0, -0.1f, 0));
            options.camera_height = camera.position.y;
            camera_settings_dirty = true;
            camera_save_timer = 0;
        }
        else if (key.keycode == KeyCode.NUM_3)
        {
            target.position = target.position.plus(Vec3(0, 0.1f, 0));
            options.target_height = target.position.y;
            camera_settings_dirty = true;
            camera_save_timer = 0;
        }
        else if (key.keycode == KeyCode.NUM_4)
        {
            target.position = target.position.plus(Vec3(0, -0.1f, 0));
            options.target_height = target.position.y;
            camera_settings_dirty = true;
            camera_save_timer = 0;
        }
        if (key.keycode == KeyCode.NUM_5)
        {
            camera.view_angle += 0.5f;
        }
        else if (key.keycode == KeyCode.NUM_6)
        {
            camera.view_angle -= 0.5f;
        }
        else if (key.keycode == KeyCode.NUM_7)
        {
            // Increase your own hand angle
            players[observer_index].adjust_hand_angle(0.02f);

           
        }
        else if (key.keycode == KeyCode.NUM_8)
        {
            // Decrease your own hand angle
            players[observer_index].adjust_hand_angle(-0.02f);

           
        }
        else if (key.keycode == KeyCode.NUM_9)
        {
            // Increase right-player (shimocha) hand angle
            int right_player_index = (observer_index + 1) % 4;
            players[right_player_index].adjust_hand_angle(0.02f);
        }
        else if (key.keycode == KeyCode.NUM_0)
        {
            // Decrease right-player (shimocha) hand angle
            int right_player_index = (observer_index + 1) % 4;
            players[right_player_index].adjust_hand_angle(-0.02f);
        }
        else if (key.keycode == KeyCode.MINUS)
        {
             // Increase cross-player (opposite, toimen) hand angle
            int cross_player_index = (observer_index + 2) % 4;
            players[cross_player_index].adjust_hand_angle(0.02f);
        }
        else if (key.keycode == KeyCode.EQUALS)
        {
             // Decrease cross-player (opposite, toimen) hand angle
            int cross_player_index = (observer_index + 2) % 4;
            players[cross_player_index].adjust_hand_angle(-0.02f);    
        }
        else if (key.keycode == KeyCode.LEFTBRACKET)
        { 
            // Increase left-player (kamicha) hand angle
            int left_player_index = (observer_index + 3) % 4;
            players[left_player_index].adjust_hand_angle(0.02f);
        }
        else if (key.keycode == KeyCode.RIGHTBRACKET)
        {
             // Decrease left-player (kamicha) hand angle
            int left_player_index = (observer_index + 3) % 4;
            players[left_player_index].adjust_hand_angle(-0.02f);
          
        }
    }

    public void load_options(Options options)
    {
        scene.load_options(options);
    }

    private void game_finished(RoundFinishResult results)
    {
        switch (results.result)
        {
        case RoundFinishResult.RoundResultEnum.DRAW:
            draw(results.tenpai_indices, results.draw_type);
            break;
        case RoundFinishResult.RoundResultEnum.RON:
            ron(results.winner_indices, results.loser_index, results.discard_tile, true);
            break;
        case RoundFinishResult.RoundResultEnum.TSUMO:
            tsumo(results.winner_indices[0]);
            break;
        default:
            break;
        }
    }

    private void ron(int[] winner_indices, int discard_player_index, int tile_ID, bool allow_dora_flip)
    {
        RenderPlayer? discard_player = null;
        if (discard_player_index != -1)
            discard_player = players[discard_player_index];

        RenderPlayer? return_riichi_player = null;
       

        RenderTile? tile = null;

        if (tile_ID != -1)
        {
            tile = tiles[tile_ID];
            discard_player.rob_tile(tile);
        }

        RenderPlayer[] winners = new RenderPlayer[winner_indices.length];
        for (int i = 0; i < winners.length; i++)
            winners[i] = players[winner_indices[i]];

        buffer_action(new RenderActionRon(context.server_times.win, winners, discard_player, tile, return_riichi_player, allow_dora_flip));
    }

    private void tsumo(int player_index)
    {
        RenderPlayer player = players[player_index];
        buffer_action(new RenderActionTsumo(context.server_times.win, player));
    }

    private void draw(int[] tenpai_indices, GameDrawType draw_type)
    {
        if (draw_type == GameDrawType.TRIPLE_RON)
        {
            ron(tenpai_indices, -1, -1, false);
            return;
        }

        if (draw_type == GameDrawType.EMPTY_WALL ||
            draw_type == GameDrawType.FOUR_RIICHI ||
            draw_type == GameDrawType.VOID_HAND ||
            draw_type == GameDrawType.TRIPLE_RON)
        {
            ArrayList<RenderPlayer> tenpai_players = new ArrayList<RenderPlayer>();
            foreach (int i in tenpai_indices)
                tenpai_players.add(players[i]);

            buffer_action(new RenderActionGameDraw(new AnimationTime.zero(), tenpai_players, draw_type));
        }
    }

    private void tile_assignment(Tile tile)
    {
        RenderTile t = tiles[tile.ID];
        t.tile_type = tile;
        t.reload();
    }

    private void tile_draw(int player_index, int tile_ID)
    {
        RenderPlayer player = players[player_index];
        //  RenderTile tile = tiles[tile_ID];
        //      @"tile_draw: player=$player_index, tile_ID=$tile_ID, tile_type=$(tile.tile_type.tile_type.to_string())");

        buffer_action(new RenderActionDraw(context.server_times.tile_draw, player));
    }

    public void dead_tile_draw(int player_index, int tile_ID)
    {
        RenderPlayer player = players[player_index];
        RenderTile tile = tiles[tile_ID];

        buffer_action(new RenderActionDrawDeadWall(context.server_times.tile_draw, player, tile));
    }

    private void tile_discard(int player_index, int tile_ID)
    {
        RenderPlayer player = players[player_index];
        RenderTile tile = tiles[tile_ID];
        buffer_action(new RenderActionDiscard(context.server_times.tile_discard, player, tile));
    }

    private void flip_dead_wall_mark(int mark_tile_id)
    {
        scene.wall.flip_dead_wall_mark(mark_tile_id);
    }

    private void late_kan(int player_index, int tile_ID)
    {
        RenderPlayer player = players[player_index];
        RenderTile tile = tiles[tile_ID];
        buffer_action(new RenderActionLateKan(context.server_times.call, player, tile));
    }

    private void closed_kan(int player_index, TileType type, int tile_1_ID, int tile_2_ID, int tile_3_ID, int tile_4_ID)
    {
        RenderPlayer player = players[player_index];

        RenderTile tile_1 = tiles[tile_1_ID];
        RenderTile tile_2 = tiles[tile_2_ID];
        RenderTile tile_3 = tiles[tile_3_ID];
        RenderTile tile_4 = tiles[tile_4_ID];

        buffer_action(new RenderActionClosedKan(context.server_times.call, player, tile_1, tile_2, tile_3, tile_4));
    }

    private void open_kan(int player_index, int discard_player_index, int tile_ID, int tile_1_ID, int tile_2_ID, int tile_3_ID)
    {
        RenderPlayer player = players[player_index];
        RenderPlayer discard_player = players[discard_player_index];

        RenderTile tile   = tiles[tile_ID];
        RenderTile tile_1 = tiles[tile_1_ID];
        RenderTile tile_2 = tiles[tile_2_ID];
        RenderTile tile_3 = tiles[tile_3_ID];

        buffer_action(new RenderActionOpenKan(context.server_times.call, player, discard_player, tile, tile_1, tile_2, tile_3));

        // Dead tile draw will happen through game_dead_tile_draw signal from server_calls_finished
    }

    private void pon(int player_index, int discard_player_index, int tile_ID, int tile_1_ID, int tile_2_ID)
    {
        RenderPlayer player = players[player_index];
        RenderPlayer discard_player = players[discard_player_index];

        RenderTile tile   = tiles[tile_ID];
        RenderTile tile_1 = tiles[tile_1_ID];
        RenderTile tile_2 = tiles[tile_2_ID];

        buffer_action(new RenderActionPon(context.server_times.call, player, discard_player, tile, tile_1, tile_2));
    }

    private void chii(int player_index, int discard_player_index, int tile_ID, int tile_1_ID, int tile_2_ID)
    {
        RenderPlayer player = players[player_index];
        RenderPlayer discard_player = players[discard_player_index];

        RenderTile tile   = tiles[tile_ID];
        RenderTile tile_1 = tiles[tile_1_ID];
        RenderTile tile_2 = tiles[tile_2_ID];

        buffer_action(new RenderActionChii(context.server_times.call, player, discard_player, tile, tile_1, tile_2));
    }

    public void set_active(bool active)
    {
        if (active)
            buffer_action(new RenderActionSetActive(active));
        else
            scene.active = active;

        if (!active)
        {
            select_groups = null;
            foreach (RenderTile tile in tiles)
                tile.indicated = false;
        }
    }

    /////////////////////

    protected void buffer_action(RenderAction action)
    {
        scene.add_action(action);
    }

    private RenderTile? hover_tile = null;
    private void tile_hover(WorldObject obj)
    {
        hover_tile = obj as RenderTile;
    }

    private void tile_unhover(WorldObject obj)
    {
        var t = obj as RenderTile;
        t.hovered = false;
        hover_tile = null;

        //if (scene.active)
            foreach (var tile in tiles)
                tile.indicated = false;
    }

    protected override void mouse_move(MouseMoveArgs mouse)
    {
        base.mouse_move(mouse);

        RenderTile? tile = scene.active ? hover_tile : null;
        TileSelectionGroup? group = get_tile_selection_group(tile);

        if (group != null)
        {
            if (!tile.hovered)
                hover_sound.play();
            foreach (Tile t in group.highlight_tiles)
                tiles[t.ID].indicated = true;

            tile.hovered = true;
            mouse.cursor_type = CursorType.HOVER;
            mouse.handled = true;
        }
    }

    private TileSelectionGroup? get_tile_selection_group(RenderTile? tile)
    {
        if (tile == null || select_groups == null)
            return null;

        foreach (TileSelectionGroup group in select_groups)
            foreach (Tile t in group.selection_tiles)
                if (t.ID == tile.tile_type.ID)
                    return group;

        return null;
    }

    protected override void mouse_event(MouseEventArgs mouse)
    {
        if (mouse.handled || !scene.active)
        {
            mouse_down_tile = null;
            return;
        }

        if (mouse.button == MouseEventArgs.Button.LEFT)
        {
            RenderTile? tile = get_tile_selection_group(hover_tile) == null ? null : hover_tile;

            if (mouse.down)
                mouse_down_tile = tile;
            else
            {
                if (tile != null && tile == mouse_down_tile)
                    tile_selected(tile.tile_type);

                mouse_down_tile = null;
            }
        }
    }

    public void set_tile_select_groups(ArrayList<TileSelectionGroup>? groups)
    {
        /*foreach (RenderTile tile in scene.tiles)
            tile.indicated = false;*/

        select_groups = groups;

        /*if (groups != null)
            foreach (TileSelectionGroup group in groups)
                if (group.group_type != TileSelectionGroup.GroupType.DISCARD)
                    foreach (Tile tile in group.highlight_tiles)
                        tiles[tile.ID].indicated = true;*/
    }

    public void set_paused(bool paused)
    {
        is_paused = paused;
        scene.set_paused(paused);
    }
}
