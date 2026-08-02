using Engine;

class GameController : Object
{
    private GameState game;
    private ClientRoundState round;
    private GameRenderView? renderer = null;
    private View2D? menu = null;  // Can be GameMenuView or ReplayMenuView
    private EventTimer? round_over_timer = null;

    private unowned Container parent_view;
    private GameStartInfo start_info;
    private ServerSettings settings;
    private IGameConnection connection;
    private int player_index;

    private Options options;
    private bool game_finished = false;
    private bool is_disconnected = false;
    private bool is_paused = false;
    private float saved_speed_multiplier = 1.0f;
    private float speed_multiplier = 1.0f;
    public signal void game_loaded();
    public signal void finished();

    public GameController(Container parent_view, GameStartInfo start_info, ServerSettings settings, IGameConnection connection, int player_index, Options options)
    {
        this.parent_view = parent_view;
        this.start_info = start_info;
        this.settings = settings;
        this.connection = connection;
        this.player_index = player_index;
        this.options = options;

        //  Environment.log(LogType.DEBUG, "GameController", @"Created: player_index=$player_index, settings.is_replay_mode=$(settings.is_replay_mode), is_replay_mode=$(is_replay_mode)");

        this.connection.disconnected.connect(disconnected);

        game = new GameState(start_info, settings);
    }

    ~GameController()
    {
        Environment.log(LogType.DEBUG, "GameController", "Destroying game controller");
        connection.close();

        parent_view.remove_child(renderer);
        parent_view.remove_child(menu);
    }

    public void process(DeltaArgs delta)
    {
        if (game_finished == true)
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
                if (!game.round_is_finished)
                    round.receive_message(message);

                if (message is ServerMessageRoundStart)
                {
                    ServerMessageRoundStart start = message as ServerMessageRoundStart;
                    create_round(start.info);
                    if (menu is GameMenuView)
                        ((GameMenuView)menu).update_scores(game.scores.to_array());
                    else if (menu is ReplayMenuView)
                        ((ReplayMenuView)menu).update_scores(game.scores.to_array());
                }
                else if (message is ServerMessagePlayerLeft && !game.game_is_finished)
                {
                    ServerMessagePlayerLeft msg = message as ServerMessagePlayerLeft;
                    if (menu is GameMenuView)
                        ((GameMenuView)menu).display_player_left(game.get_player(msg.player_index).name);
                }
            }

            // Check for round finish only when not paused
            if (!game.round_is_finished)
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

    public void load_options(Options options)
    {
        this.options = options;
        renderer.load_options(options);
    }

    private void create_round_state(RoundStartInfo round_start)
    {
        round = new ClientRoundState(round_start, settings, player_index, game.round_wind, game.dealer_index);
        round.do_action.connect(do_action);

        // Only connect game action signals in normal mode
        if (!settings.is_replay_mode && menu is GameMenuView)
        {
            var game_menu = (GameMenuView)menu;

            round.set_chii_state.connect(game_menu.set_chii);
            round.set_pon_state.connect(game_menu.set_pon);
            round.set_kan_state.connect(game_menu.set_kan);
            round.set_tsumo_state.connect(game_menu.set_tsumo);
            round.set_ron_state.connect(game_menu.set_ron);
            round.set_timer_state.connect(game_menu.set_move_timer);
            round.set_continue_state.connect(game_menu.set_continue);
            round.set_void_hand_state.connect(game_menu.set_void_hand);

            game_menu.chii_pressed.connect(round.client_chii);
            game_menu.pon_pressed.connect(round.client_pon);
            game_menu.kan_pressed.connect(round.client_kan);
            game_menu.tsumo_pressed.connect(round.client_tsumo);
            game_menu.ron_pressed.connect(round.client_ron);
            game_menu.continue_pressed.connect(round.client_continue);
            game_menu.void_hand_pressed.connect(round.client_void_hand);

            renderer.tile_selected.connect(round.client_tile_selected);
        }

        round.set_tile_select_state.connect(renderer.set_active);
        round.set_tile_select_groups.connect(renderer.set_tile_select_groups);

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
    }

    private void do_action(ClientAction action)
    {
        connection.send_message(new ClientMessageGameAction(action));
    }

    private void create_round(RoundStartInfo info)
    {
        if (renderer != null)
            parent_view.remove_child(renderer);
        if (menu != null)
            parent_view.remove_child(menu);

        int index = player_index == -1 ? 0 : player_index;

        game.start_round(info);

        // Create appropriate view based on replay mode
        if (settings.is_replay_mode)
        {
            // Replay mode: use ReplayGameRenderView and ReplayMenuView
            renderer = new ReplayGameRenderView(player_index, game.dealer_index, start_info, info, options, game.score);
            renderer.game_loaded.connect(on_game_loaded);
            parent_view.add_child(renderer);

            var replay_menu = new ReplayMenuView(renderer.context, settings, index);
            replay_menu.score_finished.connect(menu_score_finished);
            replay_menu.next_hand_requested.connect(menu_next_hand_requested);
            replay_menu.return_to_menu_requested.connect(menu_return_to_menu_requested);
            replay_menu.observe_next_pressed.connect(((ReplayGameRenderView)renderer).observe_next);
            replay_menu.observe_prev_pressed.connect(((ReplayGameRenderView)renderer).observe_prev);
            replay_menu.speed_up_pressed.connect(speed_up);
            replay_menu.speed_down_pressed.connect(speed_down);
            replay_menu.pause_continue_pressed.connect(pause_continue);

            menu = replay_menu;
            parent_view.add_child(menu);

            Environment.log(LogType.DEBUG, "GameController", "Created ReplayGameRenderView and ReplayMenuView");
        }
        else
        {
            // Normal game: use GameRenderView and GameMenuView
            renderer = new GameRenderView(player_index, game.dealer_index, start_info, info, options, game.score);
            renderer.game_loaded.connect(on_game_loaded);
            parent_view.add_child(renderer);

            var game_menu = new GameMenuView(renderer.context, settings, index, player_index == -1);
            game_menu.score_finished.connect(menu_score_finished);
            game_menu.next_hand_requested.connect(menu_next_hand_requested);
            game_menu.return_to_menu_requested.connect(menu_return_to_menu_requested);

            menu = game_menu;
            parent_view.add_child(menu);

            Environment.log(LogType.DEBUG, "GameController", "Created GameRenderView and GameMenuView");
        }

        create_round_state(info);
    }

