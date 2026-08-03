using Gee;
using Engine;

namespace GameServer
{
    // Dedicated controller for bot simulation - no UI, no replay, no menu
    class BotController : Object
    {
        private RegularServer server;
        private ArrayList<ServerPlayer> players;
        private ClientMessageParser parser = new ClientMessageParser();
        private bool finished = false;

        public BotController(ArrayList<ServerPlayer> players, RandomClass rnd, GameStartInfo info, ServerSettings settings)
        {
            this.players = players;

            // Connect player message signals
            foreach (ServerPlayer player in players)
                player.receive_message.connect(message_received);

            // Create server
            server = new RegularServer(players, new ArrayList<ServerPlayer>(), rnd, info, settings);
        }

        public void run()
        {
            Timer timer = new Timer();

            while (!finished && !server.finished)
            {
                float time = (float)timer.elapsed();

                // Process any messages from bots
                process_messages(time);

                // Update server
                server.process(time);

                // Minimal sleep for CPU
                Thread.usleep(100); // 0.1ms
            }
        }

        private void process_messages(float time)
        {
            ClientMessageParser.ClientMessageTuple? message;
            while ((message = parser.dequeue()) != null)
            {
                server.message_received(message.player, message.message);
            }
        }

        private void message_received(ServerPlayer player, ClientMessage message)
        {
            parser.add(player, message);
        }
    }
}
