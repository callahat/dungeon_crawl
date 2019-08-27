defmodule DungeonCrawl.DungeonChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.DungeonChannel
  alias DungeonCrawl.DungeonInstances, as: Dungeon

  @player_row 3
  @player_col 1

  setup config do
    basic_tiles = DungeonCrawl.TileTemplates.TileSeeder.basic_tiles()

    # set the tile north of player_loc, for testing purposes
    north_tile = basic_tiles[if(tile = config[:up_tile], do: tile, else: ".")]

    map_instance = insert_stubbed_dungeon_instance(%{},
      [Map.merge(%{row: @player_row-1, col: @player_col, tile_template_id: north_tile.id, z_index: 0},
                 Map.take(north_tile, [:character,:color,:background_color,:state,:script])),
       Map.merge(%{row: @player_row, col: @player_col, tile_template_id: basic_tiles["."].id, z_index: 0},
                 Map.take(basic_tiles["."], [:character,:color,:background_color,:state,:script]))])
    player_location = insert_player_location(%{map_instance_id: map_instance.id, row: @player_row, col: @player_col})
                      |> Repo.preload(:map_tile)

    {:ok, _, socket} =
      socket("user_id_hash", %{user_id_hash: player_location.user_id_hash})
      |> subscribe_and_join(DungeonChannel, "dungeons:#{map_instance.id}")

    {:ok, socket: socket, player_location: player_location, basic_tiles: basic_tiles}
  end

  defp _player_location_north(player_location) do
    %{map_instance_id: player_location.map_tile.map_instance_id, row: player_location.map_tile.row-1, col: player_location.map_tile.col}
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
    assert_broadcast "tile_update", %{new_location: %{col: 1, row: 2}, old_location: %{col: 1, row: 3, tile: "<span>.</span>"}}
  end

  @tag up_tile: "#"
  test "move broadcasts nothing if its not a valid move", %{socket: socket} do
    push socket, "move", %{"direction" => "up"}
    refute_broadcast "tile_update", _anything_really
  end

  # TODO: refactor the underlying model/channel methods into more testable concerns
  @tag up_tile: "+"
  test "use_door with a valid actions", %{socket: socket, player_location: player_location, basic_tiles: basic_tiles} do
    ref = push socket, "use_door", %{"direction" => "up", "action" => "open"}
    assert_reply ref, :ok, %{}
    assert_broadcast "door_changed", %{door_location: %{row: _, col: _, tile: "<span>'</span>"}}
    assert Dungeon.get_map_tile(_player_location_north(player_location)).tile_template_id == basic_tiles["'"].id

    ref = push socket, "use_door", %{"direction" => "up", "action" => "close"}
    assert_reply ref, :ok, %{}
    assert_broadcast "door_changed", %{door_location: %{row: _, col: _, tile: "<span>+</span>"}}
    assert Dungeon.get_map_tile(_player_location_north(player_location)).tile_template_id == basic_tiles["+"].id
  end

  @tag up_tile: "."
  test "use_door with an invalid actions", %{socket: socket, player_location: player_location, basic_tiles: basic_tiles} do
    ref = push socket, "use_door", %{"direction" => "up", "action" => "open"}
    assert_reply ref, :error, %{msg: "Cannot open that"}
    refute_broadcast "door_changed", _
    assert Dungeon.get_map_tile(_player_location_north(player_location)).tile_template_id == basic_tiles["."].id

    ref = push socket, "use_door", %{"direction" => "up", "action" => "close"}
    assert_reply ref, :error, %{msg: "Cannot close that"}
    refute_broadcast "door_changed", _
    assert Dungeon.get_map_tile(_player_location_north(player_location)).tile_template_id == basic_tiles["."].id
  end
end
