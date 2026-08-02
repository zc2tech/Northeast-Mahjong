using Engine;
using Gee;

public class ReplayGameRenderView : GameRenderView
{
    public ReplayGameRenderView(int observer_index, int dealer_index, GameStartInfo game_start, RoundStartInfo info, Options options, RoundScoreState score)
    {
        // Always initialize as observer (-1) for replay, but store the preferred observer index
        base(-1, dealer_index, game_start, info, options, score);

        // Override observer_index with the actual one for replay
        this.observer_index = (observer_index >= 0 && observer_index < 4) ? observer_index : 0;

        Environment.log(LogType.DEBUG, "ReplayGameRenderView", @"Created replay view, observer=$(this.observer_index)");
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
        Environment.log(LogType.DEBUG, "ReplayGameRenderView", @"Switched to player $(observer_index)");
    }

    public void observe_prev()
    {
        observer_index = (observer_index + 3) % 4;
        observe_animate();
        Environment.log(LogType.DEBUG, "ReplayGameRenderView", @"Switched to player $(observer_index)");
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

        foreach (var player in scene.players)
            player.set_observed(player == observer);
    }
}
