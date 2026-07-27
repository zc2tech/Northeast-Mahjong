using Gee;

public class GameState : Object
{
    private GameScorePlayer[] players;
    private int starting_score;
    private int uma_higher;
    private int uma_lower;

    public GameState(GameStartInfo info, ServerSettings settings) // TODO: Remove settings if we don't need them
    {
        starting_score = info.starting_score;
        dealer_index = starting_dealer_index = info.starting_dealer;
        round_count = info.round_count;
        hanchan_count = info.hanchan_count;
        scores = new ArrayList<RoundScoreState>();
        round_is_finished = true;

        GamePlayer[] p = info.get_players();
        players = new GameScorePlayer[p.length];

        for (int i = 0; i < players.length; i++)
            players[i] = new GameScorePlayer(p[i].name, i, (Wind)((i + 4 - starting_dealer_index) % 4), info.starting_score, 0, 0);
    }

    public void start_round(RoundStartInfo info)
    {
        if (game_is_finished || !round_is_finished)
            return;

        if (game_is_started)
        {
        
            for (int i = 0; i < players.length; i++)
                players[i].transfer = 0;

            if (hanchan_is_finished)
            {
                current_hanchan++;
                current_round = 0;
                renchan = 0;
                dealer_index = starting_dealer_index;
                round_wind = Wind.EAST;

                for (int i = 0; i < players.length; i++)
                    players[i] = new GameScorePlayer(players[i].name, players[i].index, (Wind)((i + 4 - starting_dealer_index) % 4), starting_score, players[i].score, 0);
            }
            else
            {
                if (do_renchan)
                    renchan++;
                else
                {
                    renchan = 0;

                    current_round++;
                    dealer_index = (dealer_index + 1) % players.length;

                    if (current_round % players.length == 0)
                        round_wind = NEXT_WIND(round_wind);

                    for (int i = 0; i < players.length; i++)
                        players[i].wind = PREVIOUS_WIND(players[i].wind);
                }
            }
        }
        else
            game_is_started = true;

        round_is_finished = false;
        hanchan_is_finished = false;

        add_round_score_state(new RoundFinishResult()); // Add temp info (is not a proper round)
    }

    public RoundScoreState? round_finished(RoundFinishResult result)
    {
        if (game_is_finished || round_is_finished)
            return null;

        round_is_finished = true;
        do_renchan = false;

        bool ron = result.result == RoundFinishResult.RoundResultEnum.RON;
        bool tsumo = result.result == RoundFinishResult.RoundResultEnum.TSUMO;
        int sekinin_index = -1;
        if (result.scores.length > 0)
            sekinin_index = result.scores[0].player.sekinin_index;
        bool sekinin = sekinin_index != -1;

        if (ron || (tsumo && sekinin))
        {
            int loser  = result.loser_index;

            for (int i = 0; i < result.winner_indices.length; i++)
            {
                int winner = result.winner_indices[i];
                sekinin_index = result.scores[i].player.sekinin_index;
                sekinin = sekinin_index != -1;

                int transfer = result.scores[i].total_points + renchan * 300;
                players[winner].transfer += transfer;
                // 这个sekinin 包含最后的点炮选手 ？
                if (sekinin)
                {
                    if (ron)
                        transfer /= 2;
                    players[sekinin_index].transfer -= transfer;
                }

                if (ron)
                    players[loser].transfer -= transfer;

                if (dealer_index == winner)
                    do_renchan = true;
            }

        }
        else if (result.result == RoundFinishResult.RoundResultEnum.TSUMO)
        {
            Scoring score = result.scores[0];
            int winner = result.winner_indices[0];

            if (dealer_index == winner)
            {
                for (int i = 0; i < players.length; i++)
                    if (i != dealer_index)
                        players[i].transfer -= score.tsumo_points + renchan * 100;

                do_renchan = true;
            }
            else
            {
                for (int i = 0; i < players.length; i++)
                {
                    if (i == winner)
                        continue;
                    else if (i == dealer_index)
                        players[i].transfer -= score.tsumo_points + renchan * 100;
                    else
                        players[i].transfer -= score.tsumo_points  + renchan * 100;
                }
            }

            players[winner].transfer += score.total_points + renchan * 300;
        }
        // 流局
        else if (result.result == RoundFinishResult.RoundResultEnum.DRAW)
        {
            // 流局应该算连庄吧
            do_renchan = true; // Abortive draw is always renchan
        }
        else
            return null; // Shouldn't happen

        // 把钱放到玩家口袋
        for (int i = 0; i < players.length; i++)
            players[i].points += players[i].transfer;

        if (!do_renchan)
            hanchan_is_finished = (current_round + 1) >= round_count; // 半庄是什么鬼？

        for (int i = 0; i < players.length; i++)
            if (players[i].points < 0)
            {
                hanchan_is_finished = true;
                break;
            }

        if (hanchan_is_finished)
        {
            calculate_score();

            if ((current_hanchan + 1) == hanchan_count)
                game_is_finished = true;
        }

        return replace_round_score_state(result);
    }

