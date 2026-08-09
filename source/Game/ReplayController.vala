using Engine;

class ReplayController : Object
{
    private GameState game;
    private ClientRoundState round;
    private ReplayGameRenderView? renderer = null;
    private ReplayMenuView? menu = null;
    private EventTimer? round_over_timer = null;

    private unowned Container parent_view;
    private GameStartInfo start_info;
    private AnimationTimings replay_timings;  // Use standard replay timings, not log's zero timings
    private ServerSettings settings;
    private IGameConnection connection;
    private int observer_index;  // Replay is always observer mode

    private Options options;
    private bool game_finished = false;
    private bool is_paused = false;
    private float speed_multiplier = 1.0f;

    public signal void game_loaded();
    public signal void finished();

    public ReplayController(Container parent_view, GameStartInfo start_info, ServerSettings settings, IGameConnection connection, int player_index, Options options)
    {
        this.parent_view = parent_view;
        this.start_info = start_info;
        this.settings = settings;
        this.connection = connection;
        this.observer_index = (player_index >= 0 && player_index < 4) ? player_index : 0;  // Use player_index from replay server
        this.options = options;

        // Create standard replay timings (ignore zero timings from bot simulation logs)
        this.replay_timings = create_replay_timings();

        this.connection.disconnected.connect(disconnected);

        game = new GameState(start_info, settings);
    }

    ~ReplayController()
    {
        connection.close();

        if (renderer != null)
            parent_view.remove_child(renderer);
        if (menu != null)
            parent_view.remove_child(menu);
    }

    public void process(DeltaArgs delta)
    {
        if (game_finished)
        {
            finished();
            return;
        }

        // Don't process timers or messages when paused
        if (!is_paused)
        {
            if (round_over_timer != null)
                round_over_timer.process(delta);

            ServerMessage? message = null;
            while ((message = connection.dequeue_message()) != null)
            {

                if (!game.round_is_finished && round != null)
                    round.receive_message(message);

                if (message is ServerMessageRoundStart)
                {
                    ServerMessageRoundStart start = message as ServerMessageRoundStart;
                    create_round(start.info);
                    menu.update_scores(game.scores.to_array());
                }
            }

            // Check for round finish only when not paused
            if (!game.round_is_finished && round != null)
            {
                if (round.finished)
                {
                    game.round_finished(round.result);
                    // Use replay_timings instead of start_info.timings (which may be zero from bot simulation)
                    round_over_timer = new EventTimer(replay_timings.round_over_delay, true);
                    round_over_timer.elapsed.connect(round_over_timer_elapsed);
                }
            }
        }
    }

    private void create_round(RoundStartInfo info)
    {

        if (renderer != null)
            parent_view.remove_child(renderer);
        if (menu != null)
            parent_view.remove_child(menu);

        game.start_round(info);

        // Create round state
        round = new ClientRoundState(info, settings, observer_index, game.round_wind, game.dealer_index);

        // Create replay-specific renderer
        renderer = new ReplayGameRenderView(observer_index, game.dealer_index, start_info, info, options, game.score, settings);
        renderer.game_loaded.connect(do_game_loaded);

        // Connect round signals to renderer
        round.game_finished.connect(renderer.game_finished);
        round.game_tile_assignment.connect(renderer.tile_assignment);
        round.game_tile_draw.connect(renderer.tile_draw);
        round.game_dead_tile_draw.connect(renderer.dead_tile_draw);
        round.game_tile_discard.connect(renderer.tile_discard);
        round.game_late_kan.connect(renderer.late_kan);
        round.game_closed_kan.connect(renderer.closed_kan);
        round.game_open_kan.connect(renderer.open_kan);
        round.game_pon.connect(renderer.pon);
        round.game_chii.connect(renderer.chii);

        parent_view.add_child(renderer);

        // Create replay-specific menu
        menu = new ReplayMenuView(renderer.context, settings, observer_index);
        menu.score_finished.connect(score_finished);
        menu.return_to_menu_requested.connect(return_to_menu);
        menu.next_hand_requested.connect(menu_next_hand_requested);
        menu.replay_hand_requested.connect(menu_replay_hand_requested);

        // Connect replay controls
        menu.observe_next_pressed.connect(renderer.observe_next);
        menu.observe_prev_pressed.connect(renderer.observe_prev);
        menu.speed_up_pressed.connect(speed_up);
        menu.speed_down_pressed.connect(speed_down);
        menu.pause_continue_pressed.connect(pause_continue);

        parent_view.add_child(menu);

    }

    private void round_over_timer_elapsed()
    {

        menu.update_scores(game.scores.to_array());
        menu.round_finished();

        if (game.game_is_finished)
        {
            menu.game_over();
        }
    }

