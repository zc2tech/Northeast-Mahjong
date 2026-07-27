using Engine;
using Gee;

private static bool debug =
#if DEBUG
    true
#else
    false
#endif
;

private static bool run_tests = false;
private static bool multithread_rendering = false;
private static bool bot_simulation = false;
private static bool show_help = false;
private static int simulation_hands = 1;
private static bool simulation_hands_from_cmdline = false;

private static string? arg_search_dir = null;

// Bot simulation config
class BotConfig
{
    public string bot_type { get; set; }
    public string bot_name { get; set; }

    public BotConfig(string bot_type, string bot_name)
    {
        this.bot_type = bot_type;
        this.bot_name = bot_name;
    }
}

private static ArrayList<BotConfig> bot_configs;

private static void parse_args(string[] args)
{
    for (int i = 1; i < args.length; i++)
    {
        string arg = args[i];
        if (arg.length == 0 || arg[0] != '-')
            continue;
        arg = arg.substring(1);

        if (arg == "d" || arg == "-debug")
            debug = true;
        else if (arg == "-no-debug")
            debug = false;
        else if (arg == "-test")
            run_tests = true;
        else if (arg == "-multithread-rendering")
            multithread_rendering = true;
        else if (arg == "-no-multithread-rendering")
            multithread_rendering = false;
        else if (arg == "h" || arg == "-help")
            show_help = true;
        else if (arg == "-bot-simulation" || arg == "-bots")
        {
            bot_simulation = true;
            // Check if next argument is a number (number of hands)
            if (i + 1 < args.length)
            {
                string next_arg = args[i + 1];
                if (next_arg.length > 0 && next_arg[0] != '-')
                {
                    int hands = int.parse(next_arg);
                    if (hands > 0)
                    {
                        simulation_hands = hands;
                        simulation_hands_from_cmdline = true;
                        i++;
                    }
                }
            }
        }
        else if (arg == "-search-directory")
        {
            i++;

            if (i < args.length)
                arg_search_dir = args[i];
        }
    }
}

private static void load_bot_config(string config_path, bool hands_from_cmdline)
{
    // Initialize ArrayList
    bot_configs = new ArrayList<BotConfig>();

    // Set defaults
    bot_configs.add(new BotConfig("JulianBot", "Julian"));
    bot_configs.add(new BotConfig("SimpleBot", "Simple1"));
    bot_configs.add(new BotConfig("JulianBot", "Julian2"));
    bot_configs.add(new BotConfig("SimpleBot", "Simple2"));

    var file = File.new_for_path(config_path);
    if (!file.query_exists())
    {
        stdout.printf("Bot config file not found at %s, using defaults\n", config_path);
        return;
    }

    try
    {
        var input_stream = file.read();
        var data_stream = new DataInputStream(input_stream);
        string? line;

        while ((line = data_stream.read_line()) != null)
        {
            line = line.strip();

            // Skip comments and empty lines
            if (line.length == 0 || line[0] == '#')
                continue;

            // Parse key=value
            string[] parts = line.split("=", 2);
            if (parts.length != 2)
                continue;

            string key = parts[0].strip();
            string value = parts[1].strip();

            if (key == "hands")
            {
                // Only apply config file hands if not overridden by command-line
                if (!hands_from_cmdline)
                {
                    int hands = int.parse(value);
                    if (hands > 0)
                        simulation_hands = hands;
                }
            }
            else if (key == "player1")
                bot_configs[0].bot_type = value;
            else if (key == "player2")
                bot_configs[1].bot_type = value;
            else if (key == "player3")
                bot_configs[2].bot_type = value;
            else if (key == "player4")
                bot_configs[3].bot_type = value;
            else if (key == "player1_name")
                bot_configs[0].bot_name = value;
            else if (key == "player2_name")
                bot_configs[1].bot_name = value;
            else if (key == "player3_name")
                bot_configs[2].bot_name = value;
            else if (key == "player4_name")
                bot_configs[3].bot_name = value;
        }

        stdout.printf("Loaded bot config from %s\n", config_path);
    }
    catch (Error e)
    {
        stdout.printf("Error reading bot config: %s, using defaults\n", e.message);
    }
}

private static void show_error(string message)
{
    Environment.log(LogType.ERROR, "Main", message);
    show_error_message_box("Northeast-Mahjong (" + Environment.version_info.to_string() + ") startup error", message + "\n" + "Look at logs for more details");
}

