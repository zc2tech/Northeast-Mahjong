using Engine;
using Gee;

public class RenderWall : WorldObject
{
    private GameRenderContext context;
    private RenderTile[] tiles;
    private WallPart[] walls;

    private ArrayList<WallPart> draw_parts;
    private ArrayList<WallPart> dead_parts;
    private int split_stack;
    private int TILE_COUNT_PER_WALL = 28;

    public RenderWall(GameRenderContext context, RenderTile[] tiles)
    {
        this.context = context;
        this.tiles = tiles;
        this.split_stack = context.wall_split;
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
        // No visual gap needed since dead wall mark is revealed
        float delta = 0;
        // 从庄家(东风位)位置推算  0 -> 0 , 1 -> 3 , 2 -> 2 , 3 -> 1
        int start_wall = (4 - context.dealer) % 4;
        ArrayList<WallPart> draw = new ArrayList<WallPart>(); // 正常 抽牌 墩
        ArrayList<WallPart> dead = new ArrayList<WallPart>(); // 杠牌墩

        for (int i = 0; i < 4; i++)
            draw.add(walls[(start_wall + i) % 4]); /// start_wall 偏移开始加

        WallPart dealer_wall_left = draw.remove_at(0); // 0 is the start_wall in draw     left: 剩余
        WallPart p = dealer_wall_left.dead_split(split_stack); // this.split = context.wall_split = wall_index from dice;
        draw.insert(0, p);
        p.animate_move(-delta, time);

        // For 28 tiles per wall, dead wall is 4 pairs (8 tiles)
        // Split at position 4 (counted from the right side of the wall)
        if (split_stack > 4)
        {
            var part = dealer_wall_left.dead_split(split_stack - 4); // 退4墩再割,割出来正好用来做dead wall
            part.to_dead_wall(); 
            dead.add(part);
            draw.add(dealer_wall_left);

            dealer_wall_left.animate_move(delta, time);
        }
        else
        {
            // left: 剩余
            dead.add(dealer_wall_left);
            dealer_wall_left.to_dead_wall(); 

            if (split_stack != 4)
            {
                // 跨墙往 dead wall 放
                // For 28-tile walls: 14 pairs - 4 dead wall pairs = 10 draw pairs
                // Split from the end of the opposite wall
                var part = draw[3].dead_split(10 + split_stack);
                dead.add(part);
                part.to_dead_wall();
                part.animate_move(-delta, time);
            }
        }

        draw_parts = draw;
        dead_parts = dead;
      
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
        // Draw from dead_parts[0] which is the far end (away from draw wall and mark)
        if (dead_parts[0].empty)
            dead_parts.remove_at(0);
        if (dead_parts.size == 0)
            return null;
        return dead_parts[0].dead_draw();
    }

    public void flip_dead_wall_mark(int mark_tile_id)
    {
        // Flip the mark tile specified by the server
        foreach (WallPart part in dead_parts)
        {
            int index = part.find_tile_index(mark_tile_id);
            if (index >= 0)
            {
                part.flip_dead_wall_mark(index, context.server_times.dead_wall_mark_flip);
                return;
            }
        }
    }

    public void dead_tile_add()
    {
        int i = draw_parts.size - 1;
        WallPart last = draw_parts[i];
        if (last.empty)
            draw_parts.remove_at(i--);

        dead_parts[dead_parts.size - 1].dead_tile_add(draw_parts[i].remove_last(context.server_times.dead_wall_mark_flip), context.server_times.dead_wall_mark_flip);
    }

    public class WallPart : WorldObject
    {
        private ArrayList<RenderTile> tiles = new ArrayList<RenderTile>();
        private Vec3 tile_size;
        private int removed_tiles;

        private int tiles_added;
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

        // The server has already reversed the logical order to match drawing from the far end
        // Tiles arrive: [0]=far end (upper), [1]=far end (lower), ..., [6]=mark (upper), [7]=near (lower)
        // Visual positions are set by order() which places tiles based on array index
        public void to_dead_wall()
        {
            // Server already reversed - just keep the order
        }

        // from the wall, remove the dead wall part
        public WallPart dead_split(int index_stack)
        {
            ArrayList<RenderTile> split = new ArrayList<RenderTile>();

            int index = index_stack * 2; // a stack contains upper and lower tiles

            while (index < tiles.size)
                 // continues remove from same position which will be filled from follow-up tiles
                split.add(tiles.remove_at(index));

            Vec3 pos = Vec3(split[0].position.x, 0, 0);

            WallPart wall = new WallPart(split.to_array(), tile_size); // the wall without dead wall
            get_parent().add_object(wall);
            wall.position = position.plus(pos);

            return wall; // the wall without dead wall
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

            if (empty)
                return null;

            RenderTile tile = tiles.remove_at(0);
            return tile;
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

        public RenderTile? get_tile_at(int index)
        {
            if (index >= 0 && index < tiles.size)
                return tiles[index];
            return null;
        }

        public int find_tile_index(int tile_ID)
        {
            for (int i = 0; i < tiles.size; i++)
            {
                if (tiles[i].tile_type.ID == tile_ID)
                {
                    return i;
                }
            }
            return -1;
        }

        public bool flip_dead_wall_mark(int index,AnimationTime time)
        {
            if (index >= 0 && index < tiles.size)
            {
                RenderTile t = tiles[index];
                Quat rot = Quat.from_euler(0, 1, 0).mul(t.rotation);
                t.animate_towards(t.position, rot, time);
            }
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

        public bool empty { get { return tiles.size == 0; } }
    }
}