    private void do_game_loaded()
    {
        game_loaded();
    }

    private void score_finished()
    {
        // In replay, we don't send ready message - just wait for next hand or user action
    }

    private void return_to_menu()
    {
        game_finished = true;
    }

    private void menu_next_hand_requested()
    {
        // Send message to server to advance to next hand
        connection.send_message(new ClientMessageReplayNextHand());
    }

    private void menu_replay_hand_requested()
    {
        // TODO: Implement replay same hand functionality
    }

    private void speed_up()
    {
        if( speed_multiplier < 4f) {
            speed_multiplier += 0.25f;
            apply_speed();
            menu.show_speed_toast(speed_multiplier);
        }
    }

    private void speed_down()
    {
        if ( speed_multiplier > 0.25f ) {

            speed_multiplier -= 0.25f;
            apply_speed();
            menu.show_speed_toast(speed_multiplier);
        }
    }

    private void apply_speed()
    {
        connection.send_message(new ClientMessageReplaySpeed(speed_multiplier));

        // Speed up animations when multiplier >= 2
        if (renderer != null)
            renderer.set_animation_speed(speed_multiplier);

    }

    private void pause_continue()
    {
        if (is_paused)
        {
            // Resume - server will control message flow
            is_paused = false;
            connection.send_message(new ClientMessageReplayPause(false));
            if (renderer != null)
                apply_speed();
            menu.show_speed_toast(speed_multiplier);
            menu.set_pause_button_icon(false);  // Show pause icon (||)
        }
        else
        {
            // Pause - server will stop sending messages
            is_paused = true;
            connection.send_message(new ClientMessageReplayPause(true));
            menu.show_speed_toast_text("Paused");
            menu.set_pause_button_icon(true);  // Show play icon (▶)
        }
    }

    private void disconnected()
    {
        //  if (is_disconnected)
        //      return;

        //  is_disconnected = true;
        //  game_finished = true;
    }

    public void load_options(Options options)
    {
        this.options = options;
        if (renderer != null)
            renderer.load_options(options);
    }

    private static AnimationTimings create_replay_timings()
    {
        // Create standard human-viewable timings for replay
        // These override zero timings from bot simulation logs
        float winning_draw_animation_time = 0.5f;
        float hand_reveal_animation_time = 0.5f;
        float round_over_delay = 1.0f;
        float round_end_delay = 3 + 1;
        float hanchan_end_delay = 30 + 1;
        float game_end_delay = 60 + 1;
        int decision_time = 360000; // Large value, not used in replay

        var finish_label_fade = new AnimationTime(1.0f, 0.5f, 0.0f);
        var menu_items_fade = new AnimationTime(1.0f, 0.5f, 1.0f);
        var han_fade = new AnimationTime(0.5f, 0.5f, 0.0f);
        var score_counting_fade = new AnimationTime(1.0f, 0.5f, 0.0f);
        var score_counting = new AnimationTime(1.0f, 3.0f, 2.0f);
        var players_points_counting = new AnimationTime(0.0f, 3.0f, 2.0f);
        var players_score_fade = new AnimationTime(0.0f, 0.5f, 0.0f);
        var players_score_counting = new AnimationTime(1.0f, 3.0f, 2.0f);

        var initial_draw = new AnimationTime(0.0f, 0.15f, 0.0f);
        var tile_draw = new AnimationTime(0.0f, 0.15f, 0.2f);
        var tile_discard = new AnimationTime(0.0f, 0.15f, 0.3f);
        var call = new AnimationTime(0.0f, 0.5f, 0.0f);
        var hand_reveal = new AnimationTime(0.0f, 0.15f, 0.8f);
        var split_wall = new AnimationTime(0.0f, 0.5f, 0.0f);
        var dead_wall_mark_flip = new AnimationTime(0.0f, 0.2f, 0.0f);
        var win = new AnimationTime(0.0f, 0.5f, 0.5f);
        var hand_order = new AnimationTime(0.0f, 0.15f, 0.0f);
        var hand_angle = new AnimationTime(0.0f, 0.2f, 0.0f);

        return new AnimationTimings(
            winning_draw_animation_time,
            hand_reveal_animation_time,
            round_over_delay,
            round_end_delay,
            hanchan_end_delay,
            game_end_delay,
            decision_time,
            finish_label_fade,
            menu_items_fade,
            han_fade,
            score_counting_fade,
            score_counting,
            players_points_counting,
            players_score_fade,
            players_score_counting,
            initial_draw,
            tile_draw,
            tile_discard,
            call,
            hand_reveal,
            split_wall,
            dead_wall_mark_flip,
            win,
            hand_order,
            hand_angle
        );
    }
}
