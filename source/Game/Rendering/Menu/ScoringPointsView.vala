using Engine;
using Gee;

class ScoringPointsView : View2D
{
    private GameRenderContext context;
    private RoundScoreState score;
    private LabelControl score_label;
    private LabelControl? draw_label;
    private Engine.MenuButton? next_button;
    private Engine.MenuButton? prev_button;
    private ScoringScoreControl? scoring_control;
    //  private ScoringDoraView? dora;
    //  private ScoringDoraView? ura;
    private Sound fade_sound;
    private int score_index;

    private bool animate;
    private int padding = 20;
    private int switches;
    private float total_time;

    public signal void label_animation_finished();
    public signal void score_animation_finished();
    public signal void score_selected(int player_index);

    public ScoringPointsView(GameRenderContext context, RoundScoreState score, bool animate)
    {
        this.context = context;
        this.score = score;
        this.animate = animate;

        if (animate)
            total_time = context.server_times.get_animation_round_end_delay(score);
    }

    protected override void removed()
    {
        // Stop any playing sounds when view is removed
        if (fade_sound != null)
            fade_sound.stop();
        base.removed();
    }

    public override void added()
    {
        resize_style = ResizeStyle.ABSOLUTE;

        if (!score.round_is_finished)
            return;

        bool draw = false;
        string score_text;

        int sekinin_index = -1;
        if (score.result.scores.length > 0)
            score.result.scores[0].player.sekinin_index;

        bool sekinin = !draw && sekinin_index != -1;

        if (score.result.result == RoundFinishResult.RoundResultEnum.RON)
        {
            score_text = "Ron";

            if (score.result.scores.length != 1)
                score_text = "Multiple " + score_text;
            else if (score.result.scores[0].dealer)
                score_text = "Dealer " + score_text;

            sekinin = false;
            foreach (Scoring s in score.result.scores)
                if (s.player.sekinin_index != -1 && s.player.sekinin_index != score.result.loser_index)
                    sekinin = true;
        }
        else if (score.result.result == RoundFinishResult.RoundResultEnum.TSUMO)
        {
            score_text = "Tsumo";
            if (score.result.scores[0].dealer)
                score_text = "Dealer " + score_text;
        }
        else
        {
            score_text = "Draw";
            draw = true;
        }

        if (sekinin)
            score_text += " (Sekinin Barai)";

        score_label = new LabelControl();
        add_child(score_label);
        score_label.text = score_text;
        score_label.alpha = animate ? 0 : 1;
        score_label.font_size = 40;

        fade_sound = store.audio_player.load_sound("fade_in");

        if (animate)
            animation_label_start();

        if (draw)
        {
            score_label.inner_anchor = Vec2(0.5f, 0.5f);
            score_label.outer_anchor = Vec2(0.5f, 0.5f);

            if (score.result.draw_type != GameDrawType.EMPTY_WALL || score.result.nagashi_indices.length != 0)
            {
                score_label.inner_anchor = Vec2(0.5f, 0);

                draw_label = new LabelControl();
                add_child(draw_label);
                draw_label.inner_anchor = Vec2(0.5f, 1);
                draw_label.outer_anchor = Vec2(0.5f, 0.5f);
                draw_label.font_size = score_label.font_size;

                string text;

                if (score.result.draw_type == GameDrawType.EMPTY_WALL && score.result.nagashi_indices.length != 0)
                    text = "Nagashi Mangan";
                else if (score.result.draw_type == GameDrawType.FOUR_WINDS)
                    text = "Four Winds";
                else if (score.result.draw_type == GameDrawType.FOUR_KANS)
                    text = "Four Kans";
                else if (score.result.draw_type == GameDrawType.VOID_HAND)
                    text = "Void Hand";
                else if (score.result.draw_type == GameDrawType.TRIPLE_RON)
                    text = "Triple Ron";
                else
                    text = "";

                draw_label.text = text;
                draw_label.alpha = animate ? 0 : 1;
            }

            return;
        }

        show_score_control();

        if (score.result.scores.length > 1)
        {
            switches = score.result.scores.length - 1;

            prev_button = new Engine.MenuButton("Prev");
            next_button = new Engine.MenuButton("Next");
            add_child(prev_button);
            add_child(next_button);

            float scale = score_label.size.height / prev_button.size.height;

            prev_button.size = Size2(prev_button.size.width * scale, prev_button.size.height * scale);
            next_button.size = Size2(next_button.size.width * scale, next_button.size.height * scale);
            prev_button.inner_anchor = Vec2(1, 0.5f);
            next_button.inner_anchor = Vec2(0, 0.5f);
            prev_button.outer_anchor = Vec2(0.5f, 1);
            next_button.outer_anchor = Vec2(0.5f, 1);
            prev_button.position = Vec2(-score_label.size.width / 2 - prev_button.size.height / 2, -score_label.size.height / 2);
            next_button.position = Vec2( score_label.size.width / 2 + next_button.size.height / 2, -score_label.size.height / 2);
            prev_button.clicked.connect(prev_score);
            next_button.clicked.connect(next_score);
            prev_button.visible = !animate;
            next_button.visible = !animate;
        }
    }

