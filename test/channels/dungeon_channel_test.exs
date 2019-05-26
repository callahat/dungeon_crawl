defmodule DungeonCrawl.DungeonChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.DungeonChannel
  alias DungeonCrawl.Dungeon

  @player_row 3
  @player_col 1

  setup config do
    # set the tile north of player_loc, for testing purposes
    north_tile = if tile = config[:up_tile], do: tile, else: "."

    dungeon = insert_stubbed_dungeon(%{}, [%{row: @player_row-1, col: @player_col, tile: north_tile},
                                           %{row: @player_row, col: @player_col, tile: "."}])
    player_location = insert_player_location(%{dungeon_id: dungeon.id, row: @player_row, col: @player_col})

    {:ok, _, socket} =
      socket("user_id_hash", %{user_id_hash: player_location.user_id_hash})
      |> subscribe_and_join(DungeonChannel, "dungeons:#{dungeon.id}")

    {:ok, socket: socket, player_location: player_location}
  end

  defp _player_location_north(player_location) do
    %{dungeon_id: player_location.dungeon_id, row: player_location.row-1, col: player_location.col}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push socket, "ping", %{"hello" => "there"}
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to dungeon:lobby", %{socket: socket} do
    push socket, "shout", %{"hello" => "all"}
    assert_broadcast "shout", %{"hello" => "all"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from! socket, "broadcast", %{"some" => "data"}
    assert_push "broadcast", %{"some" => "data"}
  end

  @tag up_tile: "."
  test "move replies with status ok", %{socket: socket} do
    ref = push socket, "move", %{"direction" => "up"}
    assert_reply ref, :ok, %{}
  end

  @tag up_tile: "."
  test "move broadcasts a tile_update if its a valid move", %{socket: socket} do
    push socket, "move", %{"direction" => "up"}
    assert_broadcast "tile_update", %{new_location: %{col: 1, row: 2}, old_location: %{col: 1, row: 3, tile: "."}}
  end

  @tag up_tile: "#"
  test "move broadcasts nothing if its not a valid move", %{socket: socket} do
    push socket, "move", %{"direction" => "up"}
    refute_broadcast "tile_update", _anything_really
  end

  # TODO: refactor the underlying model/channel methods into more testable concerns
  @tag up_tile: "+"
  test "use_door with a valid actions", %{socket: socket, player_location: player_location} do
    ref = push socket, "use_door", %{"direction" => "up", "action" => "open"}
    assert_reply ref, :ok, %{}
    assert_broadcast "door_changed", %{door_location: %{row: _, col: _, tile: "'"}}
    assert Dungeon.get_map_tile(_player_location_north(player_location)).tile == "'"

    ref = push socket, "use_door", %{"direction" => "up", "action" => "close"}
    assert_reply ref, :ok, %{}
    assert_broadcast "door_changed", %{door_location: %{row: _, col: _, tile: "+"}}
    assert Dungeon.get_map_tile(_player_location_north(player_location)).tile == "+"
  end

  @tag up_tile: "."
  test "use_door with an invalid actions", %{socket: socket, player_location: player_location} do
    ref = push socket, "use_door", %{"direction" => "up", "action" => "open"}
    assert_reply ref, :error, %{msg: "Cannot open that"}
    refute_broadcast "door_changed", _
    assert Dungeon.get_map_tile(_player_location_north(player_location)).tile == "."

    ref = push socket, "use_door", %{"direction" => "up", "action" => "close"}
    assert_reply ref, :error, %{msg: "Cannot close that"}
    refute_broadcast "door_changed", _
    assert Dungeon.get_map_tile(_player_location_north(player_location)).tile == "."
  end

end
