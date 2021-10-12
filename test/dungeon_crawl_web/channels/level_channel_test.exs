defmodule DungeonCrawl.LevelChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.LevelChannel
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.DungeonProcess
  alias DungeonCrawl.DungeonProcesses.DungeonRegistry
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileSeeder

  @player_row 3
  @player_col 1

  setup config do
    TileSeeder.BasicTiles.bullet_tile
    Equipment.Seeder.Item.gun

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

    dungeon_instance = insert_stubbed_dungeon_instance(%{}, %{}, [
        [Map.merge(%{row: @player_row-1, col: @player_col, tile_template_id: north_tile.id, z_index: 0},
                   Map.take(north_tile, [:character,:color,:background_color,:state,:script, :name])),
         Map.merge(%{row: @player_row, col: @player_col, tile_template_id: basic_tiles["."].id, z_index: 0},
                   Map.take(basic_tiles["."], [:character,:color,:background_color,:state,:script, :name])),
         Map.merge(%{row: @player_row+1, col: @player_col, tile_template_id: basic_tiles["."].id, z_index: 0,
                     script: "#PASSAGE test"},
                   Map.take(basic_tiles["."], [:character,:color,:background_color,:state, :name]))],
        []
      ])

    level_instance = Enum.sort(Repo.preload(dungeon_instance, :levels).levels, fn(a, b) -> a.number < b.number end)
                     |> Enum.at(0)

    player_location = insert_player_location(%{level_instance_id: level_instance.id, row: @player_row, col: @player_col, state: "ammo: #{config[:ammo] || 10}, health: #{config[:health] || 100}, deaths: 1, gameover: #{config[:gameover] || false}, player: true, torches: #{config[:torches] || 0}, equipped: gun"})
                      |> Repo.preload(:tile)

    {:ok, map_set_process} = DungeonRegistry.lookup_or_create(DungeonInstanceRegistry, dungeon_instance.id)
    instance_registry = DungeonProcess.get_instance_registry(map_set_process)
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, level_instance.id)
    LevelProcess.run_with(instance, fn (instance_state) ->
      {_, state} = Levels.create_player_tile(instance_state, player_location.tile, player_location)
      {:ok, %{ state | rerender_coords: %{}}}
    end)

    {:ok, _, socket} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: player_location.user_id_hash})
      |> subscribe_and_join(LevelChannel, "level:#{dungeon_instance.id}:#{level_instance.id}")

    on_exit(fn -> DungeonRegistry.remove(DungeonInstanceRegistry, dungeon_instance.id) end)

    {:ok, socket: socket,
          player_location: player_location,
          basic_tiles: basic_tiles,
          instance: instance,
          instance_registry: instance_registry,
          dungeon_instance_id: dungeon_instance.id,
          level_instance_id: level_instance.id}
  end

  defp _player_location_north(player_location) do
    %{level_instance_id: player_location.tile.level_instance_id, row: player_location.tile.row-1, col: player_location.tile.col}
  end

  test "with the wrong player", %{dungeon_instance_id: dungeon_instance_id,
                                  level_instance_id: level_instance_id} do
    bad_user = insert_user(%{is_admin: false, user_id_hash: "hackerman"})

    assert {:error, %{message: "Could not join channel"}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: bad_user.user_id_hash})
      |> subscribe_and_join(LevelChannel, "level:#{dungeon_instance_id}:#{level_instance_id}")
  end

  test "with a bad location" do
    assert {:error, %{reason: "join crashed"}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: "user_id_hash"})
      |> subscribe_and_join(LevelChannel, "level:0:0")
  end

  test "with a location with bad tile", %{instance: instance,
                                          player_location: player_location,
                                          dungeon_instance_id: dungeon_instance_id,
                                          level_instance_id: level_instance_id} do
    LevelProcess.run_with(instance, fn (instance_state) ->
      {_, state} = Levels.delete_tile(instance_state, player_location.tile)
      {:ok, state}
    end)

    assert {:error, %{message: "Could not join channel"}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: player_location.user_id_hash})
      |> subscribe_and_join(LevelChannel, "level:#{dungeon_instance_id}:#{level_instance_id}")
  end

  test "shout broadcasts to dungeon:lobby", %{socket: socket} do
    push socket, "shout", %{"hello" => "all"}
    assert_broadcast "shout", %{"hello" => "all"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from! socket, "broadcast", %{"some" => "data"}
    assert_push "broadcast", %{"some" => "data"}
  end

  @tag torches: 1
  test "light_torch", %{instance: instance, socket: socket, player_location: player_location} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    push socket, "light_torch", %{}

    assert_receive %Phoenix.Socket.Broadcast{
      topic: ^player_channel,
      event: "message",
      payload: %{message: "Don't need a torch here"}}

    LevelProcess.run_with(instance, fn (instance_state) ->
      player_tile = Levels.get_tile_by_id(instance_state, %{id: player_location.tile_instance_id})
      assert player_tile.parsed_state[:torches] == 1
      assert player_tile.parsed_state[:torch_light] == nil
      {:ok, %{ instance_state | state_values: Map.put(instance_state.state_values, :visibility, "dark")}}
    end)

    # Only lights a torch in the dark provided player has one
    push socket, "light_torch", %{}

    assert_receive %Phoenix.Socket.Broadcast{}

    LevelProcess.run_with(instance, fn (instance_state) ->
      player_tile = Levels.get_tile_by_id(instance_state, %{id: player_location.tile_instance_id})
      assert player_tile.parsed_state[:torches] == 0
      assert player_tile.parsed_state[:torch_light] == 6
      {:ok, instance_state}
    end)

    # no more torches to light
    push socket, "light_torch", %{}

    assert_receive %Phoenix.Socket.Broadcast{
      topic: ^player_channel,
      event: "message",
      payload: %{message: "Don't have any torches"}}
  end

  @tag up_tile: "."
  test "move replies with status ok", %{socket: socket} do
    ref = push socket, "move", %{"direction" => "up"}
    assert_reply ref, :ok, %{}
  end

  # move itself does not broadcast anymore, but the broadcast is sent from the instance_process for tiles that have changed since
  # the last cycle
  @tag up_tile: "."
  test "move broadcasts a tile_update if its a valid move", %{socket: socket} do
    push socket, "move", %{"direction" => "up"}
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, row: 2, rendering: "<div>@</div>"}, %{col: 1, row: 3, rendering: "<div>.</div>"}]}
  end

  @tag up_tile: "."
  test "move broadcasts a tile_update if its a valid move at the edge", %{socket: socket, player_location: player_location, instance: instance} do
    LevelProcess.run_with(instance, fn (instance_state) ->
      player_tile = Levels.get_tile_by_id(instance_state, %{id: player_location.tile_instance_id})
      instance_state = %{instance_state | adjacent_level_ids: %{"north" => instance_state.instance_id}}
      Levels.update_tile(instance_state, player_tile, %{row: 0})
    end)

    push socket, "move", %{"direction" => "up"}
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, rendering: "<div> </div>", row: 0},
                                               %{col: 1, rendering: "<div>.</div>", row: 3},
                                               %{col: 1, rendering: "<div>@</div>", row: 19}]}
  end

  @tag up_tile: ".", health: 0
  test "move broadcasts nothing if player is dead", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, player_location.tile.level_instance_id)
    north_tile = LevelProcess.get_tile(instance, player_location.tile.row, player_location.tile.col, "north")
    push socket, "move", %{"direction" => "up"}
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
    refute_broadcast "tile_changes", _anything
  end

  @tag up_tile: ".", gameover: true
  test "move does nothing if gameover for player", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, player_location.tile.level_instance_id)
    north_tile = LevelProcess.get_tile(instance, player_location.tile.row, player_location.tile.col, "north")
    push socket, "move", %{"direction" => "up"}
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
    refute_broadcast "tile_changes", _anything
  end

  @tag up_tile: "."
  test "move broadcasts a tile_update if its a valid move when starting location only had the tile that moved", %{socket: socket, instance_registry: instance_registry} do
    tile = Repo.get_by(DungeonInstances.Tile, %{row: @player_row, col: @player_col, z_index: 0})
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, tile.level_instance_id)
    LevelProcess.delete_tile(instance, tile.id)
    push socket, "move", %{"direction" => "up"}
    assert_broadcast "tile_changes", %{tiles: [%{col: 1, row: 2, rendering: "<div>@</div>"}, %{col: 1, row: 3, rendering: "<div> </div>"}]}
  end

  @tag up_tile: "."
  test "move clears the message_actions for that player", %{socket: socket, player_location: player_location, instance: instance} do
    LevelProcess.run_with(instance, fn (instance_state) ->
      instance_state = Levels.set_message_actions(instance_state, player_location.tile_instance_id, ["messaged"])
      {:ok, instance_state}
    end)
    push socket, "move", %{"direction" => "up"}
    LevelProcess.run_with(instance, fn (instance_state) ->
      refute Map.has_key?(instance_state, player_location.tile_instance_id)
      {:ok, instance_state}
    end)
  end

  @tag up_tile: "#"
  test "move broadcasts refresh of the player if its not a valid move", %{socket: socket, player_location: player_location} do
    push socket, "move", %{"direction" => "up"}
    col = player_location.tile.col
    row = player_location.tile.row
    assert_broadcast "tile_changes", %{tiles: [%{col: ^col, rendering: "<div>@</div>", row: ^row}]}
  end

  @tag up_tile: "#"
  test "move broadcasts nothing if there is no destination tile", %{socket: socket, instance: instance} do
    LevelProcess.run_with(instance, fn (instance_state) ->
      wall_tile = Levels.get_tile(instance_state, %{row: 2, col: 1})
      {_, state} = Levels.delete_tile(instance_state, wall_tile)
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
    LevelProcess.run_with(instance, fn (instance_state) ->
      instance_state = Levels.set_message_actions(instance_state, player_location.tile_instance_id, ["messaged"])
      {:ok, message_object} = DungeonInstances.new_tile(%{level_instance_id: instance_state.instance_id,
                                                          row: @player_row,
                                                          col: @player_col+1,
                                                          script: """
                                                                  #END
                                                                  :touch
                                                                  :messaged
                                                                  oh hai mark
                                                                  """})

      Levels.create_tile(instance_state, message_object)
    end)

    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "message_action", %{"label" => "messaged", "tile_id" => message_object.id}

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "oh hai mark"}}

    LevelProcess.run_with(instance, fn (instance_state) ->
      refute Map.has_key?(instance_state, player_location.tile_instance_id)
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
    assert_broadcast "message", %{message: "Out of ammo!"}
  end

  @tag up_tile: "."
  test "does not let the player shoot if dungeon to pacifism", %{socket: socket,
                                                                 player_location: player_location,
                                                                 instance_registry: instance_registry} do
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, player_location.tile.level_instance_id)
    LevelProcess.set_state_values(instance, %{pacifism: true})
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "tile_changes", %{tiles: [%{col: 1, rendering: "<div>◦</div>", row: 2}] }
    assert_broadcast "message", %{message: "Can't shoot here!"}
  end

  test "sends a message if the item does not exist", %{socket: socket,
                                                       player_location: player_location,
                                                       instance: instance} do
    LevelProcess.run_with(instance, fn (instance_state) ->
      Levels.update_tile_state(instance_state, %{id: player_location.tile_instance_id}, %{equipped: "missingo"})
    end)
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "tile_changes", %{tiles: [%{col: 1, rendering: "<div>◦</div>", row: 2}] }
    assert_broadcast "message", %{message: "Error: item 'missingo' not found"}
  end

  test "sends a message when nothing equipped", %{socket: socket,
                                                  player_location: player_location,
                                                  instance: instance} do
    LevelProcess.run_with(instance, fn (instance_state) ->
      Levels.update_tile_state(instance_state, %{id: player_location.tile_instance_id}, %{equipped: nil})
    end)
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "tile_changes", %{tiles: [%{col: 1, rendering: "<div>◦</div>", row: 2}] }
    assert_broadcast "message", %{message: "You have nothing equipped"}

    LevelProcess.run_with(instance, fn (instance_state) ->
      Levels.update_tile_state(instance_state, %{id: player_location.tile_instance_id}, %{equipped: ""})
    end)
    push socket, "shoot", %{"direction" => "up"}
    refute_broadcast "tile_changes", %{tiles: [%{col: 1, rendering: "<div>◦</div>", row: 2}] }
    assert_broadcast "message", %{message: "You have nothing equipped"}
  end

  @tag up_tile: ".", health: 0
  test "does not let the player shoot if dead", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, player_location.tile.level_instance_id)
    north_tile = LevelProcess.get_tile(instance, player_location.tile.row, player_location.tile.col, "north")
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
    refute_broadcast "tile_changes", _anything
    refute_broadcast "message", _anything
  end

  @tag up_tile: ".", gameover: true
  test "does not let the player shoot if gameover", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, player_location.tile.level_instance_id)
    north_tile = LevelProcess.get_tile(instance, player_location.tile.row, player_location.tile.col, "north")
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    push socket, "shoot", %{"direction" => "up"}
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
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
    refute_broadcast "tile_changes", %{payload: %{tiles: [%{col: _, rendering: "<div>◦</div>", row: _}]}}
  end

  @tag up_tile: ".", ammo: 1
  test "shoot clears the message_actions for that player", %{socket: socket, player_location: player_location, instance: instance} do
    LevelProcess.run_with(instance, fn (instance_state) ->
      instance_state = Levels.set_message_actions(instance_state, player_location.tile_instance_id, ["messaged"])
      {:ok, instance_state}
    end)
    push socket, "shoot", %{"direction" => "up"}
    LevelProcess.run_with(instance, fn (instance_state) ->
      refute Map.has_key?(instance_state, player_location.tile_instance_id)
      {:ok, instance_state}
    end)
  end

  @tag up_tile: "."
  test "speak broadcasts to other players that can hear", %{socket: socket, player_location: player_location, instance: instance, instance_registry: instance_registry} do
    # setup
    other_player_location = \
    LevelProcess.run_with(instance, fn (instance_state) ->
      other_player_location = insert_player_location(%{level_instance_id: instance_state.instance_id,
                                                       row: @player_row-2,
                                                       col: @player_col,
                                                       user_id_hash: "samelvlhash"})

      other_player_tile = Repo.preload(other_player_location, :tile).tile
      {_, state} = Levels.create_player_tile(instance_state, other_player_tile, other_player_location)
      {other_player_location, state}
    end)

    other_level_instance = Enum.sort(Repo.preload(player_location, [tile: [level: [dungeon: :levels]]]).tile.level.dungeon.levels,
                                     fn(a,b) -> a.number < b.number end)
                           |> Enum.at(1)


    {:ok, other_instance} = LevelRegistry.lookup_or_create(instance_registry, other_level_instance.id)
    other_level_pl = \
    LevelProcess.run_with(other_instance, fn (instance_state) ->
      other_level_pl = insert_player_location(%{level_instance_id: instance_state.instance_id, user_id_hash: "otherlvlhash"})
      Levels.create_player_tile(instance_state, Repo.preload(other_level_pl, :tile).tile, other_level_pl)
      other_player_lvl_tile = Repo.preload(other_level_pl, :tile).tile
      {_, state} = Levels.create_player_tile(instance_state, other_player_lvl_tile, other_level_pl)
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
    LevelProcess.run_with(instance, fn (instance_state) ->
      wall_tile = %DungeonInstances.Tile{id: "new_1",
                                         state: "blocking: true",
                                         character: "#",
                                         level_instance_id: instance_state.instance_id,
                                         row: @player_row-1,
                                         col: @player_col,
                                         z_index: 10}
      {_, state} = Levels.create_tile(instance_state, wall_tile)
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

    # /dungeon prefix messages everyone in the same dungeon instance (ie, same dungeon including different levels
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
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, player_location.tile.level_instance_id)
    north_tile = _player_location_north(player_location)

    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    assert_broadcast "tile_changes", %{tiles: [%{row: _, col: _, rendering: "<div>'</div>"}]}
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["'"].character
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col).script == basic_tiles["'"].script
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col).state == basic_tiles["'"].state

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    assert_broadcast "tile_changes", %{tiles: [%{row: _, col: _, rendering: "<div>+</div>"}]}
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["+"].character
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col).script == basic_tiles["+"].script
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col).state == basic_tiles["+"].state
  end

  @tag up_tile: "."
  test "use_door with an invalid actions", %{socket: socket, player_location: player_location, basic_tiles: basic_tiles, instance_registry: instance_registry} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    north_tile = _player_location_north(player_location)
    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, player_location.tile.level_instance_id)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "Cannot open that"}}
    refute_broadcast "tile_changes", _
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["."].character

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "Cannot close that"}}

    refute_broadcast "tile_changes", _
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col).character == basic_tiles["."].character
  end

  @tag up_tile: "+", health: 0
  test "use_door does nothing if player is dead", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, player_location.tile.level_instance_id)
    north_tile = LevelProcess.get_tile(instance, player_location.tile.row, player_location.tile.col, "north")

    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    refute_broadcast "tile_changes", _anything
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    refute_broadcast "tile_changes", _anything
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
  end

  @tag up_tile: "+", gameover: true
  test "use_door does nothing if player gameover", %{socket: socket, player_location: player_location, instance_registry: instance_registry} do
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, player_location.tile.level_instance_id)
    north_tile = LevelProcess.get_tile(instance, player_location.tile.row, player_location.tile.col, "north")

    push socket, "use_door", %{"direction" => "up", "action" => "OPEN"}

    refute_broadcast "tile_changes", _anything
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile

    push socket, "use_door", %{"direction" => "up", "action" => "CLOSE"}

    refute_broadcast "tile_changes", _anything
    assert LevelProcess.get_tile(instance, north_tile.row, north_tile.col) == north_tile
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

    LevelProcess.run_with(instance, fn (%{inactive_players: inactive_players} = instance_state) ->
      assert inactive_players[player_location.tile_instance_id]
      {:ok, instance_state}
    end)
  end
end
