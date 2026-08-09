using Engine;

public class AnimationTimings : Serializable
{
	// Create default animation timings for normal gameplay
	public static AnimationTimings create_default(int decision_time)
	{
		float winning_draw_animation_time = 0.5f;
		float hand_reveal_animation_time = 0.5f;
		float round_over_delay = 0.2f;
		float round_end_delay = 1f;  // Add 1 second for countdown
		float hanchan_end_delay = 30 + 1;
		float game_end_delay = 60 + 1;
		float decision_time_with_buffer = decision_time + 1;

		var finish_label_fade = new AnimationTime(0.2f, 0.1f, 0);
		var menu_items_fade = new AnimationTime(1, 0.5f, 1);
		var han_fade = new AnimationTime(0.5f, 0.5f, 0);
		var score_counting_fade = new AnimationTime(1, 0.5f, 0);
		var score_counting = new AnimationTime(0.1f, 0.3f, 0.2f);
		var players_points_counting = new AnimationTime(0, 0.3f, 0.2f);
		var players_score_fade = new AnimationTime(0, 0.5f, 0);
		var players_score_counting = new AnimationTime(0.1f, 0.3f, 0.2f);

		var initial_draw = new AnimationTime(0, 0.15f, 0);
		var tile_draw = new AnimationTime(0, 0.15f, 0.2f);
		var tile_discard = new AnimationTime(0, 0.15f, 0.3f);
		var call = new AnimationTime(0, 0.5f, 0);
		var hand_reveal = new AnimationTime(0, 0.15f, 0.8f);
		var split_wall = new AnimationTime(0, 0.5f, 0);
		var dead_wall_mark_flip = new AnimationTime(0, 0.2f, 0);
		var win = new AnimationTime(0, 0.5f, 0.5f);
		var hand_order = new AnimationTime(0, 0.15f, 0);
		var hand_angle = new AnimationTime(0, 0.2f, 0);

		return new AnimationTimings(
			winning_draw_animation_time,
			hand_reveal_animation_time,
			round_over_delay,
			round_end_delay,
			hanchan_end_delay,
			game_end_delay,
			decision_time_with_buffer,
			finish_label_fade,
			menu_items_fade,
			han_fade,
			score_counting_fade,
			score_counting,
			players_points_counting,
			players_score_fade,
			players_score_counting,
			initial_draw,
			tile_draw,
			tile_discard,
			call,
			hand_reveal,
			split_wall,
			dead_wall_mark_flip,
			win,
			hand_order,
			hand_angle
		);
	}

	public AnimationTimings
	(
        float winning_draw_animation_time,
        float hand_reveal_animation_time,
        float round_over_delay,
        float round_end_delay,
        float hanchan_end_delay,
        float game_end_delay,
        float decision_time,
        AnimationTime finish_label_fade,
        AnimationTime menu_items_fade,
        AnimationTime han_fade,
        AnimationTime score_counting_fade,
        AnimationTime score_counting,
        AnimationTime players_points_counting,
        AnimationTime players_score_fade,
        AnimationTime players_score_counting,
        AnimationTime initial_draw,
        AnimationTime tile_draw,
        AnimationTime tile_discard,
        AnimationTime call,
        AnimationTime hand_reveal,
        AnimationTime split_wall,
        AnimationTime dead_wall_mark_flip,
        AnimationTime win,
        AnimationTime hand_order,
        AnimationTime hand_angle
	)
	{
        this.winning_draw_animation_time = winning_draw_animation_time;
        this.hand_reveal_animation_time = hand_reveal_animation_time;
        this.round_over_delay = round_over_delay;
		this.round_end_delay = round_end_delay;
		this.hanchan_end_delay = hanchan_end_delay;
		this.game_end_delay = game_end_delay;
		this.decision_time = decision_time;
        this.finish_label_fade = finish_label_fade;
        this.menu_items_fade = menu_items_fade;
        this.han_fade = han_fade;
        this.score_counting_fade = score_counting_fade;
        this.score_counting = score_counting;
        this.players_points_counting = players_points_counting;
        this.players_score_fade = players_score_fade;
        this.players_score_counting = players_score_counting;

        this.initial_draw = initial_draw;
        this.tile_draw = tile_draw;
        this.tile_discard = tile_discard;
        this.call = call;
        this.hand_reveal = hand_reveal;
        this.split_wall = split_wall;
        this.dead_wall_mark_flip = dead_wall_mark_flip;
        this.win = win;

        this.hand_order = hand_order;
        this.hand_angle = hand_angle;
	}