    private void animation_label_start()
    {
        var animation = new Animation(context.server_times.finish_label_fade);
        animation.animate_start.connect(animation_label_animate_start);
        animation.animate.connect(animation_label_animate);
        animation.finished.connect(animation_label_finish);
        add_animation(animation);
    }

    private void animation_label_animate_start()
    {
        fade_sound.play();
    }

    private void animation_label_animate(float time)
    {
        score_label.alpha = time;
        if (draw_label != null)
            draw_label.alpha = time;
    }

    private void animation_label_finish()
    {
        label_animation_finished();
        animation_items_fade_start();

        if (scoring_control != null)
        {
            scoring_control.animate();
        }
    }

    private void animation_items_fade_start()
    {
        var animation = new Animation(context.server_times.menu_items_fade);
        animation.animate_start.connect(animation_items_fade_animate_start);
        animation.animate.connect(animation_items_fade_animate);
        animation.finished.connect(animation_items_fade_finish);
        add_animation(animation);
    }

    private void animation_items_fade_animate_start()
    {
        if (scoring_control == null)
            fade_sound.play();
    }

    private void animation_items_fade_animate(float time)
    {
        //  if (dora != null)
        //      dora.alpha = time;
        //  if (ura != null)
        //      ura.alpha = time;
    }

    private void animation_items_fade_finish()
    {
        if (scoring_control == null)
            score_animation_finished();
    }

    private void scoring_control_animation_finished()
    {
        //  if (switches > 0)
        //  {
        //      score_index = (score_index + 1) % score.result.scores.length;
        //      show_score_control();
        //      switches--;

        //      scoring_control.animate();
        //  }
        //  else
        //      score_animation_finished();
        score_animation_finished();
    }

    public void animation_finished()
    {
        if (prev_button != null)
            prev_button.visible = true;
        if (next_button != null)
            next_button.visible = true;
        animate = false;
    }

    protected override void key_press(KeyArgs key)
    {
        if (key.handled)
            return;

        if (key.down && !key.repeat)
        {
            // Keyboard shortcuts for prev/next buttons
            // Use < and > keys (comma and period), or arrow keys
            if ((key.scancode == ScanCode.COMMA || key.scancode == ScanCode.LEFT) && prev_button != null && prev_button.visible)
            {
                prev_score();
                key.handled = true;
            }
            else if ((key.scancode == ScanCode.PERIOD || key.scancode == ScanCode.RIGHT) && next_button != null && next_button.visible)
            {
                next_score();
                key.handled = true;
            }
        }
    }

    private void show_score_control()
    {
        if (scoring_control != null)
            remove_child(scoring_control);

        Scoring scoring = score.result.scores[score_index];
        int sekinin_index = scoring.player.sekinin_index;
        bool sekinin = sekinin_index != -1;
        bool dual_payer = false;

        if (score.result.result == RoundFinishResult.RoundResultEnum.RON)
            dual_payer = sekinin = sekinin && sekinin_index != score.result.loser_index;

        scoring_control = new ScoringScoreControl(context, scoring, sekinin, dual_payer, animate);
        add_child(scoring_control);
        scoring_control.resize_style = ResizeStyle.ABSOLUTE;
        scoring_control.inner_anchor = Vec2(0.5f, 0);
        scoring_control.outer_anchor = Vec2(0.5f, 0);
        //  scoring_control.position = Vec2(0, dora.size.height);
        scoring_control.position = Vec2(0, 2f);
        scoring_control.animation_finished.connect(scoring_control_animation_finished);

        score_selected(score.result.winner_indices[score_index]);
        resized();
    }

