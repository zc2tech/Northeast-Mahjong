using Engine;
using Gee;

public class RenderWall : WorldObject
{
    private GameRenderContext context;
    private RenderTile[] tiles;
    private WallPart[] walls;

    private ArrayList<WallPart> draw_parts;
    private ArrayList<WallPart> dead_parts;
    private int split;
    private int TILE_COUNT_PER_WALL = 28;

    public RenderWall(GameRenderContext context, RenderTile[] tiles)
    {
        this.context = context;
        this.tiles = tiles;
        this.split = context.wall_split;
    }

    protected override void added()
    {
        walls = new WallPart[4];
        
        for (int i = 0; i < 4; i++)
        {
            RenderTile[] wt = new RenderTile[TILE_COUNT_PER_WALL];
            for (int j = 0; j < TILE_COUNT_PER_WALL; j++)
                wt[j] = tiles[i * TILE_COUNT_PER_WALL + j];

            WorldObject wrap = new WorldObject();
            WorldObject rot = new WorldObject();
            walls[i] = new WallPart(wt, context.tile_size);
            add_object(rot);
            rot.add_object(wrap);
            wrap.add_object(walls[i]);

            rot.rotation = Quat.from_euler(-i / 2.0f, 0, 0);
            wrap.position = Vec3(context.tile_size.x * 7, context.tile_size.y / 2, 8 * context.tile_size.x);
        }
    }

    public void split_dead_wall(AnimationTime time)
    {
        float delta = context.tile_size.x / 2 * 3;

        int start_wall = (4 - context.dealer) % 4;
        ArrayList<WallPart> draw = new ArrayList<WallPart>();
        ArrayList<WallPart> dead = new ArrayList<WallPart>();

        for (int i = 0; i < 4; i++)
            draw.add(walls[(start_wall + i) % 4]);

        WallPart left = draw.remove_at(0);
        WallPart p = left.dead_split(split);
        draw.insert(0, p);
        p.animate_move(-delta, time);

        // For 28 tiles per wall, dead wall is 4 pairs (8 tiles)
        // Split at position 4 (counted from the right side of the wall)
        if (split > 4)
        {
            var part = left.dead_split(split - 4);
            part.to_dead_wall(2); // 2 dora indicators
            dead.add(part);
            draw.add(left);

            left.animate_move(delta, time);
        }
        else
        {
            dead.add(left);
            left.to_dead_wall(2); // 2 dora indicators

            if (split != 4)
            {
                // For 28-tile walls: 14 pairs - 4 dead wall pairs = 10 draw pairs
                // Split from the end of the opposite wall
                var part = draw[3].dead_split(10 + split);
                dead.add(part);
                part.to_dead_wall(0);
                part.animate_move(-delta, time);
            }
        }

        draw_parts = draw;
        dead_parts = dead;

        // For Northeast Mahjong: flip the 8th tile (index 7) in dead wall face-up
        // Dead wall has 8 tiles (4 pairs), we want tile at index 7 (8th/last tile, 0-indexed)
        // Find the tile in the dead_parts and flip it
        int tile_count = 0;
        foreach (WallPart part in dead_parts)
        {
            if (tile_count + part.tile_count() > 7)
            {
                // The 8th tile is in this part
                int index_in_part = 7 - tile_count;
                part.flip_specific_tile(index_in_part, time);
                break;
            }
            tile_count += part.tile_count();
        }
    }

    public RenderTile? draw_wall()
    {
        if (draw_parts[0].empty)
            draw_parts.remove_at(0);
        if (draw_parts.size == 0)
            return null;
        return draw_parts[0].draw();
    }

    public RenderTile? draw_dead_wall()
    {
        if (dead_parts[0].empty)
            dead_parts.remove_at(0);
        if (dead_parts.size == 0)
            return null;
        return dead_parts[0].dead_draw();
    }

    public void flip_dora()
    {
        if (!dead_parts[0].flip_dora(context.server_times.dora_flip))
            dead_parts[1].flip_dora(context.server_times.dora_flip);
    }

    public void flip_ura_dora()
    {
        foreach (WallPart part in dead_parts)
            part.flip_ura_dora(context.server_times.dora_flip);
    }

    public void dead_tile_add()
    {
        int i = draw_parts.size - 1;
        WallPart last = draw_parts[i];
        if (last.empty)
            draw_parts.remove_at(i--);

        dead_parts[dead_parts.size - 1].dead_tile_add(draw_parts[i].remove_last(context.server_times.dora_flip), context.server_times.dora_flip);
    }

    public class WallPart : WorldObject
    {
        private ArrayList<RenderTile> tiles = new ArrayList<RenderTile>();
        private Vec3 tile_size;
        private int removed_tiles;