    public GameScorePlayer get_player(int index)
    {
        return players[index];
    }

    private void calculate_score()
    {
        GameScorePlayer[] ordered_players = new GameScorePlayer[players.length];

        for (int i = 0; i < ordered_players.length; i++)
        {
            int a = (starting_dealer_index + i) % players.length;
            ordered_players[i] = players[a]; // 把庄家放到了 ordered_players[0]
        }

        for (int i = 1; i < players.length; i++)
        {
            int j = i;
            while (j > 0 && ordered_players[j].points > ordered_players[j-1].points)
            {
                var p = ordered_players[j];
                ordered_players[j] = ordered_players[j-1];
                ordered_players[j-1] = p;
                j--;
            }
        }

        int sum = 0;
        for (int i = 1; i < ordered_players.length; i++)
        {
            // Round to nearest 1000
            int p = ordered_players[i].points;
            if (ordered_players[i].points > 0)
                p += 500;
            else
                p -= 500;

            p = p / 1000 - starting_score / 1000 - 5;
            sum -= p;
            ordered_players[i].score += p;
        }

        ordered_players[0].score += sum;
        ordered_players[0].score += uma_higher;
        ordered_players[1].score += uma_lower;
        ordered_players[ordered_players.length - 2].score -= uma_lower;
        ordered_players[ordered_players.length - 1].score -= uma_higher;
    }

    private RoundScoreState add_round_score_state(RoundFinishResult result)
    {
        RoundScoreState score = new RoundScoreState
        (
            result,
            players,
            round_wind,
            starting_dealer_index,
            dealer_index,
            current_round,
            renchan,
            current_hanchan,
            hanchan_count,
            round_is_finished,
            hanchan_is_finished,
            game_is_started,
            game_is_finished,
            do_renchan
        );
        scores.add(score);
        return score;
    }

    private RoundScoreState replace_round_score_state(RoundFinishResult result)
    {
        assert(scores.size > 0);

        RoundScoreState score = new RoundScoreState
        (
            result,
            players,
            round_wind,
            starting_dealer_index,
            dealer_index,
            current_round,
            renchan,
            current_hanchan,
            hanchan_count,
            round_is_finished,
            hanchan_is_finished,
            game_is_started,
            game_is_finished,
            do_renchan
        );

        scores.remove_at(scores.size - 1);
        scores.add(score);
        return score;
    }

    public string to_string()
    {
        string str =

        "round_wind: " + round_wind.to_string() + "\n" +
        "starting_dealer_index: " + starting_dealer_index.to_string() + "\n" +
        "dealer_index: " + dealer_index.to_string() + "\n" +
        "current_round: " + current_round.to_string() + "\n" +
        "round_count: " + round_count.to_string() + "\n" +
        "renchan: " + renchan.to_string() + "\n" +
        "current_hanchan: " + current_hanchan.to_string() + "\n" +
        "hanchan_count: " + hanchan_count.to_string() + "\n" +
        "round_is_finished: " + round_is_finished.to_string() + "\n" +
        "hanchan_is_finished: " + hanchan_is_finished.to_string() + "\n" +
        "game_is_started: " + game_is_started.to_string() + "\n" +
        "game_is_finished: " + game_is_finished.to_string() + "\n" +
        "do_renchan: " + do_renchan.to_string() ;
        return str;
    }

