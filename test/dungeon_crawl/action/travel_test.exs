defmodule DungeonCrawl.Action.TravelTest do
  use DungeonCrawl.DataCase
  use AssertEventually, timeout: 50, interval: 5

  alias DungeonCrawl.Action.Travel
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.Registrar

  setup config do
    level_1_tiles = [%Tile{name: "Stairs", character: ">", row: 6, col: 9, z_index: 0, state: %{blocking: false}}]
    level_2_tiles = [%Tile{name: "Floor", character: ".", row: 1, col: 1, z_index: 0, state: %{blocking: false}}]
    dungeon_instance = insert_stubbed_dungeon_instance(%{autogenerated: !!config[:autogenerated], headers_only: false},#true},
                                                       %{height: 20, width: 20},
                                                       [ level_1_tiles, level_2_tiles ])
                       |> Repo.preload(:levels)
    [level_1, level_2] = Enum.sort(dungeon_instance.levels, fn(a,b) -> a.number < b.number end)
    Dungeons.add_spawn_locations(level_2.level_id, [{1, 5}])
    player_location = insert_player_location(%{level_instance_id: level_1.id})
    {:ok, instance_registry} = Registrar.instance_registry(dungeon_instance.id)
    {:ok, {_, instance_1}} = LevelRegistry.lookup_or_create(instance_registry, level_1.number, nil)
    {:ok, {_, _instance_2}} = LevelRegistry.lookup_or_create(instance_registry, level_2.number, nil)
    LevelProcess.run_with(instance_1, fn (state) ->
      {_player_tile, state} = Levels.create_player_tile(state, Repo.preload(player_location, :tile).tile, player_location)
      {:ok, %{ state | passage_exits: [{Levels.get_tile(state, %{row: 6, col: 9, fade_overlay: "on"}).id,"red"}] }}
    end)

    %{player_location: player_location, level_1: level_1, level_2: level_2, instance_registry: instance_registry}
  end

  test "passage/4 same instance or level", %{player_location: player_location, level_1: level_1, instance_registry: instance_registry} do
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    # travel to floor 1 from floor 1 takes player tile to a spawn coordinate
    {:ok, {_, instance_1}} = LevelRegistry.lookup_or_create(instance_registry, level_1.number, player_location.id)
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
    {:ok, {_, instance_1}} = LevelRegistry.lookup_or_create(instance_registry, level_1.number, player_location.id)
    LevelProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{match_key: "red"}, 2, state)
      refute Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    level_2_id = level_2.id
    level_2_number = level_2.number
    level_2_owner_id = level_2.player_location_id
    {:ok, {_, instance_2}} = LevelRegistry.lookup_or_create(instance_registry, level_2.number, level_2_owner_id)

    LevelProcess.run_with(instance_2, fn (state) ->
      eventually assert %{row: 1, col: 5, level_instance_id: ^level_2_id} = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "change_level",
        payload: %{
          level_number: ^level_2_number,
          level_owner_id: ^level_2_owner_id,
          level_render: _rendered_dungeon}}

    # Back to existing level
    level_1_id = level_1.id
    level_1_number = level_1.number
    level_1_owner_id = level_1.player_location_id
    LevelProcess.run_with(instance_2, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{match_key: "red"}, 1, state)
      refute Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)
    LevelProcess.run_with(instance_1, fn (state) ->
      eventually assert %{row: 6, col: 9, level_instance_id: ^level_1_id} = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
      topic: ^player_channel,
      event: "change_level",
      payload: %{
        level_number: ^level_1_number,
        level_owner_id: ^level_1_owner_id,
        level_render: _rendered_dungeon}}

    # When the target level only has the header, but not level instance created yet
    DungeonInstances.delete_level!(level_2)
    LevelRegistry.remove(instance_registry, level_2.number, level_2_owner_id)
    LevelProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{match_key: "red"}, 2, state)
      assert DungeonInstances.get_level(level_2.dungeon_instance_id, level_2.number)
      refute Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    {:ok, {level_2_id, instance_2}} = LevelRegistry.lookup_or_create(instance_registry, level_2.number, level_2_owner_id)
    LevelProcess.run_with(instance_2, fn (state) ->
      assert %{row: 1, col: 5, level_instance_id: ^level_2_id} = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
      topic: ^player_channel,
      event: "change_level",
      payload: %{
        level_number: ^level_2_number,
        level_owner_id: ^level_2_owner_id,
        level_render: _rendered_dungeon}}
  end

  test "passage/4 does nothing when target level does not exist", %{player_location: player_location, level_1: level_1, instance_registry: instance_registry} do
    # travel to floor 1 from floor 1 takes player tile to a spawn coordinate
    {:ok, {_, instance_1}} = LevelRegistry.lookup_or_create(instance_registry, level_1.number, player_location.id)
    LevelProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state_travelled} = Travel.passage(player_location, %{match_key: nil}, 12, state)
      assert state == state_travelled
      {:ok, state}
    end)
  end

  @tag autogenerated: true
  test "passage/4 when its autogenerated", %{player_location: player_location,
                                               level_1: level_1,
                                               level_2: level_2,
                                               instance_registry: instance_registry} do
    assert DungeonInstances.get_level(level_1.dungeon_instance_id, level_1.number)
    refute DungeonInstances.get_level(level_2.dungeon_instance_id, level_2.number + 1)
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    # travel to floor 1 from floor 1 takes player tile to a spawn coordinate
    {:ok, {_, instance_1}} = LevelRegistry.lookup_or_create(instance_registry, level_1.number, player_location.id)
    LevelProcess.run_with(instance_1, fn (state) ->
      assert {:ok, state} = Travel.passage(player_location, %{match_key: "stairs_down"}, 2, state)
      {:ok, state}
    end)

    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "message",
        payload: %{message: "*** Now on level 2"}}

    level_2_number = level_2.number
    level_2_owner_id = level_2.player_location_id
    assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "change_level",
        payload: %{
          level_number: ^level_2_number,
          level_owner_id: ^level_2_owner_id,
          level_render: _rendered_dungeon,
          fade_overlay: fade_overlay}}

    refute fade_overlay == ""

    refute DungeonInstances.get_level(level_1.dungeon_instance_id, level_1.number)
    assert DungeonInstances.get_level(level_2.dungeon_instance_id, level_2.number + 1)
  end
end

