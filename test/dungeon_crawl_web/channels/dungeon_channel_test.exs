defmodule DungeonCrawl.DungeonChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.DungeonChannel
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.MapSetProcess
  alias DungeonCrawl.DungeonProcesses.MapSetRegistry
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileSeeder

  @player_row 3
  @player_col 1

  setup config do
    DungeonCrawl.TileTemplates.TileSeeder.BasicTiles.bullet_tile

    message_tile = TileTemplates.create_tile_template!(
                     %{name: "message",
                       description: "test",
                       script: "#END\n:TOUCH\nJust a tile\nwith line o text",
                       active: true,
                       public: true})
    transport_tile = TileTemplates.create_tile_template!(
                       %{name: "transport",
                         description: "test",
                         script: "#END\n:TOUCH\n#TRANSPORT ?sender, 1, test",
                         active: true,
                         public: true})
    basic_tiles = Map.put TileSeeder.basic_tiles(), "message_tile", message_tile
    basic_tiles = Map.put basic_tiles, "transport_tile", transport_tile

    # set the tile north of player_loc, for testing purposes
    north_tile = basic_tiles[if(tile = config[:up_tile], do: tile, else: ".")]

    map_set_instance = insert_stubbed_map_set_instance(%{}, %{}, [
        [Map.merge(%{row: @player_row-1, col: @player_col, tile_template_id: north_tile.id, z_index: 0},
                   Map.take(north_tile, [:character,:color,:background_color,:state,:script, :name])),
         Map.merge(%{row: @player_row, col: @player_col, tile_template_id: basic_tiles["."].id, z_index: 0},
                   Map.take(basic_tiles["."], [:character,:color,:background_color,:state,:script, :name])),
         Map.merge(%{row: @player_row+1, col: @player_col, tile_template_id: basic_tiles["."].id, z_index: 0,
                     script: "#PASSAGE test"},
                   Map.take(basic_tiles["."], [:character,:color,:background_color,:state, :name]))],
        []
      ])

    map_instance = Enum.sort(Repo.preload(map_set_instance, :maps).maps, fn(a, b) -> a.number < b.number end)
                   |> Enum.at(0)

    player_location = insert_player_location(%{map_instance_id: map_instance.id, row: @player_row, col: @player_col, state: "ammo: #{config[:ammo] || 10}, health: #{config[:health] || 100}, deaths: 1, gameover: #{config[:gameover] || false}"})
                      |> Repo.preload(:map_tile)

    {:ok, map_set_process} = MapSetRegistry.lookup_or_create(MapSetInstanceRegistry, map_set_instance.id)
    instance_registry = MapSetProcess.get_instance_registry(map_set_process)
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, map_instance.id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      {_, state} = Instances.create_player_map_tile(instance_state, player_location.map_tile, player_location)
      {:ok, %{ state | rerender_coords: %{}}}
    end)

    {:ok, _, socket} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: player_location.user_id_hash})
      |> subscribe_and_join(DungeonChannel, "dungeons:#{map_set_instance.id}:#{map_instance.id}")

    on_exit(fn -> MapSetRegistry.remove(MapSetInstanceRegistry, map_set_instance.id) end)

    {:ok, socket: socket, player_location: player_location, basic_tiles: basic_tiles, instance: instance, instance_registry: instance_registry}
  end

  defp _player_location_north(player_location) do
    %{map_instance_id: player_location.map_tile.map_instance_id, row: player_location.map_tile.row-1, col: player_location.map_tile.col}
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
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, row: 2, rendering: "<div>@</div>"}, %{col: 1, row: 3, rendering: "<div>.</div>"}]}
  end

  @tag up_tile: "."
  test "move broadcasts a tile_update if its a valid move at the edge", %{socket: socket, player_location: player_location, instance: instance} do
    InstanceProcess.run_with(instance, fn (instance_state) ->
      player_map_tile = Instances.get_map_tile_by_id(instance_state, %{id: player_location.map_tile_instance_id})
      instance_state = %{instance_state | adjacent_map_ids: %{"north" => instance_state.instance_id}}
      Instances.update_map_tile(instance_state, player_map_tile, %{row: 0})
    end)

    push socket, "move", %{"direction" => "up"}
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, row: 19, rendering: "<div>@</div>"}]}
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, row: 0, rendering: "<div> </div>"}]}
  end

  @tag up_tile: ".", health: 0
  test "move broadcasts nothing if player is dead", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, player_location.map_tile.map_instance_id)
    north_tile = InstanceProcess.get_tile(instance, player_location.map_tile.row, player_location.map_tile.col, "north")
    push socket, "move", %{"direction" => "up"}
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
    refute_broadcast "tile_changes", _anything
  end

  @tag up_tile: ".", gameover: true
  test "move does nothing if gameover for player", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, player_location.map_tile.map_instance_id)
    north_tile = InstanceProcess.get_tile(instance, player_location.map_tile.row, player_location.map_tile.col, "north")
    push socket, "move", %{"direction" => "up"}
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
    refute_broadcast "tile_changes", _anything
  end

  @tag up_tile: "."
  test "move broadcasts a tile_update if its a valid move when starting location only had the tile that moved", %{socket: socket, instance_registry: instance_registry} do
    map_tile = Repo.get_by(DungeonInstances.MapTile, %{row: @player_row, col: @player_col, z_index: 0})
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, map_tile.map_instance_id)
    InstanceProcess.delete_tile(instance, map_tile.id)
    push socket, "move", %{"direction" => "up"}
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, row: 2, rendering: "<div>@</div>"}, %{col: 1, row: 3, rendering: "<div> </div>"}]}
  end

  @tag up_tile: "."
  test "move clears the message_actions for that player", %{socket: socket, player_location: player_location, instance: instance} do
    InstanceProcess.run_with(instance, fn (instance_state) ->
      instance_state = Instances.set_message_actions(instance_state, player_location.map_tile_instance_id, ["messaged"])
      {:ok, instance_state}
    end)
    push socket, "move", %{"direction" => "up"}
    InstanceProcess.run_with(instance, fn (instance_state) ->
      refute Map.has_key?(instance_state, player_location.map_tile_instance_id)
      {:ok, instance_state}
    end)
  end

  @tag up_tile: "#"
  test "move broadcasts nothing if its not a valid move", %{socket: socket} do
    push socket, "move", %{"direction" => "up"}
    refute_broadcast "tile_changes", _anything_really
  end

  @tag up_tile: "#"
  test "move broadcasts nothing if there is no destination tile", %{socket: socket, instance: instance} do
    InstanceProcess.run_with(instance, fn (instance_state) ->
      wall_map_tile = Instances.get_map_tile(instance_state, %{row: 2, col: 1})
      {_, state} = Instances.delete_map_tile(instance_state, wall_map_tile)
      {:ok, %{ state | rerender_coords: %{} }}
    end)

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
        payload: %{message: ["Just a tile", "with line o text"], modal: true}}
  end

  @tag up_tile: "transport_tile"
  test "move where a touched object moves the player", %{socket: socket} do
    push socket, "move", %{"direction" => "up"}

    # up would normally move player here to row 2, however the transport_tile causes the player
    # to move to the passage exit at 4,1; and the player stops there
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, row: 3, rendering: "<div>.</div>"},
                                               %{col: 1, row: 4, rendering: "<div>@</div>"}]}
  end

  test "message_action handles an inbound message", %{socket: socket, player_location: player_location, instance: instance} do
    message_object = \
    InstanceProcess.run_with(instance, fn (instance_state) ->
      instance_state = Instances.set_message_actions(instance_state, player_location.map_tile_instance_id, ["messaged"])
      {:ok, message_object} = DungeonInstances.new_map_tile(%{map_instance_id: instance_state.instance_id,
                                                              row: @player_row,
                                                              col: @player_col+1,
                                                              script: """
                                                                      #END
                                                                      :touch
                                                                      :messaged
                                                                      oh hai mark
                                                                      """})

      Instances.create_map_tile(instance_state, message_object)
    end)

    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "message_action", %{"label" => "messaged", "tile_id" => message_object.id}

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "oh hai mark"}}

    InstanceProcess.run_with(instance, fn (instance_state) ->
      refute Map.has_key?(instance_state, player_location.map_tile_instance_id)
      {:ok, instance_state}
    end)

    # when the message is not valid for the player to send, nothing happens
    push socket, "message_action", %{"label" => "touch", "tile_id" => message_object.id}
    refute_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel }
  end

  test "message_action handles bad inbound messages ok", %{socket: socket, player_location: player_location} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    assert push socket, "message_action", %{"label" => "messaged", "tile_id" => "new_0"}
    assert push socket, "message_action", %{"label" => "messaged", "tile_id" => "123"}

    refute_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel}
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

  @tag up_tile: "."
  test "does not let the player shoot if map set to pacifism", %{socket: socket,
                                                                 player_location: player_location,
                                                                 instance_registry: instance_registry} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, player_location.map_tile.map_instance_id)
    InstanceProcess.set_state_values(instance, %{pacifism: true})
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "tile_changes", %{tiles: [%{col: 1, rendering: "<div>◦</div>", row: 2}] }
    assert_broadcast "message", %{message: "Can't shoot here!"}
  end

  @tag up_tile: ".", health: 0
  test "does not let the player shoot if dead", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, player_location.map_tile.map_instance_id)
    north_tile = InstanceProcess.get_tile(instance, player_location.map_tile.row, player_location.map_tile.col, "north")
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
    refute_broadcast "tile_changes", _anything
    refute_broadcast "message", _anything
  end

  @tag up_tile: ".", gameover: true
  test "does not let the player shoot if gameover", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, player_location.map_tile.map_instance_id)
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

  @tag up_tile: ".", ammo: 1
  test "shoot clears the message_actions for that player", %{socket: socket, player_location: player_location, instance: instance} do
    InstanceProcess.run_with(instance, fn (instance_state) ->
      instance_state = Instances.set_message_actions(instance_state, player_location.map_tile_instance_id, ["messaged"])
      {:ok, instance_state}
    end)
    push socket, "shoot", %{"direction" => "up"}
    InstanceProcess.run_with(instance, fn (instance_state) ->
      refute Map.has_key?(instance_state, player_location.map_tile_instance_id)
      {:ok, instance_state}
    end)
  end

  @tag up_tile: "."
  test "speak broadcasts to other players that can hear", %{socket: socket, player_location: player_location, instance: instance, instance_registry: instance_registry} do
    # setup
    other_player_location = \
    InstanceProcess.run_with(instance, fn (instance_state) ->
      other_player_location = insert_player_location(%{map_instance_id: instance_state.instance_id,
                                                       row: @player_row-2,
                                                       col: @player_col,
                                                       user_id_hash: "samelvlhash"})

      other_player_map_tile = Repo.preload(other_player_location, :map_tile).map_tile
      {_, state} = Instances.create_player_map_tile(instance_state, other_player_map_tile, other_player_location)
      {other_player_location, state}
    end)

    other_map_instance = Enum.sort(Repo.preload(player_location, [map_tile: [dungeon: [map_set: :maps]]]).map_tile.dungeon.map_set.maps,
                                   fn(a,b) -> a.number < b.number end)
                         |> Enum.at(1)


    {:ok, other_instance} = InstanceRegistry.lookup_or_create(instance_registry, other_map_instance.id)
    other_level_pl = \
    InstanceProcess.run_with(other_instance, fn (instance_state) ->
      other_level_pl = insert_player_location(%{map_instance_id: instance_state.instance_id, user_id_hash: "otherlvlhash"})
      Instances.create_player_map_tile(instance_state, Repo.preload(other_level_pl, :map_tile).map_tile, other_level_pl)
      other_player_lvl_map_tile = Repo.preload(other_level_pl, :map_tile).map_tile
      {_, state} = Instances.create_player_map_tile(instance_state, other_player_lvl_map_tile, other_level_pl)
      {other_level_pl, state}
    end)

    player_channel = "players:#{player_location.id}"
    other_player_channel = "players:#{other_player_location.id}"
    other_level_player_channel = "players:#{other_level_pl.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    DungeonCrawlWeb.Endpoint.subscribe(other_player_channel)
    DungeonCrawlWeb.Endpoint.subscribe(other_level_player_channel)
    # /setup

    ref = push socket, "speak", %{"words" => "<i>words</i>"}

    # HTML escapes the incoming payload
    assert_reply ref, :ok, %{safe_words: "&lt;i&gt;words&lt;/i&gt;"}

    refute_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^other_player_channel,
        event: "message",
        payload: %{message: "<b>AnonPlayer:</b> &lt;i&gt;words&lt;/i&gt;"}}
    refute_receive %Phoenix.Socket.Broadcast{
        topic: ^other_level_player_channel}

    # does not go through walls
    InstanceProcess.run_with(instance, fn (instance_state) ->
      wall_tile = %DungeonInstances.MapTile{id: "new_1",
                                            state: "blocking: true",
                                            character: "#",
                                            map_instance_id: instance_state.instance_id,
                                            row: @player_row-1,
                                            col: @player_col,
                                            z_index: 10}
      {_, state} = Instances.create_map_tile(instance_state, wall_tile)
      {:ok, %{ state | rerender_coords: %{} }}
    end)

    ref = push socket, "speak", %{"words" => "<i>words</i>"}
    assert_reply ref, :ok, %{safe_words: "&lt;i&gt;words&lt;/i&gt;"}
    refute_receive %Phoenix.Socket.Broadcast{event: "message"}

    # /level prefix messages everyone in the level (even if blocked by a wall)
    ref = push socket, "speak", %{"words" => "/level To everyone on this floor"}
    assert_reply ref, :ok, %{safe_words: "To everyone on this floor"}
    refute_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^other_player_channel,
        event: "message",
        payload: %{message: "<b>AnonPlayer</b> <i>to level</i><b>:</b> To everyone on this floor"}}
    refute_receive %Phoenix.Socket.Broadcast{
        topic: ^other_level_player_channel,
        event: "message",
        payload: _anything}

    # /dungeon prefix messages everyone in the same map set instance (ie, same dungeon including different levels
    ref = push socket, "speak", %{"words" => "/dungeon <i>To everyone in this dungeon</i>"}
    assert_reply ref, :ok, %{safe_words: "&lt;i&gt;To everyone in this dungeon&lt;/i&gt;"}
    refute_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^other_player_channel,
        event: "message",
        payload: %{message: "<b>AnonPlayer</b> <i>to dungeon</i><b>:</b> &lt;i&gt;To everyone in this dungeon&lt;/i&gt;"}}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^other_level_player_channel,
        event: "message",
        payload: %{message: "<b>AnonPlayer</b> <i>to dungeon</i><b>:</b> &lt;i&gt;To everyone in this dungeon&lt;/i&gt;"}}
  end


  # TODO: refactor the underlying model/channel methods into more testable concerns
  @tag up_tile: "+"
  test "use_door with a valid actions", %{socket: socket, player_location: player_location, basic_tiles: basic_tiles, instance_registry: instance_registry} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, player_location.map_tile.map_instance_id)
    north_tile = _player_location_north(player_location)

    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    assert_broadcast "tile_changes", %{tiles: [%{row: _, col: _, rendering: "<div>'</div>"}]}
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["'"].character
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).script == basic_tiles["'"].script
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).state == basic_tiles["'"].state

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    assert_broadcast "tile_changes", %{tiles: [%{row: _, col: _, rendering: "<div>+</div>"}]}
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["+"].character
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).script == basic_tiles["+"].script
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).state == basic_tiles["+"].state
  end

  @tag up_tile: "."
  test "use_door with an invalid actions", %{socket: socket, player_location: player_location, basic_tiles: basic_tiles, instance_registry: instance_registry} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    north_tile = _player_location_north(player_location)
    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, player_location.map_tile.map_instance_id)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "Cannot open that"}}
    refute_broadcast "tile_changes", _
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["."].character

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "Cannot close that"}}

    refute_broadcast "tile_changes", _
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["."].character
  end

  @tag up_tile: "+", health: 0
  test "use_door does nothing if player is dead", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, player_location.map_tile.map_instance_id)
    north_tile = InstanceProcess.get_tile(instance, player_location.map_tile.row, player_location.map_tile.col, "north")

    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    refute_broadcast "tile_changes", _anything
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    refute_broadcast "tile_changes", _anything
    assert InstanceProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
  end

  @tag up_tile: "+", gameover: true
  test "use_door does nothing if player gameover", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = InstanceRegistry.lookup_or_create(instance_registry, player_location.map_tile.map_instance_id)
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
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    ref = push socket, "respawn", %{}
    assert_reply ref, :ok, %{}
    assert_broadcast "tile_changes", %{tiles: [%{col: _, row: _, rendering: "<div>@</div>"}]}
    assert_broadcast "stat_update", %{stats: %{health: 100}}
    assert_broadcast "message", %{message: "You live again, after 1 death"}
  end

  @tag up_tile: ".", gameover: true
  test "respawn does nothing if player gameover", %{socket: socket, player_location: player_location}  do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    ref = push socket, "respawn", %{}
    assert_reply ref, :ok, %{}
    refute_broadcast "tile_changes", %{tiles: [%{col: _, row: _, rendering: "<div>@</div>"}]}
    refute_broadcast "stat_update", %{stats: %{health: 100}}
    refute_broadcast "message", %{message: "You live again, after 1 death"}
  end

  test "terminate/2", %{socket: socket, player_location: player_location, instance: instance} do
    Process.unlink(socket.channel_pid) # Keep the close from raising the error in this test
    :ok = close(socket)

    InstanceProcess.run_with(instance, fn (%{inactive_players: inactive_players} = instance_state) ->
      assert inactive_players[player_location.map_tile_instance_id]
      {:ok, instance_state}
    end)
  end
end
