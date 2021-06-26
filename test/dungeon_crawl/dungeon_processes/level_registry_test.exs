defmodule DungeonCrawl.LevelRegistryTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances.{Level, Tile}
  alias DungeonCrawl.DungeonProcesses.{LevelRegistry,LevelProcess,Levels}
  alias DungeonCrawl.Scripting.Program

  setup do
    instance_registry = start_supervised!(%{
      id: TestInstanceRegistry,
      start: {LevelRegistry, :start_link, [nil, []]}
    })
    %{instance_registry: instance_registry}
  end

  test "lookup", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()

    assert :error = LevelRegistry.lookup(instance_registry, instance.id)

    LevelRegistry.create(instance_registry, instance.id)

    assert {:ok, _instance_process} = LevelRegistry.lookup(instance_registry, instance.id)
  end

  test "lookup_or_create", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    Dungeons.set_spawn_locations(instance.level_id, [{1,1}])

    assert {:ok, instance_process} = LevelRegistry.lookup_or_create(instance_registry, instance.id)
    # Finds the already existing one
    assert {:ok, instance_process} == LevelRegistry.lookup_or_create(instance_registry, instance.id)
  end

  test "create/2", %{instance_registry: instance_registry} do
    user = insert_user()
    button_tile = insert_tile_template(%{state: "blocking: true", script: "#END\n:TOUCH\n*PimPom*"})
    instance = insert_stubbed_level_instance(%{state: "flag: false"},
      [Map.merge(%{row: 1, col: 2, tile_template_id: button_tile.id, z_index: 0},
                 Map.take(button_tile, [:character,:color,:background_color,:state,:script])),
       %{row: 9, col: 10, name: "Floor", tile_template_id: nil, z_index: 0, character: ".", color: nil, background_color: nil, state: "", script: ""}])
    instance = Level.changeset(instance, %{number_north: instance.number}) |> Repo.update!

    location = insert_player_location(%{level_instance_id: instance.id, row: 1, user_id_hash: "itsmehash"})
    tile = Repo.get_by(Tile, %{level_instance_id: instance.id, row: 1, col: 2})

    Repo.preload(instance, [dungeon: :dungeon]).dungeon.dungeon
    |> Dungeons.update_dungeon(%{user_id: user.id})

    assert :ok = LevelRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = LevelRegistry.lookup(instance_registry, instance.id)

    # the instance level is loaded
    assert %Levels{program_contexts: programs,
                   map_by_ids: map_by_ids,
                   state_values: state_values,
                   instance_id: instance_id,
                   player_locations: player_locations,
                   spawn_coordinates: spawn_coordinates,
                   adjacent_level_ids: adjacent_level_ids,
                   author: author} = LevelProcess.get_state(instance_process)
    assert programs == %{tile.id => %{
                                       object_id: tile.id,
                                       program: %Program{broadcasts: [],
                                                         instructions: %{1 => [:halt, [""]],
                                                                         2 => [:noop, "TOUCH"],
                                                                         3 => [:text, [["*PimPom*"]]]},
                                                         labels: %{"touch" => [[2, true]]},
                                                         locked: false,
                                                         pc: 1,
                                                         responses: [],
                                                         status: :alive,
                                                         wait_cycles: 0
                                                },
                                      event_sender: nil
                                    }
                       }
    assert player_locations == %{location.tile_instance_id => location
                                }
    assert map_by_ids[tile.id] == Map.put(tile, :parsed_state, %{blocking: true})
    assert state_values == %{flag: false, cols: 20, rows: 20}
    assert spawn_coordinates == [{9, 10}]
    assert instance_id == instance.id
    assert adjacent_level_ids == %{"east" => nil, "north" => instance.id, "south" => nil, "west" => nil}
    assert Map.take(author, [:id, :name, :is_admin]) == Map.take(user, [:id, :name, :is_admin])
  end

  test "create/3..9", %{instance_registry: instance_registry} do
    author = %{is_admin: false, id: 12345}
    tile = %{id: 999, level_instance_id: 12345, row: 1, col: 2, z_index: 0, character: "B", state: "", script: ""}

    tiles = [tile]

    assert tile.level_instance_id == LevelRegistry.create(instance_registry, tile.level_instance_id, tiles, [], %{flag: false}, nil, nil, %{}, author)
    assert {:ok, instance_process} = LevelRegistry.lookup(instance_registry, tile.level_instance_id)

    # the instance level is loaded
    assert %Levels{program_contexts: programs,
                   map_by_ids: by_ids,
                   map_by_coords: by_coords,
                   state_values: %{flag: false},
                   author: ^author} = LevelProcess.get_state(instance_process)
    assert by_ids == %{tile.id => Map.put(tile, :parsed_state, %{})}
    assert by_coords ==  %{ {tile.row, tile.col} => %{tile.z_index => tile.id} }
    assert programs == %{}

    # if no instance_id is given, it gets an available id and returns it
    # if no state values are given, defaults to empty level
    assert instance_id = LevelRegistry.create(instance_registry, nil, tiles)
    refute instance_id == tile.level_instance_id
    assert {:ok, instance_process2} = LevelRegistry.lookup(instance_registry, instance_id)
    assert %Levels{program_contexts: _programs,
                   map_by_ids: by_ids,
                   map_by_coords: _by_coords,
                   state_values: %{}} = LevelProcess.get_state(instance_process2)
    assert by_ids == %{tile.id => Map.merge(tile, %{level_instance_id: instance_id, parsed_state: %{}})}
  end

  @tag capture_log: true
  test "create safely handles a dungeon instance that does not exist in the DB", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    DungeonCrawl.DungeonInstances.delete_level!(instance)
    log = ExUnit.CaptureLog.capture_log(fn -> LevelRegistry.create(instance_registry, instance.id); :timer.sleep 2 end)
    assert :error = LevelRegistry.lookup(instance_registry, instance.id)
    assert log =~ "Got a CREATE cast for #{instance.id} but its already been cleared"
   end

  test "remove", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.create(instance_registry, instance.id)
    assert {:ok, _instance_process} = LevelRegistry.lookup(instance_registry, instance.id)

    # seems to take a quick micro second for the cast to be done
    LevelRegistry.remove(instance_registry, instance.id)
    :timer.sleep 1
    assert :error = LevelRegistry.lookup(instance_registry, instance.id)
  end

  test "removes instances on exit", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = LevelRegistry.lookup(instance_registry, instance.id)

    GenServer.stop(instance_process)
    assert :error = LevelRegistry.lookup(instance_registry, instance.id)
  end

  test "removes instance on crash", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = LevelRegistry.lookup(instance_registry, instance.id)

    # Stop the bucket with a non-normal reason
    GenServer.stop(instance_process, :shutdown)
    assert :error = LevelRegistry.lookup(instance_registry, instance.id)
  end

  test "list", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    instance_id = instance.id
    LevelRegistry.create(instance_registry, instance.id)

    assert instance_ids = LevelRegistry.list(instance_registry)
    assert %{^instance_id => _pid} = instance_ids
    assert length(Map.keys(instance_ids)) == 1
  end

  describe "player_location_ids" do
    test "no players", %{instance_registry: instance_registry} do
      assert [] == LevelRegistry.player_location_ids(instance_registry)
    end

    test "players", %{instance_registry: instance_registry} do
      dungeon_instance = insert_stubbed_dungeon_instance(%{}, %{}, [[%{character: ".", row: 1, col: 1, z_index: 0}],
                                                                    [%{character: ".", row: 1, col: 1, z_index: 0}]])

      [level_1, level_2] = DungeonCrawl.Repo.preload(dungeon_instance, :levels).levels
                           |> Enum.sort(fn a, b -> a.number < b.number end)

      p1 = insert_player_location(%{level_instance_id: level_1.id})
      p2 = insert_player_location(%{level_instance_id: level_1.id})
      p3 = insert_player_location(%{level_instance_id: level_2.id})

      LevelRegistry.create(instance_registry, level_1)
      LevelRegistry.create(instance_registry, level_2)

      assert Enum.sort(
              [{p1.id, p1.tile_instance_id, level_1.number},
               {p2.id, p2.tile_instance_id, level_1.number},
               {p3.id, p3.tile_instance_id, level_2.number}]) ==
             Enum.sort(LevelRegistry.player_location_ids(instance_registry))
    end
  end

  test "when terminated", %{instance_registry: instance_registry} do
      dungeon_instance = insert_stubbed_dungeon_instance(%{}, %{}, [[], []])

      [level_1, level_2] = DungeonCrawl.Repo.preload(dungeon_instance, :levels).levels

      LevelRegistry.create(instance_registry, level_1)
      LevelRegistry.create(instance_registry, level_2)

      {:ok, instance_process_1} = LevelRegistry.lookup(instance_registry, level_1.id)
      {:ok, instance_process_2} = LevelRegistry.lookup(instance_registry, level_2.id)

      assert Process.alive?(instance_registry)
      assert Process.alive?(instance_process_1)
      assert Process.alive?(instance_process_2)

      GenServer.stop(instance_registry, :shutdown)
      :timer.sleep 50

      refute Process.alive?(instance_registry)
      refute Process.alive?(instance_process_1)
      refute Process.alive?(instance_process_2)
  end
end
