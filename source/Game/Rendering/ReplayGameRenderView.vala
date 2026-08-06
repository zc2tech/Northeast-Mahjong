using Engine;
using Gee;

public class ReplayGameRenderView : GameRenderView
{
    public ReplayGameRenderView(int observer_index, int dealer_index, GameStartInfo game_start, RoundStartInfo info, Options options, RoundScoreState score)
    {
        // Pass the actual observer_index to the base class
        base(observer_index, dealer_index, game_start, info, options, score);
    }

    public void set_animation_speed(float multiplier)
    {
        context.set_animation_speed(multiplier);
    }

    //  private void tile_discard(int player_index, int tile_ID)
    //  {
    //      RenderPlayer player = players[player_index];
    //      RenderTile tile = tiles[tile_ID];
    //      buffer_action(new RenderActionDiscard(context.server_times.tile_discard, player, tile));
    //  }

    // Replay-specific observer navigation
    public void observe_next()
    {
        observer_index = (observer_index + 1) % 4;
        observe_animate();
    }

    public void observe_prev()
    {
        observer_index = (observer_index + 3) % 4;
        observe_animate();
    }

    private void observe_animate()
    {
        var observer = scene.players[observer_index];
        observer.convert_object(observe_object);

        WorldObjectAnimation animation = new WorldObjectAnimation(new AnimationTime.preset(2));
        PathQuat rot = new LinearPathQuat(Quat());
        animation.do_absolute_rotation(rot);

        animation.curve = new SCurve(0.5f);

        observe_object.cancel_buffered_animations();
        observe_object.animate(animation, true);

        // In replay mode, all hands stay revealed but angles adjust based on relative position
        // Update each player's view angle based on their position relative to new observer
        foreach (var player in scene.players)
            player.update_view_angle_for_observer(observer_index);
    }
}
