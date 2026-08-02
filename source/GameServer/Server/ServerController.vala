using Gee;
using Engine;

namespace GameServer
{
    public class ServerController : Object
    {
        private Server server;
        private ReplayServer replay_server;
        private ServerMenu menu = new ServerMenu();
        private ServerNetworking? net = null;
        private ClientMessageParser parser = new ClientMessageParser();

        private ServerPlayer host;
        private ArrayList<ServerPlayer> players;
        private ArrayList<ServerPlayer> observers;
        private GameLog? log;
        private ServerSettings settings;
        private GameStartInfo info;
        private RandomClass rnd = new RandomClass();

        private Mutex mutex = Mutex();
        private bool started = false;
        private bool finished = false;
        private bool is_replay = false;

        public ServerController()
        {
            menu.game_start.connect(game_start);
        }

        ~ServerController()
        {
            close_network();
        }

        public bool start_listening(uint16 port)
        {
            if (net != null)
                return false;

            net = new ServerNetworking();
            net.player_connected.connect(player_connected);

            return net.listen(port);
        }

        public void stop_listening()
        {
            if (net != null)
                net.stop_listening();
        }

        public void close_network()
        {
            if (net != null)
                net.close();
        }

        public void add_player(ServerPlayer player)
        {
            mutex.lock();

            if (!started)
                player_connected(player);

            mutex.unlock();
        }

        public void kill()
        {
            finished = true;
        }

        private void player_connected(ServerPlayer player)
        {
            menu.player_connected(player);
        }

        private void game_start(GameStartInfo info)
        {
            mutex.lock();

            if (started)
            {
                mutex.unlock();
                return;
            }

            started = true;

            if (net != null)
            {
                net.player_connected.disconnect(player_connected);
                stop_listening();
            }

            host = menu.host;

            foreach (ServerPlayer player in menu.players)
                player.disconnected.connect(player_disconnected);

            if(menu.do_log)
            {
                observers = menu.players;
                foreach (var player in menu.observers)
                    observers.add(player);
                players = new ArrayList<ServerPlayer>();

                log = menu.log;
                // Clone the settings from log to avoid modifying the original
                settings = new ServerSettings.from_settings(log.settings);
                settings.is_replay_mode = true;  // Mark as replay mode
                this.info = log.start_info;

                // Use NEW clean replay system
                replay_server = new ReplayServer(observers, settings, log);
                is_replay = true;

                Environment.log(LogType.DEBUG, "ServerController", "Created ReplayServer");
            }
            else
            {
                players = menu.players;
                observers = menu.observers;
                settings = menu.settings;
                settings.is_replay_mode = false;  // Ensure normal game mode
                this.info = info;

                foreach (ServerPlayer player in players)
                    player.receive_message.connect(message_received);

                server = new RegularServer(players, observers, rnd, info, settings);
            }

            foreach (ServerPlayer player in observers)
                player.receive_message.connect(message_received);

            menu = null;

            ref(); // Keep alive until graceful shutdown
            Threading.start0(server_worker);

            mutex.unlock();
        }

        private void server_worker()
        {
            // Server was already created in game_start() - don't recreate it here!
            Timer timer = new Timer();

            if (is_replay)
            {
                while (!finished && !replay_server.finished)
                {
                    mutex.lock();
                    float time = (float)timer.elapsed();
                    process_messages(time);
                    replay_server.process(time);
                    mutex.unlock();
                    sleep();
                }

                // TODO: if you want to realize 'replay same hand' function, 
                // you should do something before 'die' to send message to this Cotroller
                // watch how ClientMessageReplayPause is processed

                die();
                unref(); // Allow graceful deallocation
            }
            else
            {
                //  while (!finished && !server.finished)
                while (!finished && !server.finished)
                {
                    mutex.lock();
                    float time = (float)timer.elapsed();
                    process_messages(time);
                    server.process(time);
                    mutex.unlock();
                    sleep();
                }
                die();
                unref(); // Allow graceful deallocation
            }

         
        }

        private void sleep()
        {
            Thread.usleep(50000); // Server is not cpu intensive at all (can save cycles)
        }

        private void process_messages(float time)
        {
            ClientMessageParser.ClientMessageTuple? message;
            while ((message = parser.dequeue()) != null)
            {
                if (message.message is ClientMessageReplayPause)
                {
                    ClientMessageReplayPause pause_msg = message.message as ClientMessageReplayPause;
                    if (is_replay)
                        replay_server.set_paused(pause_msg.paused, time);
                }
                else if (message.message is ClientMessageReplaySpeed)
                {
                    ClientMessageReplaySpeed speed_msg = message.message as ClientMessageReplaySpeed;
                    if (is_replay)
                        replay_server.set_speed(speed_msg.multiplier);
                }
                else
                {
                    if (is_replay)
                        replay_server.message_received(message.player, message.message);
                    else
                        server.message_received(message.player, message.message);
                }
            }
        }

        private void message_received(ServerPlayer player, ClientMessage message)
        {
            parser.add(player, message);
        }

        private void player_disconnected(ServerPlayer player)
        {
            if (player == host)
            {
                kill();
                return;
            }

            mutex.lock();
            if (is_replay)
                replay_server.player_disconnected(player);
            else
                server.player_disconnected(player);
            mutex.unlock();
        }

        private void die()
        {
            foreach (ServerPlayer player in players)
            {
                player.disconnected.disconnect(player_disconnected);
                player.close();
            }

            foreach (ServerPlayer player in observers)
            {
                player.disconnected.disconnect(player_disconnected);
                player.close();
            }

            close_network();
        }
    }
}