        private int dora_index;
        private int tiles_added;
        private int dead_drawn;
        private ArrayList<RenderTile> doras = new ArrayList<RenderTile>();
        private ArrayList<RenderTile> ura_doras = new ArrayList<RenderTile>();

        public WallPart(RenderTile[] tiles, Vec3 tile_size)
        {
            for (int i = 0; i < tiles.length; i++)
                this.tiles.add(tiles[i]);

            this.tile_size = tile_size;
        }

        public override void added()
        {
            foreach (RenderTile tile in tiles)
                add_object(tile);

            order();
        }

        public void animate_move(float delta, AnimationTime time)
        {
            WorldObjectAnimation animation = new WorldObjectAnimation(time);
            Path3D path = new LinearPath3D(Vec3(delta, 0, 0));
            animation.do_relative_position(path);
            animation.curve = new SmoothApproachCurve();
            animate(animation, true);
        }

        public void to_dead_wall(int dora_index)
        {
            this.dora_index = dora_index + 1;

            ArrayList<RenderTile> tiles = new ArrayList<RenderTile>();
            while (this.tiles.size > 0)
                tiles.add(this.tiles.remove_at(this.tiles.size - 1));
            this.tiles = tiles;
        }

        public WallPart dead_split(int index)
        {
            ArrayList<RenderTile> split = new ArrayList<RenderTile>();

            index *= 2;

            while (index < tiles.size)
                split.add(tiles.remove_at(index));

            Vec3 pos = Vec3(split[0].position.x, 0, 0);

            WallPart wall = new WallPart(split.to_array(), tile_size);
            get_parent().add_object(wall);
            wall.position = position.plus(pos);

            return wall;
        }

        public RenderTile remove_last(AnimationTime time)
        {
            assert(tiles.size > 0);
            RenderTile tile = tiles.remove_at(tiles.size - 1);

            if (removed_tiles % 2 == 0 && tiles.size > 0)
            {
                RenderTile t = tiles[tiles.size - 1];
                t.animate_towards(tile.position, tile.rotation, time);
            }

            removed_tiles++;
            return tile;
        }

        public RenderTile? draw()
        {
            assert(!empty);

            if (empty)
                return null;

            return tiles.remove_at(0);
        }

        public RenderTile? dead_draw()
        {
            assert(!empty);

            int i = ++dead_drawn % 2;

            if (i >= tiles.size)
                return null;

            dora_index--;
            return tiles.remove_at(i);
        }

        private void order()
        {
            for (int i = 0; i < tiles.size; i++)
            {
                RenderTile tile = tiles[i];

                Vec3 pos = Vec3
                (
                    (i / 2) * -tile_size.x,
                    ((i + 1) % 2) * tile_size.y,
                    0
                );
                Quat rot = Quat.from_euler(0, 1, 0);

                tile.rotation = rot;
                tile.position = pos;
            }
        }

        public void dead_tile_add(RenderTile tile, AnimationTime time)
        {
            Vec3 pos = Vec3(((tiles_added + 1) % 2) * tile_size.x, ((tiles_added % 2) * 2 - 1) * tile_size.y, 0);
            pos = tiles[tiles.size - 1].position.plus(pos);
            Quat rot = Quat.from_euler(0, 1, 0);

            convert_object(tile);
            tile.animate_towards(pos, rot, time);

            tiles.add(tile);
            tiles_added++;
        }

        public bool flip_dora(AnimationTime time)
        {
            if (dora_index >= tiles.size)
                return false;

            RenderTile t = tiles[dora_index];
            doras.add(t);
            ura_doras.add(tiles[dora_index - 1]);

            // Flip the tile face-up
            Quat rot = Quat.from_euler(0, 1, 0).mul(t.rotation);
            t.animate_towards(t.position, rot, time);

            dora_index += 2;

            return true;
        }

        public void flip_ura_dora(AnimationTime time)
        {
            // Don't reveal ura dora in Northeast Mahjong, just hide them
            foreach (var tile in doras)
            {
                tile.visible = false;
            }

            foreach (var tile in ura_doras)
            {
                tile.visible = false;
            }
        }

        public int tile_count()
        {
            return tiles.size;
        }

        public void flip_specific_tile(int index, AnimationTime time)
        {
            if (index >= 0 && index < tiles.size)
            {
                RenderTile t = tiles[index];
                Quat rot = Quat.from_euler(0, 1, 0).mul(t.rotation);
                t.animate_towards(t.position, rot, time);
            }
        }

        public bool empty { get { return tiles.size == 0; } }
    }
}
