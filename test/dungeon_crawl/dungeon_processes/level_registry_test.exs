defmodule DungeonCrawl.LevelRegistryTest do
  use DungeonCrawl.DataCase
  use AssertEventually, timeout: 10, interval: 1

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances.{Level, Tile}
  alias DungeonCrawl.DungeonProcesses.{LevelRegistry,LevelProcess,Levels}
  alias DungeonCrawl.Scripting.{Parser,Program}

  setup do
    instance_registry = start_supervised!(%{
      id: TestInstanceRegistry,
      start: {LevelRegistry, :start_link, [nil, []]}
    })
    %{instance_registry: instance_registry}
  end

  test "set_dungeon_instance_id", %{instance_registry: instance_registry} do
    assert %{dungeon_instance_id: nil} = :sys.get_state(instance_registry)
    LevelRegistry.set_dungeon_instance_id(instance_registry, 2048)
    assert %{dungeon_instance_id: 2048} = :sys.get_state(instance_registry)
  end

  test "lookup universal instance", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)

    assert :error = LevelRegistry.lookup(instance_registry, instance.number, nil)
    assert :error = LevelRegistry.lookup(instance_registry, instance.number, 1)

    LevelRegistry.create(instance_registry, instance.number, 1)

    assert {:ok, {_instance_id, _instance_pid}} = LevelRegistry.lookup(instance_registry, instance.number, nil)
    assert {:ok, {_instance_id, _instance_pid}} = LevelRegistry.lookup(instance_registry, instance.number, 1)
  end

  test "lookup solo instance", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance(%{state: %{"solo" => true}})
    location = insert_player_location(%{level_instance_id: instance.id, user_id_hash: "testhash"})
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)

    assert :error = LevelRegistry.lookup(instance_registry, instance.number, nil)
    assert :error = LevelRegistry.lookup(instance_registry, instance.number, location.id)

    LevelRegistry.create(instance_registry, instance.number, location.id)

    assert :error = LevelRegistry.lookup(instance_registry, instance.number, nil)
    assert :error = LevelRegistry.lookup(instance_registry, instance.number, 1)
    assert {:ok, {_instance_id, _instance_pid}} = LevelRegistry.lookup(instance_registry, instance.number, location.id)
  end

  test "lookup_or_create universal instance", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)
    Dungeons.set_spawn_locations(instance.level_id, [{1,1}])

    assert {:ok, instance_id_and_process} = LevelRegistry.lookup_or_create(instance_registry, instance.number, 1)
    # Finds the already existing one
    assert {:ok, instance_id_and_process} == LevelRegistry.lookup_or_create(instance_registry, instance.number, 1)
    assert {:ok, instance_id_and_process} == LevelRegistry.lookup_or_create(instance_registry, instance.number, nil)
  end

  test "lookup_or_create solo instance", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance(%{state: %{"solo" => true}})
    location = insert_player_location(%{level_instance_id: instance.id, user_id_hash: "testhash"})
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)
    Dungeons.set_spawn_locations(instance.level_id, [{1,1}])

    assert {:ok, instance_id_and_process} = LevelRegistry.lookup_or_create(instance_registry, instance.number, location.id)
    # Finds the already existing one
    assert {:ok, instance_id_and_process} == LevelRegistry.lookup_or_create(instance_registry, instance.number, location.id)
    assert {:ok, instance_id_and_process} != LevelRegistry.lookup_or_create(instance_registry, instance.number, nil)
  end

  test "create/2", %{instance_registry: instance_registry} do
    user = insert_user()
    button_tile = insert_tile_template(%{state: %{"blocking" => true}, script: "#END\n:TOUCH\n*PimPom*"})
    instance = insert_stubbed_level_instance(%{state: %{"flag" => false}},
      [Map.merge(%{row: 1, col: 2, tile_template_id: button_tile.id, z_index: 0},
                 Map.take(button_tile, [:character,:color,:background_color,:state,:script])),
       %{row: 9, col: 10, name: "Floor", tile_template_id: nil, z_index: 0, character: ".", color: nil, background_color: nil, state: %{}, script: ""}])
    instance = Level.changeset(instance, %{number_north: instance.number}) |> Repo.update!

    location = insert_player_location(%{level_instance_id: instance.id, row: 1, user_id_hash: "itsmehash"})
    tile = Repo.get_by(Tile, %{level_instance_id: instance.id, row: 1, col: 2})
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)

    Repo.preload(instance, [dungeon: :dungeon]).dungeon.dungeon
    |> Dungeons.update_dungeon(%{user_id: user.id})

    assert :ok = LevelRegistry.create(instance_registry, instance.number, nil)
    assert reg_state = :sys.get_state(instance_registry)
    assert :ok = LevelRegistry.create(instance_registry, instance.number, nil)
    assert reg_state == :sys.get_state(instance_registry)

    assert {:ok, {_instance_id, instance_process}} = LevelRegistry.lookup(instance_registry, instance.number, 1)

    # the instance level is loaded
    assert %Levels{program_contexts: programs,
                   map_by_ids: map_by_ids,
                   state_values: state_values,
                   instance_id: instance_id,
                   player_locations: player_locations,
                   spawn_coordinates: spawn_coordinates,
                   adjacent_level_numbers: adjacent_level_numbers,
                   author: author} = LevelProcess.get_state(instance_process)
    assert programs == %{tile.id => %{
                                       object_id: tile.id,
                                       program: %Program{broadcasts: [],
                                                         instructions: %{1 => [:halt, [""]],
                                                                         2 => [:noop, "TOUCH"],
                                                                         3 => [:text, [["*PimPom*"]]]},
                                                         labels: %{"touch" => [[2, true]]},
                                                         locked: false,
                                                         pc: 0,
                                                         responses: [],
                                                         status: :idle,
                                                         wait_cycles: 0
                                                },
                                      event_sender: nil
                                    }
                       }
    assert player_locations == %{location.tile_instance_id => location}
    assert map_by_ids[tile.id] == Map.put(tile, :state, %{"blocking" => true})
    assert state_values == %{"flag" => false, "cols" => 20, "rows" => 20}
    assert spawn_coordinates == [{9, 10}]
    assert instance_id == instance.id
    assert adjacent_level_numbers == %{"east" => nil, "north" => instance.number, "south" => nil, "west" => nil}
    assert Map.take(author, [:id, :name, :is_admin]) == Map.take(user, [:id, :name, :is_admin])
  end

  test "create/2 when program contexts exist in the DB", %{instance_registry: instance_registry} do
    user = insert_user()
    button_tile = insert_tile_template(%{state: %{"blocking" => true}, script: "#END\n:TOUCH\n*PimPom*"})
    instance = insert_stubbed_level_instance(%{state: %{"flag" => false}},
      [Map.merge(%{row: 1, col: 2, tile_template_id: button_tile.id, z_index: 0},
        Map.take(button_tile, [:character,:color,:background_color,:state,:script])),
        %{row: 9, col: 10, name: "Floor", tile_template_id: nil, z_index: 0, character: ".", color: nil, background_color: nil, state: %{}, script: ""}])
    tile = Repo.get_by(Tile, %{level_instance_id: instance.id, row: 1, col: 2})
    {:ok, alt_program} = Parser.parse("#END\n:TOUCH\n*BZZZZ")
    instance = Level.changeset(instance,
                 %{
                   number_north: instance.number,
                   program_contexts: %{tile.id => %{program: alt_program, event_sender: %{tile_id: 456}, object_id: tile.id}},
                   passage_exits: [{123, "Puce"}]
                 }
               )
               |> Repo.update!

    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)
    Repo.preload(instance, [dungeon: :dungeon]).dungeon.dungeon
    |> Dungeons.update_dungeon(%{user_id: user.id})

    assert :ok = LevelRegistry.create(instance_registry, instance.number, nil)

    assert {:ok, {_instance_id, instance_process}} = LevelRegistry.lookup(instance_registry, instance.number, 1)

    # the instance level is loaded
    assert %Levels{program_contexts: programs, passage_exits: passage_exits} = LevelProcess.get_state(instance_process)
    assert programs == %{tile.id => %{
             object_id: tile.id,
             program: %Program{broadcasts: [],
               instructions: %{1 => [:halt, [""]],
                 2 => [:noop, "TOUCH"],
                 3 => [:text, [["*BZZZZ"]]]},
               labels: %{"touch" => [[2, true]]},
               locked: false,
               pc: 0,
               responses: [],
               status: :idle,
               wait_cycles: 0
             },
             event_sender: %{tile_id: 456}
           }
         }
    assert passage_exits == [{123, "Puce"}]
  end

  test "create/2 when a solo instance", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance(%{state: %{"solo" => true}})
    location = insert_player_location(%{level_instance_id: instance.id, row: 1, user_id_hash: "itsmehash"})
    instance = %{instance | player_location_id: location.id}

    assert :ok = LevelRegistry.create(instance_registry, instance)
    assert reg_state = :sys.get_state(instance_registry)
    assert :ok = LevelRegistry.create(instance_registry, instance)
    assert reg_state == :sys.get_state(instance_registry)

    assert :error = LevelRegistry.lookup(instance_registry, instance.number, nil)
    assert {:ok, {_instance_id, _instance_pid}} = LevelRegistry.lookup(instance_registry, instance.number, location.id)
  end

  test "create/3..9", %{instance_registry: instance_registry} do
    level_number = 1
    author = %{is_admin: false, id: 12345}
    tile = %Tile{id: 999, level_instance_id: 12345, row: 1, col: 2, z_index: 0, character: "B", state: %{}, script: ""}

    tiles = [tile]

    assert tile.level_instance_id ==
             LevelRegistry.create(instance_registry, nil, tile.level_instance_id, tiles, [], %{"flag" => false}, nil, level_number, %{}, author)
    assert reg_state = :sys.get_state(instance_registry)
    assert :exists ==
             LevelRegistry.create(instance_registry, nil, tile.level_instance_id, tiles, [], %{"flag" => false}, nil, level_number, %{}, author)
    assert reg_state == :sys.get_state(instance_registry)

    assert {:ok, {_instance_id, instance_process}} = LevelRegistry.lookup(instance_registry, level_number, 1)

    # the instance level is loaded
    assert %Levels{program_contexts: programs,
                   map_by_ids: by_ids,
                   map_by_coords: by_coords,
                   state_values: %{"flag" => false},
                   author: ^author} = LevelProcess.get_state(instance_process)
    assert by_ids == %{tile.id => Map.put(tile, :state, %{})}
    assert by_coords ==  %{ {tile.row, tile.col} => %{tile.z_index => tile.id} }
    assert programs == %{}

    # if no instance_id is given, it gets an available id and returns it
    # if no state values are given, defaults to empty level
    assert instance_id = LevelRegistry.create(instance_registry, nil, nil, tiles)
    refute instance_id == tile.level_instance_id
    assert {:ok, {instance_id2, instance_process2}} = LevelRegistry.lookup(instance_registry, level_number, 1)
    assert %Levels{program_contexts: _programs,
                   map_by_ids: by_ids,
                   map_by_coords: _by_coords,
                   state_values: %{}} = LevelProcess.get_state(instance_process2)
    assert by_ids == %{tile.id => Map.merge(tile, %{level_instance_id: instance_id2, state: %{}})}
  end

  @tag capture_log: true
  test "create safely handles a dungeon instance that does not exist in the DB", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)
    DungeonCrawl.Dungeons.delete_level!(Repo.preload(instance, :level).level)
    log = ExUnit.CaptureLog.capture_log(fn -> LevelRegistry.create(instance_registry, instance.number, nil); :timer.sleep 2 end)
    assert :error = LevelRegistry.lookup(instance_registry, instance.id, 1)
    assert log =~ "Got a CREATE cast for DungeonInstance #{instance.dungeon_instance_id} LevelNumber #{instance.number} but no header matched"
   end

  test "remove", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)
    LevelRegistry.create(instance_registry, instance.number, nil)
    assert {:ok, _instance_id_and_process} = LevelRegistry.lookup(instance_registry, instance.number, 1)

    # seems to take a quick micro second for the cast to be done
    LevelRegistry.remove(instance_registry, instance.number, nil)

    eventually assert :error = LevelRegistry.lookup(instance_registry, instance.number, 1)
  end

  test "removes instances on exit", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)
    LevelRegistry.create(instance_registry, instance.number, nil)
    assert {:ok, {_instance_id, instance_process}} = LevelRegistry.lookup(instance_registry, instance.number, 1)

    GenServer.stop(instance_process)
    assert :error = LevelRegistry.lookup(instance_registry, instance.number, 1)
  end

  test "removes instance on crash", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)
    LevelRegistry.create(instance_registry, instance.number, nil)
    assert {:ok, {_instance_id, instance_process}} = LevelRegistry.lookup(instance_registry, instance.number, 1)

    # Stop the bucket with a non-normal reason
    GenServer.stop(instance_process, :shutdown)
    assert :error = LevelRegistry.lookup(instance_registry, instance.number, 1)
  end

  test "list", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)
    instance_id = instance.id
    instance_number = instance.number
    LevelRegistry.create(instance_registry, instance.number, nil)

    assert instance_ids = LevelRegistry.list(instance_registry)
    assert %{^instance_number => %{nil => {^instance_id, _pid}}} = instance_ids
    assert length(Map.keys(instance_ids)) == 1
  end

  test "flat_list", %{instance_registry: instance_registry} do
    instance = insert_stubbed_level_instance()
    LevelRegistry.set_dungeon_instance_id(instance_registry, instance.dungeon_instance_id)
    instance_id = instance.id
    LevelRegistry.create(instance_registry, instance.number, nil)

    assert instance_ids = LevelRegistry.flat_list(instance_registry)
    assert [{^instance_id, _pid}] = instance_ids
    assert length(instance_ids) == 1
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

      {:ok, {instance_id_1, instance_process_1}} = LevelRegistry.lookup(instance_registry, level_1.number, 1)
      {:ok, {instance_id_2, instance_process_2}} = LevelRegistry.lookup(instance_registry, level_2.number, 1)

      assert Process.alive?(instance_registry)
      assert Process.alive?(instance_process_1)
      assert Process.alive?(instance_process_2)
      assert level_1.id == instance_id_1
      assert level_2.id == instance_id_2

      GenServer.stop(instance_registry, :shutdown)

      eventually refute Process.alive?(instance_registry)
      eventually refute Process.alive?(instance_process_1)
      eventually refute Process.alive?(instance_process_2)
  end
end
