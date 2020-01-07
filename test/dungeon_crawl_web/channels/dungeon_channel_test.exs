defmodule DungeonCrawl.DungeonChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.DungeonChannel
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileSeeder

  @player_row 3
  @player_col 1

  setup config do
    message_tile = TileTemplates.create_tile_template!(
                     Map.merge(%{name: "message", description: "test", script: "#END\n:TOUCH\nJust a tile\nwith line o text"},
                               %{active: true, public: true}))
    basic_tiles = Map.put TileSeeder.basic_tiles(), "message_tile", message_tile

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
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: player_location.user_id_hash})
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

#  test "can broadcase outside", %{socket: socket, player_location: pl} do
#    DungeonCrawlWeb.Endpoint.broadcast "dungeons:#{Repo.preload(pl, :map_tile).map_tile.map_instance_id}", "something", %{"some" => "data"}
#    assert_broadcast "something", %{"some" => "data"}
#  end

  @tag up_tile: "."
  test "move replies with status ok", %{socket: socket} do
    ref = push socket, "move", %{"direction" => "up"}
    assert_reply ref, :ok, %{}
  end

  @tag up_tile: "."
  test "move broadcasts a tile_update if its a valid move", %{socket: socket} do
    push socket, "move", %{"direction" => "up"}
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, row: 2, rendering: "<div>@</div>"}, %{col: 1, row: 3, rendering: "<div>.</div>"}]}
  end

  @tag up_tile: "."
  test "move broadcasts a tile_update if its a valid move when starting location only had the tile that moved", %{socket: socket} do
    map_tile = Repo.get_by(DungeonInstances.MapTile, %{row: @player_row, col: @player_col, z_index: 0})
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
    InstanceProcess.delete_tile(instance, map_tile.id)
    push socket, "move", %{"direction" => "up"}
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, row: 2, rendering: "<div>@</div>"}, %{col: 1, row: 3, rendering: "<div></div>"}]}
  end

  @tag up_tile: "#"
  test "move broadcasts nothing if its not a valid move", %{socket: socket} do
    push socket, "move", %{"direction" => "up"}
    refute_broadcast "tile_changes", _anything_really
  end

  @tag up_tile: "."
  test "step does not reply if nothing happens", %{socket: socket} do
    ref = push socket, "step", %{"direction" => "up"}
    refute_reply ref, _, _
    refute_broadcast _any_event, _any_payload
  end

  @tag up_tile: "."
  test "step does not reply if there is no tile", %{socket: socket} do
    Repo.get_by(DungeonInstances.MapTile, %{row: @player_row-1, col: @player_col})
    |> Repo.delete!
    ref = push socket, "step", %{"direction" => "up"}
    refute_reply ref, _, _
    refute_broadcast _any_event, _any_payload
  end

  @tag up_tile: "message_tile"
  test "step replies with messages", %{socket: socket, player_location: player_location} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "step", %{"direction" => "up"}

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "Just a tile"}}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "with line o text"}}
    refute_broadcast _any_event, _any_payload
  end

  # TODO: refactor the underlying model/channel methods into more testable concerns
  @tag up_tile: "+"
  test "use_door with a valid actions", %{socket: socket, player_location: player_location, basic_tiles: basic_tiles} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, player_location.map_tile.map_instance_id)
    north_tile = _player_location_north(player_location)

    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    assert_broadcast "tile_changes", %{tiles: [%{row: _, col: _, rendering: "<div>'</div>"}]}
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).tile_template_id == basic_tiles["'"].id
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["'"].character
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).script == basic_tiles["'"].script
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).state == basic_tiles["'"].state

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    assert_broadcast "tile_changes", %{tiles: [%{row: _, col: _, rendering: "<div>+</div>"}]}
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).tile_template_id == basic_tiles["+"].id
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["+"].character
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).script == basic_tiles["+"].script
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).state == basic_tiles["+"].state
  end

  @tag up_tile: "."
  test "use_door with an invalid actions", %{socket: socket, player_location: player_location, basic_tiles: basic_tiles} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    north_tile = _player_location_north(player_location)
    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, player_location.map_tile.map_instance_id)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "Cannot open that"}}
    refute_broadcast "tile_changes", _
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).tile_template_id == basic_tiles["."].id

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "Cannot close that"}}

    refute_broadcast "tile_changes", _
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).tile_template_id == basic_tiles["."].id
  end
end
