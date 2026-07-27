using Engine;
using Gee;

class GameMenuView : View2D
{
    private ScoringView? score_view = null;
    private ArrayList<MenuButton> action_buttons = new ArrayList<MenuButton>();
    private ArrayList<MenuTextButton> observer_buttons = new ArrayList<MenuTextButton>();

    private GameRenderContext context;
    private ServerSettings settings;
    private bool observing;

    private Sound hint_sound;
    private float start_time;
    private LabelControl timer;

    private MenuButton chii;
    private MenuButton pon;
    private MenuButton kan;
    private MenuButton tsumo;
    private MenuButton ron;
    private MenuButton conti; // "conti" is usually shorthand for continuance or dealer continuation
    private MenuButton void_hand;

    private MenuTextButton next;
    private MenuTextButton prev;

    public signal void chii_pressed();
    public signal void pon_pressed();
    public signal void kan_pressed();
    public signal void tsumo_pressed();
    public signal void ron_pressed();
    public signal void continue_pressed();
    public signal void void_hand_pressed();
    public signal void display_score_pressed();
    public signal void score_finished();

    public signal void observe_next_pressed();
    public signal void observe_prev_pressed();

    private void press_chii() { chii_pressed(); }
    private void press_pon() { pon_pressed(); }
    private void press_kan() { kan_pressed(); }
   
    private void press_tsumo() { tsumo_pressed(); }
    private void press_ron() { ron_pressed(); }
    private void press_continue() { continue_pressed(); }
    private void press_void_hand() { void_hand_pressed(); }

    private void press_next() { observe_next_pressed(); score_view.next(); }
    private void press_prev() { observe_prev_pressed(); score_view.prev(); }

    public GameMenuView(GameRenderContext context, ServerSettings settings, int player_index, bool observing)
    {
        this.context = context;
        this.settings = settings;
        this.player_index = player_index;
        this.observing = observing;

        score_view = new ScoringView(context, player_index, observing);
        score_view.score_finished.connect(do_score_finished);
    }

    public override void added()
    {
        hint_sound = store.audio_player.load_sound("hint");

        int padding = 30;
        timer = new LabelControl();
        add_child(timer);
        timer.inner_anchor = Vec2(1, 0);
        timer.outer_anchor = Vec2(1, 0);
        timer.position = Vec2(-padding, padding / 2);
        timer.font_size = 60;
        timer.visible = false;

        chii = new MenuButton("Chii");
        pon = new MenuButton("Pon");
        kan = new MenuButton("Kan");
        tsumo = new MenuButton("Tsumo");
        ron = new MenuButton("Ron");
        conti = new MenuButton("Continue");
        void_hand = new MenuButton("VoidHand");

        next = new MenuTextButton("MenuButtonSmall", "Next");
        prev = new MenuTextButton("MenuButtonSmall", "Previous");

        chii.clicked.connect(press_chii);
        pon.clicked.connect(press_pon);
        kan.clicked.connect(press_kan);
        tsumo.clicked.connect(press_tsumo);
        ron.clicked.connect(press_ron);
        conti.clicked.connect(press_continue);
        void_hand.clicked.connect(press_void_hand);

        next.clicked.connect(press_next);
        prev.clicked.connect(press_prev);

        action_buttons.add(chii);
        action_buttons.add(pon);
        action_buttons.add(kan);
        action_buttons.add(tsumo);
        action_buttons.add(ron);
        action_buttons.add(conti); // "conti" is usually shorthand for continuance or dealer continuation
        action_buttons.add(void_hand);

        observer_buttons.add(prev);
        observer_buttons.add(next);

        foreach (var button in action_buttons)
        {
            add_child(button);
            button.enabled = false;
            button.inner_anchor = Vec2(0.5f, 0);
            button.outer_anchor = Vec2(0.5f, 0);
            button.visible = !observing;
        }

        foreach (var button in observer_buttons)
        {
            add_child(button);
            button.inner_anchor = Vec2(0.5f, 0);
            button.outer_anchor = Vec2(0.5f, 0);
            button.font_size = 14;
            button.visible = observing;
        }

        void_hand.visible = false;
        position_action_buttons();
        position_observer_buttons();

        add_child(score_view);
    }

