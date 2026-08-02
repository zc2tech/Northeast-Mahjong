using Engine;
using Gee;

class ReplayMenuView : View2D
{
    private ScoringView? score_view = null;
    private ArrayList<MenuButton> replay_buttons = new ArrayList<MenuButton>();

    private GameRenderContext context;
    private ServerSettings settings;

    private LabelControl speed_toast;
    private int speed_toast_frames = 0;

    private MenuButton next;
    private MenuButton prev;
    private MenuButton speed_up;
    private MenuButton speed_down;
    private MenuButton pause_continue;

    public signal void observe_next_pressed();
    public signal void observe_prev_pressed();
    public signal void speed_up_pressed();
    public signal void speed_down_pressed();
    public signal void pause_continue_pressed();
    public signal void next_hand_requested();
    public signal void replay_hand_requested();
    public signal void return_to_menu_requested();
    public signal void score_finished();

    private void press_next() {
        Environment.log(LogType.DEBUG, "ReplayMenuView", "press_next called");
        observe_next_pressed();
        if (score_view != null) score_view.next();
    }
    private void press_prev() {
        Environment.log(LogType.DEBUG, "ReplayMenuView", "press_prev called");
        observe_prev_pressed();
        if (score_view != null) score_view.prev();
    }
    private void press_speed_up() {
        Environment.log(LogType.DEBUG, "ReplayMenuView", "press_speed_up called");
        speed_up_pressed();
    }
    private void press_speed_down() {
        Environment.log(LogType.DEBUG, "ReplayMenuView", "press_speed_down called");
        speed_down_pressed();
    }
    private void press_pause_continue() {
        Environment.log(LogType.DEBUG, "ReplayMenuView", "press_pause_continue called");
        pause_continue_pressed();
    }

    public ReplayMenuView(GameRenderContext context, ServerSettings settings, int player_index)
    {
        this.context = context;
        this.settings = settings;

        Environment.log(LogType.DEBUG, "ReplayMenuView", "Created replay menu view");

        score_view = new ScoringView(context, player_index, true, true);  // observing=true, is_replay=true
        score_view.score_finished.connect(do_score_finished);
        score_view.next_hand_requested.connect(do_next_hand_requested);
        score_view.replay_hand_requested.connect(do_replay_hand_requested);
        score_view.return_to_menu_requested.connect(do_return_to_menu_requested);
    }

    public override void added()
    {
        // Speed toast notification
        speed_toast = new LabelControl();
        add_child(speed_toast);
        speed_toast.inner_anchor = Vec2(0.5f, 0.5f);
        speed_toast.outer_anchor = Vec2(0.5f, 0.5f);
        speed_toast.position = Vec2(0, -100);
        speed_toast.font_size = 40;
        speed_toast.visible = false;
        speed_toast.color = Color(1, 1, 0.5f, 1);  // Light yellow

        // Replay control buttons
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

        replay_buttons.add(prev);
        replay_buttons.add(pause_continue);
        replay_buttons.add(next);
        replay_buttons.add(speed_down);
        replay_buttons.add(speed_up);

        foreach (var button in replay_buttons)
        {
            add_child(button);
            button.enabled = true;
            button.inner_anchor = Vec2(0.5f, 0);
            button.outer_anchor = Vec2(0.5f, 0);
            button.visible = false;  // Hide replay control buttons (1-5), keep keyboard shortcuts working
        }

        position_replay_buttons();

        add_child(score_view);
    }

    private void position_replay_buttons()
    {
        // Layout: [Prev] [Play/Pause] [Next]  [Speed-] [Speed+]
        float button_spacing = 20;
        float group_spacing = 40;
        float y_position = 80;

        // Calculate total width
        float total_width = 0;
        for (int i = 0; i < replay_buttons.size; i++)
        {
            if (replay_buttons[i].visible && replay_buttons[i].size.width > 0)
            {
                total_width += replay_buttons[i].size.width;
                if (i > 0)
                {
                    // Group spacing after "next" button (index 2)
                    if (i == 3)
                        total_width += group_spacing;
                    else
                        total_width += button_spacing;
                }
            }
        }

        // Position buttons centered
        float current_x = -(total_width / 2);
        for (int i = 0; i < replay_buttons.size; i++)
        {
            MenuButton button = replay_buttons[i];
            if (!button.visible || button.size.width == 0)
                continue;

            button.position = Vec2(current_x + button.size.width / 2, y_position);
            current_x += button.size.width;

            if (i < replay_buttons.size - 1)
            {
                if (i == 2)  // After "next" button
                    current_x += group_spacing;
                else
                    current_x += button_spacing;
            }
        }
    }

