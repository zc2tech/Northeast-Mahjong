using Gee;
using Engine;

namespace GameServer
{
    class ServerMenu : Object
    {
        private Mutex mutex = Mutex();

        private ClientMessageParser parser = new ClientMessageParser();
        private ServerPlayer?[] slots = new ServerPlayer?[4];
        private RandomClass rnd = new RandomClass();

        public signal void game_start(GameStartInfo info);
        public signal void game_start_event(GameStartInfo info);

        public ServerMenu()
        {
            players = new ArrayList<ServerPlayer>();
            observers = new ArrayList<ServerPlayer>();
            settings = new ServerSettings.default();

            parser.connect(client_game_start, typeof(ClientMessageMenuGameStart));
            parser.connect(client_add_bot, typeof(ClientMessageMenuAddBot));
            parser.connect(client_kick_player, typeof(ClientMessageMenuKickPlayer));
            parser.connect(client_settings, typeof(ClientMessageMenuSettings));
            parser.connect(client_log_file, typeof(ClientMessageMenuGameLog));
        }

        public bool player_connected(ServerPlayer player)
        {
            mutex.lock();

            if (host == null)
                host = player;

            for (int i = 0; i < slots.length; i++)
            {
                if (slots[i] == null)
                {
                    for (int j = 0; j < slots.length; j++)
                        if (slots[j] != null)
                            player.send_message(new ServerMessageMenuSlotAssign(j, slots[j].name));

                    player.send_message(new ServerMessageMenuSettings(settings));
                    players.add(player);

                    player.receive_message.connect(message_received);
                    player.disconnected.connect(player_disconnected);

                    slots[i] = player;
                    send_assign(i, player);

                    mutex.unlock();
                    return true;
                }
            }

            mutex.unlock();

            player.close();
            return false;
        }

        public void player_disconnected(ServerPlayer player)
        {
            mutex.lock();

            for (int i = 0; i < slots.length; i++)
                if (slots[i] == player)
                {
                    mutex.unlock();
                    kick_slot(i);
                    return;
                }

            mutex.unlock();
        }

        private void message_received(ServerPlayer player, ClientMessage message)
        {
            parser.execute(player, message);
        }

        private void send_assign(int slot, ServerPlayer player)
        {
            send_assign_name(slot, player.name);
        }

        private void send_assign_name(int slot, string name)
        {
            ServerMessageMenuSlotAssign message = new ServerMessageMenuSlotAssign(slot, name);
            foreach (ServerPlayer p in players)
                p.send_message(message);
        }

        private void send_clear(int slot)
        {
            ServerMessageMenuSlotClear message = new ServerMessageMenuSlotClear(slot);
            foreach (ServerPlayer player in players)
                player.send_message(message);
        }

        private void send_settings()
        {
            ServerMessageMenuSettings message = new ServerMessageMenuSettings(settings);
            foreach (ServerPlayer player in players)
                player.send_message(message);
        }

        private void send_game_log(GameLog? log)
        {
            ServerMessageMenuGameLog message = new ServerMessageMenuGameLog(log == null ? null : "log");
            foreach (ServerPlayer player in players)
                player.send_message(message);
        }

        private void client_game_start(ServerPlayer player, ClientMessage message)
        {
            if (player != host)
                return;

            mutex.lock();

            if (players.size != 4 && log == null)
            {
                mutex.unlock();
                return;
            }

            foreach (ServerPlayer p in players)
            {
                p.receive_message.disconnect(message_received);
                p.disconnected.disconnect(player_disconnected);
            }

            int[] seats = RandomClass_seats(rnd, this.players.size);
            ArrayList<ServerPlayer> shuffled_players = new ArrayList<ServerPlayer>();
            for (int i = 0; i < this.players.size; i++)
                shuffled_players.add(this.players[seats[i]]);
            this.players = shuffled_players;

            GamePlayer[] players = new GamePlayer[this.players.size];
            for (int i = 0; i < players.length; i++)
                players[i] = new GamePlayer(i, this.players[i].name);

            mutex.unlock();

            GameStartInfo info = create_start_info(players);

            game_start(info);
        }

