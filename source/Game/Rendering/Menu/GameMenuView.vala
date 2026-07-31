using Engine;
using Gee;

class GameMenuView : View2D
{
    private ScoringView? score_view = null;
    private ArrayList<MenuButton> action_buttons = new ArrayList<MenuButton>();
    private ArrayList<MenuButton> observer_buttons = new ArrayList<MenuButton>();

    private GameRenderContext context;
    private ServerSettings settings;
    private bool observing;
    private bool is_replay;

    private Sound hint_sound;
    private float start_time;
    private LabelControl timer;
    private LabelControl speed_toast;
    private int speed_toast_frames = 0;

    private MenuButton chii;
    private MenuButton pon;
    private MenuButton kan;
    private MenuButton tsumo;
    private MenuButton ron;
    private MenuButton conti; // "conti" is usually shorthand for continuance or dealer continuation
    private MenuButton void_hand;

    private MenuButton next;
    private MenuButton prev;
    private MenuButton speed_up;
    private MenuButton speed_down;
    private MenuButton pause_continue;

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
    public signal void speed_up_pressed();
    public signal void speed_down_pressed();
    public signal void pause_continue_pressed();

    private void press_chii() { chii_pressed(); }
    private void press_pon() { pon_pressed(); }
    private void press_kan() { kan_pressed(); }
   
    private void press_tsumo() { tsumo_pressed(); }
    private void press_ron() { ron_pressed(); }
    private void press_continue() { continue_pressed(); }
    private void press_void_hand() { void_hand_pressed(); }

    private void press_next() { observe_next_pressed(); score_view.next(); }
    private void press_prev() { observe_prev_pressed(); score_view.prev(); }
    private void press_speed_up() { speed_up_pressed(); }
    private void press_speed_down() { speed_down_pressed(); }
    private void press_pause_continue() {
        Environment.log(LogType.DEBUG, "GameMenuView", "press_pause_continue called");
        pause_continue_pressed();
    }

    public GameMenuView(GameRenderContext context, ServerSettings settings, int player_index, bool observing)
    {
        this.context = context;
        this.settings = settings;
        this.player_index = player_index;
        this.observing = observing;

        Environment.log(LogType.DEBUG, "GameMenuView", @"Created with: observing=$observing, is_replay=$is_replay, settings.is_replay_mode=$(settings.is_replay_mode)");

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

        // Speed toast notification
        speed_toast = new LabelControl();
        add_child(speed_toast);
        speed_toast.inner_anchor = Vec2(0.5f, 0.5f);
        speed_toast.outer_anchor = Vec2(0.5f, 0.5f);
        speed_toast.position = Vec2(0, -100);
        speed_toast.font_size = 40;
        speed_toast.visible = false;
        speed_toast.color = Color(1, 1, 0.5f, 1);  // Light yellow

        // Action buttons - always created
        chii = new MenuButton("Chii");
        pon = new MenuButton("Pon");
        kan = new MenuButton("Kan");
        tsumo = new MenuButton("Tsumo");
        ron = new MenuButton("Ron");
        conti = new MenuButton("Continue");
        void_hand = new MenuButton("VoidHand");

        chii.clicked.connect(press_chii);
        pon.clicked.connect(press_pon);
        kan.clicked.connect(press_kan);
        tsumo.clicked.connect(press_tsumo);
        ron.clicked.connect(press_ron);
        conti.clicked.connect(press_continue);
        void_hand.clicked.connect(press_void_hand);

        action_buttons.add(chii);
        action_buttons.add(pon);
        action_buttons.add(kan);
        action_buttons.add(tsumo);
        action_buttons.add(ron);
        action_buttons.add(conti);
        action_buttons.add(void_hand);

        // Only create observer buttons in replay mode
        if (is_replay)
        {
            next = new MenuButton("replay_next");
            prev = new MenuButton("replay_prev");
            speed_up = new MenuButton("replay_speedup");
            speed_down = new MenuButton("replay_speeddown");
            pause_continue = new MenuButton("replay_pause");

            next.clicked.connect(press_next);
            prev.clicked.connect(press_prev);
            speed_up.clicked.connect(press_speed_up);
            speed_down.clicked.connect(press_speed_down);
            pause_continue.clicked.connect(press_pause_continue);

            observer_buttons.add(prev);
            observer_buttons.add(next);
            observer_buttons.add(speed_down);
            observer_buttons.add(speed_up);
            observer_buttons.add(pause_continue);
        }

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
            button.enabled = true;  // Enable observer buttons for proper rendering and hover effects
            button.inner_anchor = Vec2(0.5f, 0);
            button.outer_anchor = Vec2(0.5f, 0);
            button.visible = observing;
        }