    private void position_action_buttons()
    {
        float p = 0;
        float width = 0;

        foreach (var button in action_buttons)
        {
            if (button.visible && button.size.width > 0)
                width += button.size.width / 2;
        }

        foreach (var button in action_buttons)
        {
            if (!button.visible || button.size.width == 0)
                continue;

            button.position = Vec2(button.size.width / 2 - width + p, 120);
            p += button.size.width;
        }
    }

    private void position_observer_buttons()
    {
        float p = 0;
        float width = 0;

        foreach (var button in observer_buttons)
        {
            if (button.visible && button.size.width > 0)
                width += button.size.width / 2;
        }

        foreach (var button in observer_buttons)
        {
            if (!button.visible || button.size.width == 0)
                continue;

            button.position = Vec2(button.size.width / 2 - width + p, 120);
            p += button.size.width;
        }
    }

    protected override void key_press(KeyArgs key)
    {
        if (key.handled)
            return;

        key.handled = true;

        if (key.scancode == ScanCode.TAB && !key.repeat)
        {
            if (key.down)
                display_score();
            else
                hide_score();
        }
        else if (key.down && !key.repeat)
        {
            // Keyboard shortcuts for game action buttons
            if (key.scancode == ScanCode.C && chii.enabled && chii.visible)
                press_chii();
            else if (key.scancode == ScanCode.P && pon.enabled && pon.visible)
                press_pon();
            else if (key.scancode == ScanCode.K && kan.enabled && kan.visible)
                press_kan();
            else if (key.scancode == ScanCode.T && tsumo.enabled && tsumo.visible)
                press_tsumo();
            else if (key.scancode == ScanCode.R && ron.enabled && ron.visible)
                press_ron();
            else if (key.scancode == ScanCode.SPACE && conti.enabled && conti.visible)
                press_continue();
            else if (key.scancode == ScanCode.V && void_hand.enabled && void_hand.visible)
                press_void_hand();
            else
                key.handled = false;
        }
        else
            key.handled = false;
    }

    public void set_chii(bool enabled)
    {
        chii.enabled = enabled;
    }

    public void set_pon(bool enabled)
    {
        pon.enabled = enabled;
    }

    public void set_kan(bool enabled)
    {
        kan.enabled = enabled;
    }

    public void set_tsumo(bool enabled)
    {
        tsumo.enabled = enabled;
    }

    public void set_ron(bool enabled)
    {
        ron.enabled = enabled;
    }

    public void set_continue(bool enabled)
    {
        if (enabled)
            hint_sound.play();
        conti.enabled = enabled;
    }

    public void set_void_hand(bool enabled)
    {
        void_hand.visible = enabled;
        void_hand.enabled = enabled;
        position_action_buttons();
    }

    public void set_move_timer(bool enabled)
    {
        if (timer.visible && enabled)
            return;

        start_time = 0;
        timer.visible = enabled;
    }

    public void update_scores(RoundScoreState[] scores)
    {
        score_view.update_scores(scores);
    }

    public void game_over()
    {
        score_view.display(true);
    }

    public void round_finished()
    {
        score_view.display(true);

        foreach (var button in observer_buttons)
            button.enabled = false;
    }

    public void display_score()
    {
        score_view.display(false);
    }

    public void hide_score()
    {
        score_view.hide();
    }

    public void display_disconnected()
    {
        InformationMenuView view = new InformationMenuView("Connection to server lost");
        add_child(view);
        view.back.connect(info_menu_finished);
    }

    public void display_player_left(string name)
    {
        InformationMenuView view = new InformationMenuView(name + " has left the game");
        add_child(view);
        view.back.connect(info_menu_finished);
    }

    private void info_menu_finished(MenuSubView view)
    {
        remove_child(view);
    }

    private void do_score_finished()
    {
        score_finished();
    }

    protected override void process(DeltaArgs delta)
    {
        if (start_time == 0)
            start_time = delta.time;

        if (!timer.visible)
            return;

        int t = int.max((int)(start_time + context.server_times.decision_time - delta.time), 0);
        if (t == context.server_times.decision_time)
            t--;

        if (t < 0)
        {
            timer.visible = false;
            return;
        }

        timer.color = t < 3 ? Color.red() : Color.white();

        string str = t.to_string();

        if (str != timer.text)
            timer.text = str;
    }

    public int player_index { get; set; }
}
