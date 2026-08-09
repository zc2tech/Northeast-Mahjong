using Engine;

public class GameRenderContext
{
    private float decision_time_multiplier = 1.0f;
    private float animation_speed_multiplier = 1.0f;
    private AnimationTimings original_server_times;
    private AnimationTimings scaled_server_times;

    public GameRenderContext(AnimationTimings server_times, float tile_scale, Vec3 tile_size, int observer_index, int dealer, int wall_split, bool reveal_all_tiles)
    {
        this.original_server_times = server_times;
        this.scaled_server_times = server_times;
        this.tile_scale = tile_scale;
        this.tile_size = tile_size;
        this.observer_index = observer_index;
        this.dealer = dealer;
        this.wall_split = wall_split;
        this.reveal_all_tiles = reveal_all_tiles;
    }

    public void set_decision_time_multiplier(float multiplier)
    {
        this.decision_time_multiplier = multiplier;
    }

    public void set_animation_speed(float multiplier)
    {
        this.animation_speed_multiplier = multiplier >= 1.5f ? multiplier : 1.0f;

        if (animation_speed_multiplier > 1.0f)
        {
            // Scale all animation times
            scaled_server_times = original_server_times.scale(1.0f / animation_speed_multiplier);
        }
        else
        {
            scaled_server_times = original_server_times;
        }
    }

    public float get_decision_time()
    {
        // Return scaled decision time
        // If multiplier is 0 (paused), return a very large value to effectively pause
        if (decision_time_multiplier <= 0.0f)
            return 999999.0f;
        return original_server_times.decision_time / decision_time_multiplier;
    }

    public float tile_scale { get; private set; }
    public Vec3 tile_size { get; private set; }
    public int observer_index { get; private set; }
    public int dealer { get; private set; }
    public int wall_split { get; private set; }
    public bool reveal_all_tiles { get; private set; }

    public AnimationTimings server_times { get { return scaled_server_times; } }
    /*public AnimationTime hand_angle { get; private set; }
    public AnimationTime hand_order { get; private set; }*/
}