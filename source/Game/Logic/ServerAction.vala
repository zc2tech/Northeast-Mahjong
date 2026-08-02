using Engine;

public abstract class ServerAction : Serializable {}

public class TileDrawServerAction : ServerAction
{
	public TileDrawServerAction(int player, int tile_ID)
	{
		this.player = player;
		this.tile_ID = tile_ID;
	}
	public new string to_string()
    {
        return @"DrawAction from player_index: $(this.player)";
    }

	public int player { get; protected set; }
	public int tile_ID { get; protected set; }
}

public class ClientServerAction : ServerAction
{
	public ClientServerAction(int client, ClientAction action)
	{
		this.client = client;
		this.action = action;
	}

	public new string to_string()
    {	
        return @"$(this.action.to_string()) client: $(this.client)";
    }

	public int client { get; protected set; }
	public ClientAction action { get; protected set; }
}

public class DefaultDiscardServerAction : ServerAction
{
	public DefaultDiscardServerAction(int client, int tile)
	{
		this.client = client;
		this.tile = tile;
	}

	public int client { get; protected set; }
	public int tile { get; protected set; }
}

public class DefaultNoCallServerAction : ServerAction {}