    private void prev_score()
    {
        score_index = (score_index + 1) % score.result.scores.length;
        show_score_control();
        switches = 0;
    }

    private void next_score()
    {
        score_index = (score_index - 1 + score.result.scores.length) % score.result.scores.length;
        show_score_control();
        switches = 0;
    }

    protected override void resized()
    {
        //  if (dora != null)
        //      dora.size = Size2(ura.visible ? (size.width - padding) / 2 : size.width, dora.size.height);
        //  if (ura != null)
        //      ura.size  = Size2((size.width - padding) / 2,  ura.size.height);

        if (scoring_control != null)
            //  scoring_control.size = Size2(size.width, size.height - score_label.size.height - dora.size.height);
            scoring_control.size = Size2(size.width, size.height - score_label.size.height - 2);
    }

    public void stop_sounds()
    {
        // Stop fade sound in main view
        if (fade_sound != null)
            fade_sound.stop();

        // Stop sounds in scoring control
        if (scoring_control != null)
            scoring_control.stop_sounds();
    }

    private class ScoringScoreControl : Control
    {
        private ScoringHandView? hand;
        private GameRenderContext context;
        private Scoring scoring;
        private bool sekinin;
        private bool dual_payer;
        private bool _animate;

        private int animation_han_index;
        private LabelControl points_label;
        private ArrayList<YakuLine> lines = new ArrayList<YakuLine>();
        private Sound score_sound;
        private Sound fade_sound;

        public signal void animation_finished();

        public ScoringScoreControl(GameRenderContext context, Scoring scoring, bool sekinin, bool dual_payer, bool animate)
        {
            this.context = context;
            this.scoring = scoring;
            this.sekinin = sekinin;
            this.dual_payer = dual_payer;
            _animate = animate;
        }

        protected override void removed()
        {
            // Stop any playing sounds when view is removed
            if (score_sound != null)
                score_sound.stop();
            if (fade_sound != null)
                fade_sound.stop();
            base.removed();
        }

        public override void added()
        {
            hand = new ScoringHandView(context, scoring);
            add_child(hand);
            hand.outer_anchor = Vec2(0.5f, 1);
            hand.size = Size2(size.width, 120);
            hand.position = Vec2(0, -hand.size.height / 2);
            hand.alpha = _animate ? 0 : 1;

            int han = 0;
            int yakuman = 0;

            foreach (Yaku yaku in scoring.yaku)
            {
                han += yaku.han;
                yakuman += yaku.yakuman;
            }

            int h = 0;
            float start = hand.size.height / 2 - hand.position.y;

            foreach (Yaku yaku in scoring.yaku)
            {
                if (yakuman > 0 && yaku.yakuman == 0)
                    continue;

                LabelControl name = new LabelControl();
                add_child(name);
                name.text = yaku_to_string(yaku);
                name.inner_anchor = Vec2(0, 1);
                name.outer_anchor = Vec2(0, 1);
                name.position = Vec2(0, -start - h * name.size.height);
                name.alpha = _animate ? 0 : 1;

                string str;

                if (yaku.yakuman > 0)
                {
                    str = "Yakuman";

                    if (yaku.yakuman == 2)
                        str = "Double " + str;
                    else if (yaku.yakuman > 2)
                        str = yaku.yakuman.to_string() + " " + str;
                }
                else
                    str = yaku.han.to_string() + " han";

                LabelControl num = new LabelControl();
                add_child(num);
                num.text = str;
                num.inner_anchor = Vec2(1, 1);
                num.outer_anchor = Vec2(1, 1);
                num.position = Vec2(0, -start - h * num.size.height);
                num.alpha = _animate ? 0 : 1;
                h++;

                lines.add(new YakuLine(name, num));
            }

            points_label = new LabelControl();
            add_child(points_label);
            points_label.font_size = 40;
            points_label.inner_anchor = Vec2(0.5f, 0);
            points_label.outer_anchor = Vec2(0.5f, 0);
            points_label.alpha = _animate ? 0 : 1;
            set_points_text(_animate ? 0 : 1);

            score_sound = store.audio_player.load_sound("score_count");
            fade_sound = store.audio_player.load_sound("fade_in");
        }

        private void animate_items_start()
        {
            var animation = new Animation(context.server_times.menu_items_fade);
            animation.animate_start.connect(animate_items_animate_start);
            animation.animate.connect(animate_items_animate);
            animation.finished.connect(animate_items_finished);
            add_animation(animation);
        }

