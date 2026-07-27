using Gee;
using Engine;

public class ServerSettings : Serializable
{
    private string dir = Environment.get_user_dir() + "server_settings.cfg";

    public ServerSettings.default()
    {
        multiple_ron = OnOffEnum.OFF;  // Only first player wins
        triple_ron_draw = OnOffEnum.ON;
        decision_time = 10;
        reveal_all_tiles = OnOffEnum.OFF;
        shuffle_tiles = OnOffEnum.ON;  // Default: shuffle tiles
    }

    public ServerSettings.from_disk()
    {
        this.default();
        load_disk();
    }

    public ServerSettings.from_string(string settings)
    {
        this.default();
        load_string(settings);
    }

    public ServerSettings.from_settings(ServerSettings settings)
    {
        this.default();
        load_from_string(settings.to_string());
    }

    public void load_disk()
    {
        string[] settings = FileLoader.load(dir);
        load_from_string(settings);
    }

    public void load_string(string settings)
    {
        string[] s = FileLoader.load(dir);
        load_from_string(s);
    }

    private void load_from_string(string[] settings)
    {
        foreach (string setting in settings)
        {
            string[] parts = setting.split("=", 2);

            if (parts.length < 2)
                continue;

            string name = parts[0].strip().down();
            string value = parts[1].strip().down();

            if (name == "" || value == "")
                continue;

            parse_name(name, value);
        }
    }

    public new string[] to_string()
    {
        ArrayList<string> settings = new ArrayList<string>();

        settings.add("multiple_ron = " + on_off_enum_to_string(multiple_ron));
        settings.add("triple_ron_draw = " + on_off_enum_to_string(triple_ron_draw));
        settings.add("decision_time = " + decision_time.to_string());
        settings.add("reveal_all_tiles = " + on_off_enum_to_string(reveal_all_tiles));
        settings.add("shuffle_tiles = " + on_off_enum_to_string(shuffle_tiles));

        return settings.to_array();
    }

    public void save()
    {
        string[] settings = to_string();
        FileLoader.save(dir, settings);
    }

    private void parse_name(string name, string value)
    {
        switch (name)
        {
        case "multiple_ron":
            multiple_ron = parse_on_off_enum(value);
            break;
        case "triple_ron_draw":
            triple_ron_draw = parse_on_off_enum(value);
            break;
        case "decision_time":
            decision_time = int.parse(value).clamp(2, 120);
            break;
        case "reveal_all_tiles":
            reveal_all_tiles = parse_on_off_enum(value);
            break;
        case "shuffle_tiles":
            shuffle_tiles = parse_on_off_enum(value);
            break;
        }
    }

    public OnOffEnum multiple_ron { get; set; }
    public OnOffEnum triple_ron_draw { get; set; }
    public int decision_time { get; set; }
    public OnOffEnum reveal_all_tiles { get; set; }
    public OnOffEnum shuffle_tiles { get; set; }
}
