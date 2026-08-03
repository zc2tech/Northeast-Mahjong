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
    private ServerSettings settings;
    private IGameConnection connection;
    private int observer_index;  // Replay is always observer mode

    private Options options;
    private bool game_finished = false;
    private bool is_disconnected = false;
    private bool is_paused = false;
    private float speed_multiplier = 1.0f;

    public signal void game_loaded();
    public signal void finished();

    public ReplayController(Container parent_view, GameStartInfo start_info, ServerSettings settings, IGameConnection connection, Options options)
    {
        this.parent_view = parent_view;
        this.start_info = start_info;
        this.settings = settings;
        this.connection = connection;
        this.observer_index = 0;  // Start observing player 0
        this.options = options;


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
                    round_over_timer = new EventTimer(start_info.timings.round_over_delay, true);
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
        renderer = new ReplayGameRenderView(observer_index, game.dealer_index, start_info, info, options, game.score);
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
        // Server will send next round start when ready
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
}