    private void on_game_loaded()
    {
        game_loaded();
    }

    private void menu_score_finished()
    {
        if (game.game_is_finished || is_disconnected)
            game_finished = true;
        else
            connection.send_message(new ClientMessageMenuReady());
    }

    private void menu_next_hand_requested()
    {
        // In replay mode, proceed to next hand automatically
        Environment.log(LogType.DEBUG, "GameController", "Next hand requested in replay mode");
        if (game.game_is_finished)
        {
            Environment.log(LogType.DEBUG, "GameController", "All hands replayed, no more hands");
            return;
        }
        connection.send_message(new ClientMessageMenuReady());
    }

    private void menu_return_to_menu_requested()
    {
        // Exit replay and return to main menu
        Environment.log(LogType.DEBUG, "GameController", "Return to menu requested");
        game_finished = true;
    }

    private void round_over_timer_elapsed()
    {
        if (menu is GameMenuView)
        {
            ((GameMenuView)menu).update_scores(game.scores.to_array());
            ((GameMenuView)menu).round_finished();
        }
        else if (menu is ReplayMenuView)
        {
            ((ReplayMenuView)menu).update_scores(game.scores.to_array());
            ((ReplayMenuView)menu).round_finished();
        }
    }

    private void disconnected()
    {
        is_disconnected = true;

        if (menu != null && !game.game_is_finished)
        {
            if (round != null)
                round.disconnected();

            if (menu is GameMenuView)
            {
                ((GameMenuView)menu).game_over();
                ((GameMenuView)menu).display_disconnected();
            }
            else if (menu is ReplayMenuView)
            {
                ((ReplayMenuView)menu).game_over();
                // Replay doesn't need disconnected message
            }
        }
    }

    private void speed_up()
    {
        // Increase speed by 0.25x increments, max 4x
        if (speed_multiplier < 4.0f)
        {
            speed_multiplier += 0.25f;
            apply_speed();
            connection.send_message(new ClientMessageReplaySpeed(speed_multiplier));
            if (menu is ReplayMenuView)
                ((ReplayMenuView)menu).show_speed_toast(speed_multiplier);
            Environment.log(LogType.INFO, "GameController", @"Replay speed: $(speed_multiplier)x");
        }
    }

    private void speed_down()
    {
        // Decrease speed by 0.25x increments, min 0.25x
        if (speed_multiplier > 0.25f)
        {
            speed_multiplier -= 0.25f;
            apply_speed();
            connection.send_message(new ClientMessageReplaySpeed(speed_multiplier));
            if (menu is ReplayMenuView)
                ((ReplayMenuView)menu).show_speed_toast(speed_multiplier);
            Environment.log(LogType.INFO, "GameController", @"Replay speed: $(speed_multiplier)x");
        }
    }

    private void apply_speed()
    {
        // Apply speed multiplier to decision time only (not animation speed)
        if (renderer != null && renderer.context != null)
        {
            // Scale only the decision time, not the animations
            renderer.context.set_decision_time_multiplier(speed_multiplier);
        }
    }

    private void pause_continue()
    {
        if (is_paused)
        {
            // Resume
            is_paused = false;
            connection.send_message(new ClientMessageReplayPause(false));
            if (renderer != null)
            {
                // Reapply the speed multiplier after resuming
                apply_speed();
            }
            if (menu is ReplayMenuView)
            {
                ((ReplayMenuView)menu).show_speed_toast(speed_multiplier);
                ((ReplayMenuView)menu).set_pause_button_icon(false);  // Show pause icon (||)
            }
            Environment.log(LogType.INFO, "GameController", @"Replay resumed at $(speed_multiplier)x");
        }
        else
        {
            // Pause - just set flag, don't change speed
            is_paused = true;
            connection.send_message(new ClientMessageReplayPause(true));
            if (renderer != null)
                renderer.set_paused(true);
            if (menu is ReplayMenuView)
            {
                ((ReplayMenuView)menu).show_speed_toast_text("Paused");
                ((ReplayMenuView)menu).set_pause_button_icon(true);  // Show play icon (▶)
            }
            Environment.log(LogType.INFO, "GameController", "Replay paused");
        }
    }

    public bool is_replay_paused()
    {
        return is_paused;
    }
}