	public float get_animation_round_end_delay(RoundScoreState round)
	{
	    float time = 0;

	    time += round_over_delay;
        time += finish_label_fade.total() + menu_items_fade.total();

	    //  if (round.result.result != RoundFinishResult.RoundResultEnum.DRAW &&
        //      round.result.result != RoundFinishResult.RoundResultEnum.NONE)
        //  {
        //      foreach (Scoring score in round.result.scores)
        //      {
        //          time += score_counting_fade.total() + score_counting.total();

        //          foreach (Yaku y in score.yaku)
        //              if (score.yakuman == 0 || y.yakuman > 0)
        //                  time += han_fade.total();
        //      }
        //  }

        //  if (round.game_is_finished)
        //      time += game_end_delay + players_score_fade.total() + players_score_counting.total();
        //  else if (round.hanchan_is_finished)
        //      time += hanchan_end_delay + players_score_fade.total() + players_score_counting.total();
        //  else
        //      time += round_end_delay;

        //  foreach (var player in round.players)
        //      if (player.transfer != 0)
        //      {
        //          time += players_points_counting.total();
        //          break;
        //      }

        return time;
	}

	// Create a scaled copy of all animation times
	public AnimationTimings scale(float multiplier)
	{
		return new AnimationTimings(
			winning_draw_animation_time * multiplier,
			hand_reveal_animation_time * multiplier,
			round_over_delay * multiplier,
			round_end_delay * multiplier,
			hanchan_end_delay * multiplier,
			game_end_delay * multiplier,
			decision_time * multiplier,
			finish_label_fade.scale(multiplier),
			menu_items_fade.scale(multiplier),
			han_fade.scale(multiplier),
			score_counting_fade.scale(multiplier),
			score_counting.scale(multiplier),
			players_points_counting.scale(multiplier),
			players_score_fade.scale(multiplier),
			players_score_counting.scale(multiplier),
			initial_draw.scale(multiplier),
			tile_draw.scale(multiplier),
			tile_discard.scale(multiplier),
			call.scale(multiplier),
			hand_reveal.scale(multiplier),
			split_wall.scale(multiplier),
			dead_wall_mark_flip.scale(multiplier),
			win.scale(multiplier),
			hand_order.scale(multiplier),
			hand_angle.scale(multiplier)
		);
	}

	public float winning_draw_animation_time { get; protected set; }
	public float hand_reveal_animation_time { get; protected set; }

	public float round_over_delay { get; protected set; }

	public float round_end_delay { get; protected set; }
	public float hanchan_end_delay { get; protected set; }
	public float game_end_delay { get; protected set; }
	public float decision_time { get; protected set; }

	public AnimationTime finish_label_fade { get; protected set; }
	public AnimationTime menu_items_fade { get; protected set; }
	public AnimationTime han_fade { get; protected set; }

	public AnimationTime score_counting_fade { get; protected set; }
	public AnimationTime score_counting { get; protected set; }

	public AnimationTime players_points_counting { get; protected set; }
	public AnimationTime players_score_fade { get; protected set; }
	public AnimationTime players_score_counting { get; protected set; }

    //////////////////

    public AnimationTime initial_draw { get; protected set; }
    public AnimationTime tile_draw { get; protected set; }
    public AnimationTime tile_discard { get; protected set; }
    public AnimationTime call { get; protected set; }
    public AnimationTime hand_reveal { get; protected set; }
    public AnimationTime split_wall { get; protected set; }
    public AnimationTime dead_wall_mark_flip { get; protected set; }
    public AnimationTime win { get; protected set; }

    public AnimationTime hand_order { get; protected set; }
    public AnimationTime hand_angle { get; protected set; }
}
