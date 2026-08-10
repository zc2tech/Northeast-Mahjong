using Engine;
using Gee;
using GameServer;

class MainMenuView : MenuSubView
{
    public signal GameController menu_game_start(GameStartInfo info, ServerSettings settings, IGameConnection connection, int player_index);
    public signal void restart();

    public void show_log_selection()
    {
        // Navigate directly to log selection without going through singleplayer menu
        SelectGameLogMenuView log_view = new SelectGameLogMenuView();
        log_view.finish.connect(load_log);
        load_sub_view(log_view);
    }

    private void singleplayer()
    {
        SingleplayerMenuView singleplayer_menu_view = new SingleplayerMenuView();
        singleplayer_menu_view.menu_game_start.connect(game_start);
        load_sub_view(singleplayer_menu_view);
    }

    private void multiplayer()
    {
        MultiplayerMenuView multiplayer_menu_view = new MultiplayerMenuView();
        multiplayer_menu_view.menu_game_start.connect(game_start);
        load_sub_view(multiplayer_menu_view);
    }

    private void options()
    {
        OptionsMenuView options_view = new OptionsMenuView();
        options_view.finish.connect(options_apply);
        load_sub_view(options_view);
    }

    private void about()
    {
        AboutMenuView about_view = new AboutMenuView();
        load_sub_view(about_view);
    }

    private void options_apply()
    {
        restart();
    }

    private void load_log(MenuSubView view)
    {
        SelectGameLogMenuView v = (SelectGameLogMenuView)view;

        // Create ServerMenuView with the log
        // Auto-start will happen automatically in load_finished() when log != null
        ServerMenuView s = new ServerMenuView.use_log(v.log);
        s.start.connect(log_game_start);
        load_sub_view(s);

        // Hide the lobby UI immediately for replay
        s.set_visibility(false);
    }

    private void log_game_start(GameStartInfo info, ServerSettings settings, IGameConnection connection, int player_index)
    {
        game_start(info, settings, connection, player_index);
    }

    private GameController game_start(GameStartInfo info, ServerSettings settings, IGameConnection connection, int player_index)
    {
        return menu_game_start(info, settings, connection, player_index);
    }

    protected override void key_press(KeyArgs key)
    {
        if (key.handled)
            return;

        // Only handle keys if our buttons are visible
        if (!are_buttons_visible())
            return;

        // Check if no modifier keys are pressed
        if (key.down && key.modifiers == Modifier.NONE)
        {
            key.handled = true;

            if (key.scancode == ScanCode.S)
                singleplayer();
            else if (key.scancode == ScanCode.M)
                multiplayer();
            else if (key.scancode == ScanCode.O)
                options();
            else if (key.scancode == ScanCode.A)
                about();
            else if (key.scancode == ScanCode.E)
                do_finish();
            else
                key.handled = false;
        }
    }

    protected override ArrayList<MenuTextButton>? get_main_buttons()
    {
        ArrayList<MenuTextButton> buttons = new ArrayList<MenuTextButton>();

        MenuTextButton singleplayer_button = new MenuTextButton("MenuButtonBig", "Singleplayer (S)");
        singleplayer_button.clicked.connect(singleplayer);
        buttons.add(singleplayer_button);

        MenuTextButton multiplayer_button = new MenuTextButton("MenuButtonBig", "Multiplayer (M)");
        multiplayer_button.clicked.connect(multiplayer);
        buttons.add(multiplayer_button);

        MenuTextButton options_button = new MenuTextButton("MenuButtonBig", "Options (O)");
        options_button.clicked.connect(options);
        buttons.add(options_button);

        MenuTextButton about_button = new MenuTextButton("MenuButtonBig", "About (A)");
        about_button.clicked.connect(about);
        buttons.add(about_button);

        MenuTextButton exit_button = new MenuTextButton("MenuButtonBig", "Exit (E)");
        exit_button.clicked.connect(do_finish);
        buttons.add(exit_button);

        return buttons;
    }
}

class MainMenuControlView : View2D
{
    private MainMenuBackgroundView background_view;
    private MainMenuView main_view;

    public signal GameController game_start(GameStartInfo info, ServerSettings settings, IGameConnection connection, int player_index);
    public signal void restart();
    public signal void quit();

    public MainMenuControlView()
    {
        Options options = new Options.from_disk();
        background_view = new MainMenuBackgroundView(options.tile_textures, options.tile_fore_color, options.tile_back_color);
    }

    public void show_log_selection()
    {
        // Navigate to singleplayer menu and then to log selection
        main_view.show_log_selection();
    }

    private GameController menu_game_start(GameStartInfo info, ServerSettings settings, IGameConnection connection, int player_index)
    {
        return game_start(info, settings, connection, player_index);
    }

    private void do_restart()
    {
        restart();
    }

    private void do_quit()
    {
        quit();
    }

    protected override void resized()
    {
        main_view.size = Size2(size.width, size.height - 70);
    }

    protected override void added()
    {
        add_child(background_view);

        main_view = new MainMenuView();
        main_view.menu_game_start.connect(menu_game_start);
        main_view.restart.connect(do_restart);
        main_view.finish.connect(do_quit);
        add_child(main_view);
        main_view.resize_style = ResizeStyle.ABSOLUTE;
        main_view.inner_anchor = Vec2(0.5f, 0);
        main_view.outer_anchor = Vec2(0.5f, 0);
    }
}
