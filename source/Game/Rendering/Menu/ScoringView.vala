using Engine;
using Gee;

class ScoringView : View2D
{
    private GameRenderContext context;
	private RoundScoreState[] scores;
    private int player_index;
    private int score_index;
    private LabelControl time_label;
    private LabelControl score_label;
    private RectangleControl rectangle;
    private MenuTextButton ready_button;
    private MenuTextButton next_hand_button;
    private MenuTextButton return_menu_button;
    private GameMenuButton next_score_button;
    private GameMenuButton prev_score_button;
    private ScoringInnerView scoring_view;
    private int padding = 10;
    private bool display_timer;
    private float time;
    private float start_time;
    private bool is_replay;

    public signal void score_finished();
    public signal void next_hand_requested();
    public signal void return_to_menu_requested();

    public ScoringView(GameRenderContext context, int player_index, bool observing, bool is_replay)
    {
        this.context = context;
        this.player_index = player_index;
        this.is_replay = is_replay;
        relative_size = Size2(0.9f, 0.9f);
    }

    public override void removed()
    {
        // Ensure scoring_view is properly removed and its sounds stopped
        if (scoring_view != null)
        {
            remove_child(scoring_view);
            scoring_view = null;
        }
        base.removed();
    }

    public override void added()
    {
        rectangle = new RectangleControl();
        add_child(rectangle);
        rectangle.resize_style = ResizeStyle.RELATIVE;
        rectangle.color = Color.with_alpha(0.7f);
        rectangle.selectable = true;
        rectangle.cursor_type = CursorType.NORMAL;

        time_label = new LabelControl();
        add_child(time_label);
        time_label.inner_anchor = Vec2(1, 0);
        time_label.outer_anchor = Vec2(1, 0);
        time_label.position = Vec2(-padding, padding);
        time_label.font_size = 60;
		time_label.visible = false;

        score_label = new LabelControl();
        add_child(score_label);
        score_label.inner_anchor = Vec2(0.5f, 1);
        score_label.outer_anchor = Vec2(0.5f, 1);
        score_label.position = Vec2(0, -padding);
        score_label.font_size = 40;
        score_label.text = "Scores";

        ready_button = new MenuTextButton("MenuButtonSmall", "Ready (R)");
        add_child(ready_button);
        ready_button.clicked.connect(ready_clicked);
        ready_button.inner_anchor = Vec2(0, 0);
        ready_button.outer_anchor = Vec2(0, 0);
        ready_button.position = Vec2(padding, padding);
        ready_button.visible = true;
        ready_button.enabled = true;

        // Replay mode buttons
        next_hand_button = new MenuTextButton("MenuButtonSmall", "Next Hand (N)");
        add_child(next_hand_button);
        next_hand_button.clicked.connect(next_hand_clicked);
        next_hand_button.inner_anchor = Vec2(0, 0);
        next_hand_button.outer_anchor = Vec2(0, 0);
        next_hand_button.position = Vec2(padding, padding);
        next_hand_button.visible = false;
        next_hand_button.enabled = true;

        return_menu_button = new MenuTextButton("MenuButtonSmall", "Return to Menu (M)");
        add_child(return_menu_button);
        return_menu_button.clicked.connect(return_menu_clicked);
        return_menu_button.inner_anchor = Vec2(1, 0);
        return_menu_button.outer_anchor = Vec2(1, 0);
        return_menu_button.position = Vec2(-padding, padding);
        return_menu_button.visible = false;
        return_menu_button.enabled = true;

        next_score_button = new GameMenuButton("Next");
        add_child(next_score_button);
        next_score_button.clicked.connect(next_score_clicked);
        next_score_button.inner_anchor = Vec2(0, 0.5f);
        next_score_button.outer_anchor = Vec2(0.5f, 1);
        next_score_button.size = Size2(score_label.size.height, score_label.size.height);
        next_score_button.position = Vec2(score_label.size.width / 2 + padding, -(score_label.size.height / 2 + padding));
        next_score_button.enabled = false;

        prev_score_button = new GameMenuButton("Prev");
        add_child(prev_score_button);
        prev_score_button.clicked.connect(prev_score_clicked);
        prev_score_button.inner_anchor = Vec2(1, 0.5f);
        prev_score_button.outer_anchor = Vec2(0.5f, 1);
        prev_score_button.size = Size2(score_label.size.height, score_label.size.height);
        prev_score_button.position = Vec2(-(score_label.size.width / 2 + padding), -(score_label.size.height / 2 + padding));
        prev_score_button.enabled = false;

        visible = false;
    }

