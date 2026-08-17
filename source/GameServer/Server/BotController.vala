using Gee;
using Engine;

namespace GameServer
{
    // Dedicated controller for bot simulation - no UI, no replay, no menu
    public class BotController : Object
    {
        private RegularServer server;
        private ArrayList<ServerPlayer> players;
        private ClientMessageParser parser = new ClientMessageParser();
        private bool finished = false;
        private int rounds_done = 0;
        private int total_rounds;

        public BotController(ArrayList<ServerPlayer> players, RandomClass rnd, GameStartInfo info, ServerSettings settings)
        {
            this.players = players;
            this.total_rounds = info.round_count;

            // Connect player message signals
            foreach (ServerPlayer player in players)
                player.receive_message.connect(message_received);

            // Create server
            server = new RegularServer(players, new ArrayList<ServerPlayer>(), rnd, info, settings);
            server.on_round_finished.connect(() => {
                rounds_done++;
                stdout.printf("%d/%d\n", rounds_done, total_rounds);
                stdout.flush();
            });
        }
        // Called from main.vala line 264
        // ignore the warning!!!
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