    public RoundScoreState score { owned get { return scores[scores.size - 1]; } }
    public ArrayList<RoundScoreState> scores { get; private set; }
    public Wind round_wind { get; private set; }
    public int starting_dealer_index { get; private set; }
    public int dealer_index { get; private set; }
    public int current_round { get; private set; }
    public int round_count { get; private set; }
    public int renchan { get; private set; } // 连庄
    public int current_hanchan { get; private set; }
    public int hanchan_count { get; private set; }
    public bool round_is_finished { get; private set; }
    public bool hanchan_is_finished { get; private set; }
    public bool game_is_started { get; private set; }
    public bool game_is_finished { get; private set; }
    public bool do_renchan { get; private set; }
}

public class RoundScoreState
{
    public RoundScoreState
    (
        RoundFinishResult result,
        GameScorePlayer[] players,
        Wind round_wind,
        int starting_dealer_index,
        int dealer_index,
        int current_round,
        int renchan,
        int current_hanchan,
        int hanchan_count,
        bool round_is_finished,
        bool hanchan_is_finished,
        bool game_is_started,
        bool game_is_finished,
        bool do_renchan
    )
    {
        this.result = result;
        this.round_wind = round_wind;
        this.starting_dealer_index = starting_dealer_index;
        this.dealer_index = dealer_index;
        this.current_round = current_round;
        this.round_count = round_count;
        this.renchan = renchan;
        this.current_hanchan = current_hanchan;
        this.hanchan_count = hanchan_count;
        this.riichi_count = riichi_count;
        this.round_is_finished = round_is_finished;
        this.hanchan_is_finished = hanchan_is_finished;
        this.game_is_started = game_is_started;
        this.game_is_finished = game_is_finished;
        this.do_renchan = do_renchan;

        this.players = new GameScorePlayer[players.length];
        for (int i = 0; i < players.length; i++)
            this.players[i] = new GameScorePlayer(players[i].name, players[i].index, players[i].wind, players[i].points, players[i].score, players[i].transfer);
    }

    public RoundFinishResult result { get; private set; }
    public GameScorePlayer[] players { get; private set; }
    public Wind round_wind { get; private set; }
    public int starting_dealer_index { get; private set; }
    public int dealer_index { get; private set; }
    public int current_round { get; private set; }
    public int round_count { get; private set; }
    public int renchan { get; private set; }
    public int current_hanchan { get; private set; }
    public int hanchan_count { get; private set; }
    public int riichi_count { get; private set; }
    public bool round_is_finished { get; private set; }
    public bool hanchan_is_finished { get; private set; }
    public bool game_is_started { get; private set; }
    public bool game_is_finished { get; private set; }
    public bool do_renchan { get; private set; }
}

public class GameScorePlayer
{
    public GameScorePlayer(string name, int index, Wind wind, int starting_points, int score, int transfer)
    {
        this.name = name;
        this.index = index;
        this.wind = wind;
        points = starting_points;
        this.score = score;
        this.transfer = transfer;
    }

    public string name { get; private set; }
    public int index { get; private set; }
    public Wind wind { get; set; }
    public int points { get; set; } // Regular game points
    public int score { get; set; } // +- score
    public int transfer { get; set; }
}

public class RoundFinishResult
{
    public RoundFinishResult()
    {
        result = RoundResultEnum.NONE;
    }

    public RoundFinishResult.ron(Scoring[] scores, int[] winner_indices, int loser_index, int discard_tile)
    {
        result = RoundResultEnum.RON;
        this.scores = scores;
        this.winner_indices = winner_indices;
        this.loser_index = loser_index;
        this.discard_tile = discard_tile;
    }

    public RoundFinishResult.tsumo(Scoring score, int winner_index)
    {
        result = RoundResultEnum.TSUMO;
        this.scores = new Scoring[] { score };
        this.winner_indices = new int[] { winner_index };
    }
    // 平局 流局
    public RoundFinishResult.draw(int[] tenpai_indices, int[] nagashi_indices, GameDrawType draw_type)
    {
        result = RoundResultEnum.DRAW;
        this.tenpai_indices = tenpai_indices;
        this.nagashi_indices = nagashi_indices;
        this.draw_type = draw_type;
    }

    public RoundResultEnum result { get; private set; }
    public Scoring[] scores { get; private set; }
    public GameDrawType draw_type { get; private set; }
    public int[] winner_indices { get; private set; }
    public int loser_index { get; private set; }
    public int discard_tile { get; private set; }
    public int[] tenpai_indices { get; private set; }
    public int[] nagashi_indices { get; private set; }

    public enum RoundResultEnum
    {
        RON,
        TSUMO,
        DRAW,
        NONE
    }
}
