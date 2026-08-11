class BotConnection : Object
{
    private Bot bot;
    private IGameConnection connection;
    private ServerMessageParser parser = new ServerMessageParser();

    public BotConnection(Bot bot, IGameConnection connection)
    {
        this.bot = bot;
        this.connection = connection;

        connection.received_message.connect(message_received);
        parser.connect(round_start, typeof(ServerMessageRoundStart));
        parser.connect(tile_assignment, typeof(ServerMessageTileAssignment));
        parser.connect(dead_wall_draw, typeof(ServerMessageDeadWallDraw));
        parser.connect(tile_draw, typeof(ServerMessageTileDraw));
        parser.connect(tile_discard, typeof(ServerMessageTileDiscard));
        parser.connect(ron, typeof(ServerMessageRon));
        parser.connect(tsumo, typeof(ServerMessageTsumo));
        parser.connect(turn_decision, typeof(ServerMessageTurnDecision));
        parser.connect(call_decision, typeof(ServerMessageCallDecision));
        parser.connect(late_kan, typeof(ServerMessageLateKan));
        parser.connect(closed_kan, typeof(ServerMessageClosedKan));
        parser.connect(open_kan, typeof(ServerMessageOpenKan));
        parser.connect(pon, typeof(ServerMessagePon));
        parser.connect(chii, typeof(ServerMessageChii));
        parser.connect(calls_finished, typeof(ServerMessageCallsFinished));
        parser.connect(draw, typeof(ServerMessageDraw));

        bot.poll.connect(poll);
        bot.do_discard.connect(bot_do_discard);
        bot.do_void_hand.connect(bot_do_void_hand);
        bot.do_tsumo.connect(bot_do_tsumo);
        bot.do_late_kan.connect(bot_do_late_kan);
        bot.do_closed_kan.connect(bot_do_closed_kan);
        bot.call_nothing.connect(bot_call_nothing);
        bot.call_ron.connect(bot_call_ron);
        bot.call_open_kan.connect(bot_call_open_kan);
        bot.call_pon.connect(bot_call_pon);
        bot.call_chii.connect(bot_call_chii);
    }

    ~BotConnection()
    {
        connection.received_message.disconnect(message_received);
        bot.poll.disconnect(poll);

        stop();
    }

    public void stop()
    {
        bot.stop(true);
    }

    private void message_received()
    {
        ServerMessage? message;

        while ((message = connection.dequeue_message()) != null)
        {
            if (message is ServerMessageGameStart)
            {
                ServerMessageGameStart start = message as ServerMessageGameStart;
                bot.init_game(start.info, start.settings, start.player_index);
            }
            else if (message is ServerMessageRoundStart)
            {
                connection.received_message.disconnect(message_received);
                var start = message as ServerMessageRoundStart;
                bot.start_round(true, start.info);
                break;
            }
        }
    }

    private void poll()
    {
        ServerMessage? message;
        while ((message = connection.dequeue_message()) != null)
            parser.execute(message);
    }

    private void round_start(ServerMessage message)
    {
        ServerMessageRoundStart start = message as ServerMessageRoundStart;
        bot.start_round(false, start.info);
    }

    private void tile_assignment(ServerMessage message)
    {
        ServerMessageTileAssignment tile_assignment = (ServerMessageTileAssignment)message;
        bot.tile_assign(tile_assignment.tile);
    }

    private void dead_wall_draw(ServerMessage message)
    {
        ServerMessageDeadWallDraw msg = (ServerMessageDeadWallDraw)message;
        bot.dead_wall_draw(msg.tile);
    }

    private void tile_draw(ServerMessage message)
    {
        bot.tile_draw();
    }

    private void tile_discard(ServerMessage message)
    {
        ServerMessageTileDiscard tile_discard = (ServerMessageTileDiscard)message;
        bot.tile_discard(tile_discard.tile_ID);
    }

    private void ron(ServerMessage message)
    {
        ServerMessageRon ron = (ServerMessageRon)message;
        bot.ron(ron.get_player_indices());
    }

    private void tsumo(ServerMessage message)
    {
        bot.tsumo();
    }

    private void turn_decision(ServerMessage message)
    {
        // Before processing turn decision, check if there are any state-update messages
        // (TileDraw, TileAssignment, TileDiscard) in the queue and process them first
        // to ensure the bot's state is fully up-to-date

        // Try multiple times with short waits to handle race conditions where
        // the server thread is still adding messages to the queue
        const int MAX_RETRIES = 3;
        const int WAIT_MICROSECONDS = 1000; // 1ms

        for (int retry = 0; retry < MAX_RETRIES; retry++)
        {
            bool found_state_message = false;

            while (true)
            {
                ServerMessage? next = connection.peek_message();
                if (next == null)
                    break;

                // Check if it's a state-update message that should be processed before turn decision
                if (next is ServerMessageTileDraw ||
                    next is ServerMessageTileAssignment ||
                    next is ServerMessageTileDiscard)
                {
                    // Dequeue and process this message
                    ServerMessage? msg = connection.dequeue_message();
                    if (msg != null)
                    {
                        parser.execute(msg);
                        found_state_message = true;
                    }
                }
                else
                {
                    // It's not a state-update message, stop peeking
                    break;
                }
            }

            // If we found and processed state messages, check again immediately
            // in case more arrived while we were processing
            if (found_state_message)
                continue;

            // No state messages found. If this isn't the last retry, wait a bit
            // in case the server thread is still adding messages to the queue
            if (retry < MAX_RETRIES - 1)
                Thread.usleep(WAIT_MICROSECONDS);
            else
                break;
        }

        // Now process the turn decision with fully updated state
        bot.turn_decision();
    }

    private void call_decision(ServerMessage message)
    {
        bot.call_decision();
    }

    private void late_kan(ServerMessage message)
    {
        ServerMessageLateKan kan = (ServerMessageLateKan)message;
        bot.late_kan(kan.tile_ID);
    }

    private void closed_kan(ServerMessage message)
    {
        ServerMessageClosedKan kan = (ServerMessageClosedKan)message;
        bot.closed_kan(kan.tile_type);
    }

    private void open_kan(ServerMessage message)
    {
        ServerMessageOpenKan kan = (ServerMessageOpenKan)message;
        bot.open_kan(kan.player_index, kan.tile_1_ID, kan.tile_2_ID, kan.tile_3_ID);
    }

    private void pon(ServerMessage message)
    {
        ServerMessagePon pon = (ServerMessagePon)message;
        bot.pon(pon.player_index, pon.tile_1_ID, pon.tile_2_ID);
    }

    private void chii(ServerMessage message)
    {
        ServerMessageChii chii = (ServerMessageChii)message;
        bot.chii(chii.player_index, chii.tile_1_ID, chii.tile_2_ID);
    }

    private void calls_finished(ServerMessage message)
    {
        bot.calls_finished();
    }

    private void draw(ServerMessage message)
    {
        ServerMessageDraw draw = message as ServerMessageDraw;
        bot.draw(draw.get_tenpai_indices(), draw.void_hand, draw.triple_ron);
    }

    /////////////////

    private void send_action(ClientAction action)
    {
        connection.send_message(new ClientMessageGameAction(action));
    }

    private void bot_do_discard(Tile tile)
    {
        send_action(new TileDiscardClientAction(tile.ID));
    }

    private void bot_do_tsumo()
    {
        send_action(new TsumoClientAction());
    }

    private void bot_do_void_hand()
    {
        send_action(new VoidHandClientAction());
    }

    private void bot_do_late_kan(Tile tile)
    {
        send_action(new LateKanClientAction(tile.ID));
    }

    private void bot_do_closed_kan(TileType type)
    {
        send_action(new ClosedKanClientAction(type));
    }

    private void bot_call_nothing()
    {
        send_action(new NoCallClientAction());
    }

    private void bot_call_ron()
    {
        send_action(new RonClientAction());
    }

    private void bot_call_open_kan()
    {
        send_action(new OpenKanClientAction());
    }

    private void bot_call_pon()
    {
        send_action(new PonClientAction());
    }

    private void bot_call_chii(Tile tile_1, Tile tile_2)
    {
        send_action(new ChiiClientAction(tile_1.ID, tile_2.ID));
    }
}