        private void animate_items_animate_start()
        {
            fade_sound.play();
        }

        private void animate_items_animate(float time)
        {
            hand.alpha = time;
        }

        private void animate_items_finished()
        {
            animation_score_fade_start();
        }

        private void animation_han_animate_start()
        {
            fade_sound.play();
        }

        private void animation_score_fade_start()
        {
            var animation = new Animation(context.server_times.score_counting_fade);
            animation.animate_start.connect(animation_score_fade_animate_start);
            animation.animate.connect(animation_score_fade_animate);
            animation.finished.connect(animation_score_fade_finish);
            add_animation(animation);
        }

        private void animation_score_fade_animate_start()
        {
            fade_sound.play();
        }

        private void animation_score_fade_animate(float time)
        {
            points_label.alpha = time;
        }

        private void animation_score_fade_finish()
        {
            animation_score_count_start();
        }

        private void animation_score_count_start()
        {
            var animation = new Animation(context.server_times.score_counting);
            animation.animate_start.connect(animation_score_count_animate_start);
            animation.animate_finish.connect(animation_score_count_animate_finish);
            animation.animate.connect(animation_score_count_animate);
            animation.finished.connect(animation_score_count_finish);
            animation.curve = new ExponentCurve(0.5f);
            add_animation(animation);
        }

        private void animation_score_count_animate_start()
        {
            //  score_sound.play(true);
        }

        private void animation_score_count_animate_finish()
        {
            //  score_sound.stop();
        }

        private void animation_score_count_animate(float time)
        {
            set_points_text(time);
        }

        private void animation_score_count_finish()
        {
            animation_finished();
        }

        protected override void resized()
        {
            if (hand != null)
                hand.size = Size2(size.width, hand.size.height);
        }

        public void animate()
        {
            animate_items_start();
        }

        public void stop_sounds()
        {
            // Stop score counting and fade sounds
            if (score_sound != null)
                score_sound.stop();
            if (fade_sound != null)
                fade_sound.stop();
        }

        // TODO: need to adjust for Northeast
        private void set_points_text(float amount)
        {
            string points;

            if (scoring.ron)
            {
                if (dual_payer)
                    points = "2 * " + ((int)(scoring.ron_points / 2 * amount)).to_string();
                else
                    points = ((int)(scoring.ron_points * amount)).to_string();
            }
            else
            {
                if (sekinin)
                    points = ((int)(scoring.total_points * amount)).to_string();
                else if (scoring.dealer)
                    points = "3 * " + ((int)(scoring.tsumo_points * amount)).to_string();
                else
                    points = ((int)(scoring.tsumo_points * amount)).to_string() + "/" + ((int)(scoring.tsumo_points * amount)).to_string();
            }

            string name = "";

            switch (scoring.score_type)
            {
            case Scoring.ScoreType.MANGAN:
                name = "Mangan";
                break;
            case Scoring.ScoreType.HANEMAN:
                name = "Haneman";
                break;
            case Scoring.ScoreType.BAIMAN:
                name = "Baiman";
                break;
            case Scoring.ScoreType.SANBAIMAN:
                name = "Sanbaiman";
                break;
            case Scoring.ScoreType.KAZOE_YAKUMAN:
                name = "Kazoe Yakuman";
                break;
            case Scoring.ScoreType.YAKUMAN:
                name = "Yakuman";
                break;
            case Scoring.ScoreType.NAGASHI_MANGAN:
                name = "Nagashi Mangan";
                break;
            case Scoring.ScoreType.NORMAL:
            default:
                name = "";
                break;
            }

            if (name != "")
            {
                if (scoring.dealer)
                    name = "Dealer " + name;
                name += " - ";
            }

            points_label.text = name + points + " points";
        }

        private string yaku_to_string(Yaku yaku)
        {
            string str = "";

            string[] parts = yaku.yaku_type.to_string().substring(10).down().split("_");

            for (int i = 0; i < parts.length; i++)
            {
                string part = parts[i];

                if (i != 0)
                    str += " ";
                str += part[0].toupper().to_string() + part.substring(1);
            }

            return str;
        }

        private class YakuLine
        {
            public YakuLine(LabelControl name, LabelControl han)
            {
                this.name = name;
                this.han = han;
            }

            public LabelControl name { get; private set; }
            public LabelControl han { get; private set; }
        }
    }
}