private static void show_help_message()
{
    stdout.printf("Northeast-Mahjong (%s)\n\n", Environment.version_info.to_string());
    stdout.printf("Usage: Northeast-Mahjong [OPTIONS]\n\n");
    stdout.printf("Options:\n");
    stdout.printf("  -h, --help                    Show this help message\n");
    stdout.printf("  -d, --debug                   Enable debug mode\n");
    stdout.printf("  --no-debug                    Disable debug mode\n");
    stdout.printf("  --test                        Run hand tests and exit\n");
    stdout.printf("  --bot-simulation [N]          Bot simulation mode (config: bot_simulation.conf)\n");
    stdout.printf("  --bots [N]                    Alias for --bot-simulation\n");
    stdout.printf("  --multithread-rendering       Enable multithreaded rendering\n");
    stdout.printf("  --no-multithread-rendering    Disable multithreaded rendering\n");
    stdout.printf("  --search-directory <DIR>      Add custom search directory\n");
    stdout.printf("\n");
    stdout.printf("Bot simulation reads bot_simulation.conf for player configuration.\n");
    stdout.printf("Command-line [N] overrides the 'hands' setting in the config file.\n");
    stdout.printf("\n");
    stdout.printf("Keyboard Shortcuts (in-game):\n");
    stdout.printf("  C - Chii, P - Pon, K - Kan\n");
    stdout.printf("  T - Tsumo, R - Ron, V - Void Hand\n");
    stdout.printf("  Space - Continue, Tab - Show Scores\n");
    stdout.printf("  1/2 - Camera height, 3/4 - Target height\n");
    stdout.printf("\n");
}

private static void run_bot_simulation(int num_hands)
{
    stdout.printf("Bot simulation feature is not yet fully implemented.\n");
    stdout.printf("This requires exposing more APIs from RoundState for automated play.\n");
    stdout.printf("\n");
    stdout.printf("Configured bots:\n");
    for (int i = 0; i < 4; i++)
    {
        stdout.printf("  Player %d: %s (%s)\n", i + 1, bot_configs[i].bot_name, bot_configs[i].bot_type);
    }
    stdout.printf("\n");
    stdout.printf("For now, you can start a local server and add 4 bots manually.\n");
}

public static int main(string[] args)
{
    string? executable_dir = args.length > 0 ? GLib.Path.get_dirname(args[0]) : null;
    string? built_search_dir = Build.SEARCH_DIR;

    parse_args(args);

    if (show_help)
    {
        show_help_message();
        return 0;
    }

    if (run_tests)
    {
        stdout.printf("------------Starting hand tests --------\n");
        stdout.flush();
        test_hands();
        stdout.printf("------------Tests completed!-------------\n");
        stdout.flush();
        return 0;
    }

    if (bot_simulation)
    {
        stdout.printf("------------Starting bot simulation --------\n");

        // Load config file first (can be overridden by command-line)
        string config_path = "bot_simulation.conf";
        if (executable_dir != null)
            config_path = GLib.Path.build_filename(executable_dir, "bot_simulation.conf");

        load_bot_config(config_path, simulation_hands_from_cmdline);

        stdout.printf("Simulating %d hands with 4 bots\n", simulation_hands);
        stdout.flush();

        if (!Environment.init(debug))
        {
            show_error("Could not init environment for bot simulation");
            return -1;
        }

        run_bot_simulation(simulation_hands);
        stdout.printf("------------Bot simulation completed!-------\n");
        stdout.flush();
        return 0;
    }

    if (!Environment.init(debug))
    {
        show_error("Could not init environment");
        return -1;
    }

    FileLoader.init();
    FileLoader.add_search_path(executable_dir);
    FileLoader.add_search_path(built_search_dir);
    FileLoader.add_search_path(arg_search_dir);
    FileLoader.add_search_path(Environment.get_user_dir());

    if (FileLoader.find_directory("Data") == null)
    {
        show_error("Could not find Data directory in search paths");
        return -1;
    }

    while (true)
    {
        Options options = new Options.from_disk();
        int multisamples = options.anti_aliasing == OnOffEnum.ON ? 2 : 0;
        Size2i window_size = Size2i(options.window_width, options.window_height);
        Vec2i window_position = Vec2i(options.window_x, options.window_y);
        string window_name = "Northeast-Mahjong";

        SDLGLEngine engine = new SDLGLEngine(multithread_rendering, Environment.version_info.to_string(), debug);
        if (!engine.init(window_name, window_size, window_position, options.screen_type, multisamples))
        {
            show_error("Could not init engine");
            return -1;
        }

        MainWindow window = new MainWindow(engine.window, engine.renderer);

        window.show();
        engine.stop();

        if (!window.do_restart)
            break;
    }

    Environment.log(LogType.INFO, "Main", "Application stopped normally");

    return 0;
}