    protected override void key_press(KeyArgs key)
    {
        if (key.handled)
            return;

        if (key.down && !key.repeat)
        {
            Environment.log(LogType.DEBUG, "ReplayMenuView", @"Key pressed: scancode=$(key.scancode)");

            key.handled = true;

            // Replay controls - don't check visible since buttons are hidden
            if ((key.scancode == ScanCode.COMMA || key.scancode == ScanCode.LEFT) && prev != null)
            {
                Environment.log(LogType.DEBUG, "ReplayMenuView", "Prev key detected");
                press_prev();
            }
            else if ((key.scancode == ScanCode.PERIOD || key.scancode == ScanCode.RIGHT) && next != null)
            {
                Environment.log(LogType.DEBUG, "ReplayMenuView", "Next key detected");
                press_next();
            }
            else if (key.scancode == ScanCode.UP && speed_up != null)
            {
                Environment.log(LogType.DEBUG, "ReplayMenuView", "Speed up key detected");
                press_speed_up();
            }
            else if (key.scancode == ScanCode.DOWN && speed_down != null)
            {
                Environment.log(LogType.DEBUG, "ReplayMenuView", "Speed down key detected");
                press_speed_down();
            }
            else if (key.scancode == ScanCode.SPACE && pause_continue != null)
            {
                Environment.log(LogType.DEBUG, "ReplayMenuView", "Spacebar detected");
                press_pause_continue();
            }
            else
            {
                Environment.log(LogType.DEBUG, "ReplayMenuView", "Key not handled");
                key.handled = false;
            }
        }
        else
            key.handled = false;
    }

    public void update_scores(RoundScoreState[] scores)
    {
        if (score_view != null)
            score_view.update_scores(scores);
    }

    public void round_finished()
    {
        if (score_view != null)
        {
            score_view.display(true);

            // Disable replay buttons during scoring
            foreach (var button in replay_buttons)
                button.enabled = false;
        }
    }

    public void game_over()
    {
        if (score_view != null)
            score_view.display(true);
    }

    private void do_score_finished()
    {
        score_finished();
    }

    private void do_next_hand_requested()
    {
        next_hand_requested();
    }

    private void do_replay_hand_requested()
    {
        replay_hand_requested();
    }

    private void do_return_to_menu_requested()
    {
        return_to_menu_requested();
    }

    protected override void process(DeltaArgs delta)
    {
        if (speed_toast == null)
            return;

        // Update speed toast visibility
        if (speed_toast_frames > 0)
        {
            speed_toast_frames--;
            if (speed_toast_frames == 0)
                speed_toast.visible = false;
        }
    }

    public void show_speed_toast(float speed_multiplier)
    {
        if (speed_toast == null)
            return;
        speed_toast.text = @"Speed: $(speed_multiplier)x";
        speed_toast.visible = true;
        speed_toast_frames = 90;
    }

    public void show_speed_toast_text(string text)
    {
        if (speed_toast == null)
            return;
        speed_toast.text = text;
        speed_toast.visible = true;
        speed_toast_frames = 90;
    }

    public void set_pause_button_icon(bool is_paused)
    {
        if (pause_continue == null)
            return;

        string icon_name = is_paused ? "replay_play" : "replay_pause";

        int button_index = replay_buttons.index_of(pause_continue);
        if (button_index < 0)
            return;

        bool was_visible = pause_continue.visible;
        bool was_enabled = pause_continue.enabled;
        Vec2 button_pos = pause_continue.position;
        Vec2 inner_anchor = pause_continue.inner_anchor;
        Vec2 outer_anchor = pause_continue.outer_anchor;

        remove_child(pause_continue);
        replay_buttons.remove_at(button_index);

        pause_continue = new MenuButton(icon_name);
        pause_continue.clicked.connect(press_pause_continue);
        pause_continue.enabled = was_enabled;
        pause_continue.inner_anchor = inner_anchor;
        pause_continue.outer_anchor = outer_anchor;
        pause_continue.visible = was_visible;
        pause_continue.position = button_pos;

        replay_buttons.insert(button_index, pause_continue);
        add_child(pause_continue);
    }

    public int player_index { get; set; }
}