        private void client_add_bot(ServerPlayer player, ClientMessage message)
        {
            if (player != host)
                return;

            var msg = (ClientMessageMenuAddBot)message;

            Bot? bot = null;
            if (msg.name == "JulianBot")
                bot = new JulianBot();
            else if (msg.name == "SimpleBot")
                bot = new SimpleBot();
            else if (msg.name == "OracleBot")
                bot = new OracleBot();
            else if (msg.name == "ShantenBot")
                bot = new ShantenBot();
            else if (msg.name == "MortalBot")
                bot = new MortalBot();

            if (bot == null)
                return;

            mutex.lock();

            int slot = msg.slot;
            ServerPlayer bot_player = new ServerComputerPlayer(bot);
            players.add(bot_player);

            mutex.unlock();

            kick_slot(msg.slot);
            slots[slot] = bot_player;
            send_assign(slot, bot_player);
        }

        private void client_kick_player(ServerPlayer player, ClientMessage message)
        {
            if (player != host)
                return;

            var kick = (ClientMessageMenuKickPlayer)message;
            kick_slot(kick.slot);
        }

        private void kick_slot(int slot)
        {
            mutex.lock();

            ServerPlayer? p = slots[slot];
            if (p == null)
            {
                mutex.unlock();
                return;
            }

            p.disconnected.disconnect(player_disconnected);
            p.receive_message.disconnect(message_received);
            players.remove(p);
            send_clear(slot);
            slots[slot] = null;

            mutex.unlock();
            p.close();
        }

        private void client_settings(ServerPlayer player, ClientMessage message)
        {
            if (player != host)
                return;

            var s = (ClientMessageMenuSettings)message;
            settings = s.settings;

            send_settings();
        }

        private void client_log_file(ServerPlayer player, ClientMessage message)
        {
            if (player != host)
                return;

            var l = (ClientMessageMenuGameLog)message;
            log = l.log;
            do_log = (log != null && Environment.compatible(log.version));

            if (log != null && !Environment.compatible(log.version))

            if (!do_log)
                log = null;

            send_game_log(log);

            if (do_log)
            {
                settings = log.settings;
                send_settings();

                GamePlayer[] players = log.start_info.get_players();
                foreach (GamePlayer p in players)
                    send_assign_name(p.ID, p.name);
            }
        }

        private int[] RandomClass_seats(RandomClass rnd, int count)
        {
            int[] seats = new int[count];

            for (int i = 0; i < count; i++)
                seats[i] = i;

            for (int i = 0; i < count; i++)
            {
                int tmp = rnd.int_range(0, count);
                int a = seats[i];
                seats[i] = seats[tmp];
                seats[tmp] = a;
            }

            return seats;
        }

        private GameStartInfo create_start_info(GamePlayer[] players)
        {
            int starting_dealer = 0;
            int starting_score = 500;
            int round_count = 8;
            //  Unlike a single hand, a hanchan is won by having the highest total score at the end of the game.
            int hanchan_count = 1;
            //  int uma_higher = 20;
            //  int uma_lower = 10;

            // Use default animation timings
            AnimationTimings timings = AnimationTimings.create_default(settings.decision_time);

            GameStartInfo info = new GameStartInfo
            (
                players,
                timings,
                starting_dealer,
                starting_score,
                round_count,
                hanchan_count
                //  ,uma_higher,
                //  uma_lower
            );

            return info;
        }

        public ServerPlayer? host { get; private set; }
        public ArrayList<ServerPlayer> players { get; private set; }
        public ArrayList<ServerPlayer> observers { get; private set; }
        public ServerSettings settings { get; private set; }
        public bool do_log { get; private set; }
        public GameLog? log { get; private set; }
    }
}
