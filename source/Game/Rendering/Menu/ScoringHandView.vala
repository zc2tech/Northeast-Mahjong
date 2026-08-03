using Engine;
using Gee;

public class ScoringHandView : View3D
{
    private Scoring score;

    private ArrayList<RenderTile> tiles = new ArrayList<RenderTile>();
    private float width = 1;
    private const float TILE_GAP = 0.08f;  // Gap between tiles in scoring view

    public ScoringHandView(GameRenderContext context, Scoring score)
    {
        this.score = score;
        resize_style = ResizeStyle.ABSOLUTE;
    }

    public override void added()
    {
        Options options = new Options.from_disk();

        RenderTile size_tile = new RenderTile();
        world.add_object(size_tile);
        Vec3 tile_size = size_tile.obb;
        world.remove_object(size_tile);

        width = (score.player.hand.size + 2) * (tile_size.x + TILE_GAP);

        ArrayList<RenderCalls.RenderCall> calls = new ArrayList<RenderCalls.RenderCall>();

        for (int i = 0; i < score.player.calls.size; i++)
        {
            RoundStateCall call = score.player.calls[score.player.calls.size - i - 1];
            RenderCalls.RenderCall c = create_call(call, score.player.index, tile_size);
            c.set_tile_gap(TILE_GAP);  // Apply gap to call tiles

            calls.add(c);
            width += c.width + tile_size.x + TILE_GAP;  // Reduced group spacing
        }

        float p = -width / 2;
        for (int i = 0; i < score.player.hand.size; i++)
        {
            Tile t = score.player.hand[i];
            RenderTile tile = new RenderTile() { tile_type = t };

            bool added = false;
            for (int j = 0; j < tiles.size; j++)
            {
                if (t.tile_type <= tiles[j].tile_type.tile_type)
                {
                    tiles.insert(j, tile);
                    added = true;
                    break;
                }
            }

            if (!added)
                tiles.add(tile);
        }

        for (int i = 0; i < tiles.size; i++)
        {
            world.add_object(tiles[i]);
            Quat tile_rot = Quat.from_euler(0, 0.5f - 0.44f, 0);  // Slightly more tilt toward viewer
            tiles[i].set_absolute_location(Vec3(p + (tile_size.x + TILE_GAP) * 0.5f, -tile_size.y / 4, 0), tile_rot);
            p += tile_size.x + TILE_GAP;
        }

        RenderTile tile = new RenderTile() { tile_type = score.round.win_tile };
        world.add_object(tile);
        Quat win_tile_rot = Quat.from_euler(0, 0.5f - 0.44f, 0);  // Slightly more tilt toward viewer
        tile.set_absolute_location(Vec3(p + (tile_size.x + TILE_GAP) * 1.5f, -tile_size.y / 4, 0), win_tile_rot);
        p += (tile_size.x + TILE_GAP) * 2;
        tiles.add(tile);

        foreach (RenderCalls.RenderCall call in calls)
        {
            p += call.width + tile_size.x + TILE_GAP;  // Reduced group spacing
            foreach (RenderTile t in call.tiles)
                tiles.add(t);
            world.add_object(call);
            call.transform.position = Vec3(p, -tile_size.y / 4, tile_size.z / 2);  // Lowered to match hand tiles
            call.arrange(new AnimationTime.zero());  // Re-arrange with the gap applied
        }

        foreach (var t in tiles)
        {
            t.model_quality = options.model_quality;
            t.texture_type = options.tile_textures;
            t.front_color = options.tile_fore_color;
            t.back_color = options.tile_back_color;
            t.reload();
        }

        // Adjust camera distance based on total width to fit everything
        float len = 4;
        float width_ratio = width / 4.0f;  // Base width is around 4 units
        if (width_ratio > 1.0f)
        {
            len = len * width_ratio * 0.8f;  // Scale camera distance with width
        }

        Vec3 pos = Vec3(0, len * 0.8f, len * 0.6f);  // Lower angle for better tile face view

        WorldObject target = new WorldObject();
        world.add_object(target);
        WorldCamera camera = new TargetWorldCamera(target);
        world.add_object(camera);
        world.active_camera = camera;
        camera.position = pos;

        WorldLight light1 = new WorldLight();
        WorldLight light2 = new WorldLight();
        world.add_object(light1);
        world.add_object(light2);

        light1.color = Color.white();
        light1.position = Vec3(len, len * 2, len);
        light1.intensity = 6;
        light2.color = light1.color;
        light2.position = Vec3(-len, len * 2, len);
        light2.intensity = light1.intensity;
    }

    private RenderCalls.RenderCall create_call(RoundStateCall call, int player_index, Vec3 tile_size)
    {
        ArrayList<RenderTile> tiles = new ArrayList<RenderTile>();
        RenderTile? call_tile = null;

        foreach (Tile t in call.tiles)
        {
            RenderTile tl = new RenderTile() { tile_type = t };

            if (call.call_type != RoundStateCall.CallType.CLOSED_KAN && call.call_tile != null && t.ID == call.call_tile.ID)
                call_tile = tl;
            else
                tiles.add(tl);
        }

        RenderCalls.RenderCall? c = null;
        RenderCalls.Alignment align = (RenderCalls.Alignment)((call.discarder_index - player_index + 4) % 4);

        if (call.call_type == RoundStateCall.CallType.CHII)
            c = new RenderCalls.RenderCallChii(tiles, call_tile, tile_size);
        else if (call.call_type == RoundStateCall.CallType.PON)
            c = new RenderCalls.RenderCallPon(tiles, call_tile, tile_size, align);
        else if (call.call_type == RoundStateCall.CallType.OPEN_KAN)
            c = new RenderCalls.RenderCallOpenKan(tiles, call_tile, tile_size, align);
        else if (call.call_type == RoundStateCall.CallType.CLOSED_KAN)
            c = new RenderCalls.RenderCallClosedKan(tiles, tile_size);
        else if (call.call_type == RoundStateCall.CallType.LATE_KAN)
            c = new RenderCalls.RenderCallLateKan(tiles, call_tile, tile_size, align);

        return c;
    }

    public float alpha
    {
        set
        {
            foreach (RenderTile tile in tiles)
                tile.alpha = value;
        }
    }
}
