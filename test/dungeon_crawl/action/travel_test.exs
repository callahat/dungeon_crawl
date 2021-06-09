defmodule DungeonCrawl.Action.TravelTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Travel
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.Registrar

  setup do
    level_1_tiles = [%Tile{name: "Stairs", character: ">", row: 6, col: 9, z_index: 0, state: "blocking: false"}]
    dungeon_instance = insert_stubbed_dungeon_instance(%{}, %{height: 20, width: 20}, [ level_1_tiles, [] ])
                       |> Repo.preload(:levels)
    [level_1, level_2] = Enum.sort(dungeon_instance.levels, fn(a,b) -> a.number < b.number end)
    player_location = insert_player_location(%{level_instance_id: level_1.id})
    {:ok, instance_registry} = Registrar.instance_registry(dungeon_instance.id)
    {:ok, instance_1} = LevelRegistry.lookup_or_create(instance_registry, level_1.id)
    {:ok, instance_2} = LevelRegistry.lookup_or_create(instance_registry, level_2.id)
    LevelProcess.run_with(instance_1, fn (state) ->
      {_player_tile, state} = Levels.create_player_tile(state, Repo.preload(player_location, :tile).tile, player_location)
      {:ok, %{ state | passage_exits: [{Levels.get_tile(state, %{row: 6, col: 9}).id,"red"}] }}
    end)
    LevelProcess.run_with(instance_2, fn (state) ->
      {:ok, %{ state | spawn_coordinates: [{1,5}] }}
    end)

    %{player_location: player_location, level_1: level_1, level_2: level_2, instance_registry: instance_registry}
  end

  test "passage/4 same instance or level", %{player_location: player_location, level_1: level_1, instance_registry: instance_registry} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    # travel to floor 1 from floor 1 takes player tile to a spawn coordinate
    {:ok, instance_1} = LevelRegistry.lookup_or_create(instance_registry, level_1.id)
    LevelProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{match_key: nil}, 1, state)
      level_1_id = level_1.id
      assert %{row: 6, col: 9, level_instance_id: ^level_1_id} = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    refute_receive %Phoenix.Socket.Broadcast{topic: ^player_channel}
  end

  test "passage/4 different instance or level", %{player_location: player_location, level_1: level_1, level_2: level_2, instance_registry: instance_registry} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    # travel to floor 1 from floor 1 takes player tile to a spawn coordinate
    {:ok, instance_1} = LevelRegistry.lookup_or_create(instance_registry, level_1.id)
    LevelProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{match_key: "red"}, 2, state)
      refute Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    level_2_id = level_2.id
    {:ok, instance_2} = LevelRegistry.lookup_or_create(instance_registry, level_2.id)
    LevelProcess.run_with(instance_2, fn (state) ->
      assert %{row: 1, col: 5, level_instance_id: ^level_2_id} = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "change_level",
        payload: %{level_id: ^level_2_id, level_render: _rendered_dungeon}}
  end

  test "passage/4 does nothing when target level does not exist", %{player_location: player_location, level_1: level_1, instance_registry: instance_registry} do
    # travel to floor 1 from floor 1 takes player tile to a spawn coordinate
    {:ok, instance_1} = LevelRegistry.lookup_or_create(instance_registry, level_1.id)
    LevelProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state_travelled} = Travel.passage(player_location, %{match_key: nil}, 12, state)
      assert state == state_travelled
      {:ok, state}
    end)
  end

  test "passage/3 same instance or level", %{player_location: player_location, level_1: level_1, instance_registry: instance_registry} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    # travel to floor 1 from floor 1 takes player tile to a spawn coordinate
    {:ok, instance_1} = LevelRegistry.lookup_or_create(instance_registry, level_1.id)
    LevelProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{adjacent_level_id: level_1.id, edge: "south"}, state)
      level_1_id = level_1.id
      assert %{row: 19, col: 1, level_instance_id: ^level_1_id} = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    refute_receive %Phoenix.Socket.Broadcast{topic: ^player_channel}
  end

  test "passage/3 different instance or level", %{player_location: player_location, level_1: level_1, level_2: level_2, instance_registry: instance_registry} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    # travel to floor 1 from floor 1 takes player tile to a spawn coordinate
    {:ok, instance_1} = LevelRegistry.lookup_or_create(instance_registry, level_1.id)
    LevelProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{adjacent_level_id: level_2.id, edge: "west"}, state)
      refute Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    level_2_id = level_2.id
    {:ok, instance_2} = LevelRegistry.lookup_or_create(instance_registry, level_2.id)
    LevelProcess.run_with(instance_2, fn (state) ->
      assert %{row: 3, col: 0, level_instance_id: ^level_2_id} = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "change_level",
        payload: %{level_id: ^level_2_id, level_render: _rendered_dungeon}}
  end
end