    protected override void process(DeltaArgs delta)
    {
        if (start_time == 0)
            start_time = delta.time;

        int t = (int)(start_time + time - delta.time);

        if (t < 0)
        {
            display_timer = false;
            time_label.visible = false;
            return;
        }

        string str = t.to_string();

        if (str != time_label.text)
            time_label.text = str;
    }

    protected override void key_press(KeyArgs key)
    {
        if (key.handled || !visible)
            return;

        if (key.down && key.modifiers == Modifier.NONE)
        {
            key.handled = true;

            if (key.scancode == ScanCode.R && ready_button.enabled && ready_button.visible)
                ready_clicked();
            else if (key.scancode == ScanCode.N && next_hand_button.enabled && next_hand_button.visible)
                next_hand_clicked();
            else if (key.scancode == ScanCode.M && return_menu_button.enabled && return_menu_button.visible)
                return_menu_clicked();
            else
                key.handled = false;
        }
    }

    protected override void resized()
    {
        if (scoring_view == null)
            return;

        scoring_view.resize_style = ResizeStyle.ABSOLUTE;
        scoring_view.size = Size2(size.width - padding * 2, size.height - padding * 3 - score_label.size.height);
        scoring_view.inner_anchor = Vec2(0, 0);
        scoring_view.outer_anchor = Vec2(0, 0);
        scoring_view.position = Vec2(padding, padding);
    }

    public void update_scores(RoundScoreState[] scores)
    {
        this.scores = scores;
        score_index = scores.length - 1;
    }

    public void display(bool round_finished)
    {
        if (scores == null || scores.length == 0)
            return;

        visible = true;

        if (round_finished)
        {
            busy = true;

            if (is_replay)
            {
                // Show replay buttons instead of ready button
                ready_button.visible = false;
                next_hand_button.visible = true;
                return_menu_button.visible = true;
            }
            else
            {
                // Show normal ready button
                ready_button.visible = true;
                next_hand_button.visible = false;
                return_menu_button.visible = false;
            }
        }

        update_score_view(round_finished);

        next_score_button.visible = !round_finished;
        prev_score_button.visible = !round_finished;
    }

    public void next()
    {
        player_index = (player_index + 1) % 4;
        refresh_score();
    }

    public void prev()
    {
        player_index = (player_index + 3) % 4;
        refresh_score();
    }

    private void refresh_score()
    {
        if (scoring_view != null)
            remove_child(scoring_view);
        scoring_view = null;
        update_score_view(false);
    }

    private void update_score_view(bool round_finished)
    {
        check_score_change_buttons();

        var score = scores[score_index];
        if (scoring_view != null)
        {
            if (scoring_view.score == score && !round_finished)
                return;
            remove_child(scoring_view);
        }

        if (round_finished)
        {
            start_time = 0;
            time = context.server_times.get_animation_round_end_delay(score);
            time--; // Count down to 0
        }

        scoring_view = new ScoringInnerView(context, score, player_index, round_finished);
        scoring_view.animation_finished.connect(animation_finished);
        add_child(scoring_view);
        resized();
    }

    private void check_score_change_buttons()
    {
        prev_score_button.visible = true;
        next_score_button.visible = true;
        prev_score_button.enabled = score_index > 0;
        next_score_button.enabled = score_index < scores.length - 1;
    }

    public void hide()
    {
        if (!busy)
        {
            visible = false;
            prev_score_button.visible = false;
            next_score_button.visible = false;
        }
    }

    private void animation_finished()
    {
        busy = false;
        ready_button.enabled = true;
        time_label.visible = true;
        display_timer = true;
        check_score_change_buttons();
    }

    private void ready_clicked()
    {
        // Stop scoring sound effects when ready is clicked
        //  if (scoring_view != null)
        //      scoring_view.stop_sounds();

        score_finished();
        ready_button.enabled = false;
    }

    private void next_hand_clicked()
    {
        next_hand_requested();
        next_hand_button.enabled = false;
    }

    private void return_menu_clicked()
    {
        return_to_menu_requested();
        return_menu_button.enabled = false;
    }

    private void next_score_clicked()
    {
        if (busy || score_index >= scores.length -1)
            return;

        score_index++;
        update_score_view(false);
    }

    private void prev_score_clicked()
    {
        if (busy || score_index == 0)
            return;

        score_index--;
        update_score_view(false);
    }

    public bool busy { get; private set; }
}
