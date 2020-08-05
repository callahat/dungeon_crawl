defmodule DungeonCrawl.DungeonChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.DungeonChannel
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.Instances
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
                 Map.take(north_tile, [:character,:color,:background_color,:state,:script, :name])),
       Map.merge(%{row: @player_row, col: @player_col, tile_template_id: basic_tiles["."].id, z_index: 0},
                 Map.take(basic_tiles["."], [:character,:color,:background_color,:state,:script, :name]))])

    player_location = insert_player_location(%{map_instance_id: map_instance.id, row: @player_row, col: @player_col, state: "ammo: #{config[:ammo] || 10}, health: #{config[:health] || 100}"})
                      |> Repo.preload(:map_tile)

    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_instance.id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      Instances.create_player_map_tile(instance_state, player_location.map_tile, player_location)
    end)

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

  @tag up_tile: ".", health: 0
  test "move broadcasts nothing if player is dead", %{socket: socket, player_location: player_location} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, player_location.map_tile.map_instance_id)
    north_tile = InstanceProcess.get_tile(instance, player_location.map_tile.row, player_location.map_tile.col, "north")
    push socket, "move", %{"direction" => "up"}
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
    refute_broadcast "tile_changes", _anything
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

  @tag up_tile: "message_tile"
  test "move replies with messages", %{socket: socket, player_location: player_location} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "move", %{"direction" => "up"}

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "Just a tile"}}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "with line o text"}}
  end

  @tag up_tile: "."
  test "pull replies with status ok", %{socket: socket} do
    # Pull is tested more in depth elsewhere, this is just verifying the channel responds to this event.
    # as far as sending broadcasts this is sufficiently covered in the move tests
    ref = push socket, "pull", %{"direction" => "up"}
    assert_reply ref, :ok, %{}
  end

  @tag up_tile: "."
  test "shoot replies with status ok", %{socket: socket} do
    ref = push socket, "shoot", %{"direction" => "up"}
    assert_reply ref, :ok, %{}
  end

  @tag up_tile: "."
  test "shoot into an empty space spawns a bullet but does not broadcast", %{socket: socket} do
    # Not sure how to check that something was set in the socket
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "tile_changes", %{tiles: [%{col: 2, rendering: "<div>◦</div>", row: 2}] }

    # but not if one has been fired in the last 100ms
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "tile_changes", %{tiles: [%{col: 2, rendering: "<div>◦</div>", row: 2}] }
  end

  @tag up_tile: ".", ammo: 0
  test "does not let the player shoot if out of ammo", %{socket: socket, player_location: player_location} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "tile_changes", %{tiles: [%{col: 1, rendering: "<div>◦</div>", row: 2}] }
    assert_broadcast "message", %{message: "Out of ammo"}
  end

  @tag up_tile: ".", health: 0
  test "does not let the player shoot if dead", %{socket: socket, player_location: player_location} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, player_location.map_tile.map_instance_id)
    north_tile = InstanceProcess.get_tile(instance, player_location.map_tile.row, player_location.map_tile.col, "north")
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
    refute_broadcast "tile_changes", _anything
    refute_broadcast "message", _anything
  end

  @tag up_tile: ".", ammo: 1
  test "updates the players stats including ammo count after shooting", %{socket: socket, player_location: player_location} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "message", %{message: "Out of ammo"}
    assert_broadcast "stat_update", %{stats: %{ammo: 0}}
  end

  @tag up_tile: " "
  test "shoot into a nil space or idle does nothing", %{socket: socket} do
    push socket, "shoot", %{"direction" => "gibberish_which_becomes_idle"}
    refute_broadcast "tile_changes", _anything_really
  end

  @tag up_tile: "#"
  test "shoot into a blocking or shootable space spawns no bullet but sends the shot message", %{socket: socket} do
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "tile_changes", _anything_really
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

  @tag up_tile: "+", health: 0
  test "use_door does nothing if player is dead", %{socket: socket, player_location: player_location} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, player_location.map_tile.map_instance_id)
    north_tile = InstanceProcess.get_tile(instance, player_location.map_tile.row, player_location.map_tile.col, "north")

    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    refute_broadcast "tile_changes", _anything
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    refute_broadcast "tile_changes", _anything
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
  end

  @tag health: 100
  test "respawn does nothing if player alive", %{socket: socket, player_location: player_location}  do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    ref = push socket, "respawn", %{}
    assert_reply ref, :ok, %{}
    refute_broadcast "tile_changes", _anything
  end

  @tag up_tile: ".", health: 0
  test "respawn respawns the player", %{socket: socket, player_location: player_location}  do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, player_location.map_tile.map_instance_id)
    InstanceProcess.get_tile(instance, player_location.map_tile.row, player_location.map_tile.col)

    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    ref = push socket, "respawn", %{}
    assert_reply ref, :ok, %{}
    assert_broadcast "tile_changes", %{tiles: [%{col: _, row: _, rendering: "<div>@</div>"}]}
    assert_broadcast "stat_update", %{stats: %{health: 100}}
    assert_broadcast "message", %{message: "You live again."}
  end
end