        Environment.log(LogType.INFO, "GameMenuView", @"Observer buttons: observing=$(observing), is_replay=$(is_replay), count=$(observer_buttons.size)");

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

        Environment.log(LogType.INFO, "GameMenuView", @"Positioning observer buttons: total_width=$(width)");

        foreach (var button in observer_buttons)
        {
            if (!button.visible || button.size.width == 0)
            {
                //  Environment.log(LogType.INFO, "GameMenuView", @"Skipping button: visible=$(button.visible), size=$(button.size.width)");
                continue;
            }

            button.position = Vec2(button.size.width / 2 - width + p, 120);
            Environment.log(LogType.INFO, "GameMenuView", @"Button positioned at: $(button.position.x), $(button.position.y), size=$(button.size.width)");
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
            // Keyboard shortcuts for observer buttons (replay mode only)
            else if ((key.scancode == ScanCode.COMMA || key.scancode == ScanCode.LEFT) && prev != null && prev.visible)
                press_prev();
            else if ((key.scancode == ScanCode.PERIOD || key.scancode == ScanCode.RIGHT) && next != null && next.visible)
                press_next();
            // Keyboard shortcuts for replay speed control
            else if (key.scancode == ScanCode.PAGEUP && speed_up != null && speed_up.visible)
                press_speed_up();
            else if (key.scancode == ScanCode.PAGEDOWN && speed_down != null && speed_down.visible)
                press_speed_down();
            else if (key.scancode == ScanCode.SPACE && pause_continue != null && pause_continue.visible)
            {
                Environment.log(LogType.DEBUG, "GameMenuView", "Spacebar pressed, calling pause_continue");
                press_pause_continue();
            }
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

        // Update speed toast visibility (hide after ~90 frames = ~1.5 seconds)
        if (speed_toast_frames > 0)
        {
            speed_toast_frames--;
            if (speed_toast_frames == 0)
                speed_toast.visible = false;
        }

        if (!timer.visible)
            return;

        float decision_time = context.get_decision_time();
        int t = int.max((int)(start_time + decision_time - delta.time), 0);
        if (t == decision_time)
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

    public void show_speed_toast(float speed_multiplier)
    {
        speed_toast.text = @"Speed: $(speed_multiplier)x";
        speed_toast.visible = true;
        speed_toast_frames = 90;  // Show for ~1.5 seconds (90 frames at 60fps)
    }

    public void show_speed_toast_text(string text)
    {
        speed_toast.text = text;
        speed_toast.visible = true;
        speed_toast_frames = 90;  // Show for ~1.5 seconds
    }

    public void set_pause_button_icon(bool is_paused)
    {
        // When paused, show Play icon (▶)
        // When playing, show Pause icon (||)
        // We need to reload the button's texture by recreating the ImageControl

        if (pause_continue == null)
            return;

        // Find the ImageControl child and update its texture
        string icon_name = is_paused ? "replay_play" : "replay_pause";

        // Unfortunately MenuButton doesn't expose a way to change the image
        // We need to track the button index, remove it, create new one at same position
        int button_index = observer_buttons.index_of(pause_continue);
        if (button_index < 0)
            return;

        // Store button state
        bool was_visible = pause_continue.visible;
        bool was_enabled = pause_continue.enabled;
        Vec2 button_pos = pause_continue.position;
        Vec2 inner_anchor = pause_continue.inner_anchor;
        Vec2 outer_anchor = pause_continue.outer_anchor;

        // Remove old button
        remove_child(pause_continue);
        observer_buttons.remove_at(button_index);

        // Create new button with correct icon
        pause_continue = new MenuButton(icon_name);
        pause_continue.clicked.connect(press_pause_continue);
        pause_continue.enabled = was_enabled;
        pause_continue.inner_anchor = inner_anchor;
        pause_continue.outer_anchor = outer_anchor;
        pause_continue.visible = was_visible;
        pause_continue.position = button_pos;

        // Insert at same index
        observer_buttons.insert(button_index, pause_continue);
        add_child(pause_continue);
    }

    public int player_index { get; set; }
}
