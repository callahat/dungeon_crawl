defmodule DungeonCrawl.Action.TravelTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Travel
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry

  setup do
    level_1_tiles = [%MapTile{name: "Stairs", character: ">", row: 6, col: 9, z_index: 0, state: "blocking: false"}]
    map_set_instance = insert_stubbed_map_set_instance(%{}, %{height: 20, width: 20}, [ level_1_tiles, [] ])
                       |> Repo.preload(:maps)
    [level_1, level_2] = Enum.sort(map_set_instance.maps, fn(a,b) -> a.number < b.number end)
    player_location = insert_player_location(%{map_instance_id: level_1.id})
    {:ok, instance_1} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, level_1.id)
    {:ok, instance_2} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, level_2.id)
    InstanceProcess.run_with(instance_1, fn (state) ->
      {_player_map_tile, state} = Instances.create_player_map_tile(state, Repo.preload(player_location, :map_tile).map_tile, player_location)
      {:ok, %{ state | passage_exits: [{Instances.get_map_tile(state, %{row: 6, col: 9}).id,"red"}] }}
    end)
    InstanceProcess.run_with(instance_2, fn (state) ->
      {:ok, %{ state | spawn_coordinates: [{1,5}] }}
    end)

    %{player_location: player_location, level_1: level_1, level_2: level_2}
  end

  test "passage/4 same instance or level", %{player_location: player_location, level_1: level_1, level_2: level_2} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    dungeon_1_channel = "dungeons:#{level_1.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_1_channel)
    dungeon_2_channel = "dungeons:#{level_2.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_2_channel)

    # travel to floor 1 from floor 1 takes player map tile to a spawn coordinate
    {:ok, instance_1} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, level_1.id)
    InstanceProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{match_key: nil}, 1, state)
      level_1_id = level_1.id
      assert %{row: 6, col: 9, map_instance_id: ^level_1_id} = Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dungeon_1_channel,
        event: "tile_changes",
        payload: %{tiles: [%{col: 1, rendering: "<div> </div>", row: 3}]}}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dungeon_1_channel,
        event: "tile_changes",
        payload: %{tiles: [%{col: 9, rendering: "<div>@</div>", row: 6}]}}
    refute_receive %Phoenix.Socket.Broadcast{topic: ^dungeon_2_channel}
    refute_receive %Phoenix.Socket.Broadcast{topic: ^player_channel}
  end

  test "passage/4 different instance or level", %{player_location: player_location, level_1: level_1, level_2: level_2} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    dungeon_1_channel = "dungeons:#{level_1.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_1_channel)
    dungeon_2_channel = "dungeons:#{level_2.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_2_channel)

    # travel to floor 1 from floor 1 takes player map tile to a spawn coordinate
    {:ok, instance_1} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, level_1.id)
    InstanceProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{match_key: "red"}, 2, state)
      refute Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})
      {:ok, state}
    end)

    level_2_id = level_2.id
    {:ok, instance_2} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, level_2.id)
    InstanceProcess.run_with(instance_2, fn (state) ->
      assert %{row: 1, col: 5, map_instance_id: ^level_2_id} = Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dungeon_1_channel,
        event: "tile_changes",
        payload: %{tiles: [%{col: 1, rendering: "<div> </div>", row: 3}]}}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dungeon_2_channel,
        event: "tile_changes",
        payload: %{tiles: [%{col: 5, rendering: "<div>@</div>", row: 1}]}}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "change_dungeon",
        payload: %{dungeon_id: ^level_2_id, dungeon_render: _rendered_dungeon}}
  end

  test "passage/4 does nothing when target level does not exist", %{player_location: player_location, level_1: level_1} do
    # travel to floor 1 from floor 1 takes player map tile to a spawn coordinate
    {:ok, instance_1} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, level_1.id)
    InstanceProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state_travelled} = Travel.passage(player_location, %{match_key: nil}, 12, state)
      assert state == state_travelled
      {:ok, state}
    end)
  end

  test "passage/3 same instance or level", %{player_location: player_location, level_1: level_1, level_2: level_2} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    dungeon_1_channel = "dungeons:#{level_1.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_1_channel)
    dungeon_2_channel = "dungeons:#{level_2.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_2_channel)

    # travel to floor 1 from floor 1 takes player map tile to a spawn coordinate
    {:ok, instance_1} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, level_1.id)
    InstanceProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{adjacent_map_id: level_1.id, edge: "south"}, state)
      level_1_id = level_1.id
      assert %{row: 19, col: 1, map_instance_id: ^level_1_id} = Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dungeon_1_channel,
        event: "tile_changes",
        payload: %{tiles: [%{col: 1, rendering: "<div> </div>", row: 3}]}}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dungeon_1_channel,
        event: "tile_changes",
        payload: %{tiles: [%{col: 1, rendering: "<div>@</div>", row: 19}]}}
    refute_receive %Phoenix.Socket.Broadcast{topic: ^dungeon_2_channel}
    refute_receive %Phoenix.Socket.Broadcast{topic: ^player_channel}
  end

  test "passage/3 different instance or level", %{player_location: player_location, level_1: level_1, level_2: level_2} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    dungeon_1_channel = "dungeons:#{level_1.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_1_channel)
    dungeon_2_channel = "dungeons:#{level_2.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_2_channel)

    # travel to floor 1 from floor 1 takes player map tile to a spawn coordinate
    {:ok, instance_1} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, level_1.id)
    InstanceProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{adjacent_map_id: level_2.id, edge: "west"}, state)
      refute Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})
      {:ok, state}
    end)

    level_2_id = level_2.id
    {:ok, instance_2} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, level_2.id)
    InstanceProcess.run_with(instance_2, fn (state) ->
      assert %{row: 3, col: 0, map_instance_id: ^level_2_id} = Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dungeon_1_channel,
        event: "tile_changes",
        payload: %{tiles: [%{col: 1, rendering: "<div> </div>", row: 3}]}}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dungeon_2_channel,
        event: "tile_changes",
        payload: %{tiles: [%{col: 0, rendering: "<div>@</div>", row: 3}]}}
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "change_dungeon",
        payload: %{dungeon_id: ^level_2_id, dungeon_render: _rendered_dungeon}}
  end
end

