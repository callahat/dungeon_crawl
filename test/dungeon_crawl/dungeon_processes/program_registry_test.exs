defmodule DungeonCrawl.ProgramRegistryTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.{InstanceProcess,ProgramRegistry,ProgramProcess}
  alias DungeonCrawl.Scripting.Program

  setup do
    {:ok, instance_process} = InstanceProcess.start_link([])

    map_tile = %MapTile{id: "new_1", character: "O", row: 1, col: 1, z_index: 0, script: "#END\n:TOUCH\n*PimPom*"}
    other_map_tile = %MapTile{id: "new_2", character: "x", row: 1, col: 2, z_index: 0}
    map_instance = insert_stubbed_dungeon_instance(%{}, [map_tile, other_map_tile])

    InstanceProcess.set_instance_id(instance_process, map_instance.id)
    InstanceProcess.load_map(instance_process, [map_tile, other_map_tile])
    InstanceProcess.set_state_values(instance_process, %{rows: 20, cols: 20})

    %{program_registry: program_registry} = InstanceProcess.get_state(instance_process)

    %{program_registry: program_registry, instance_process: instance_process}
  end

  test "it doesnt link the instance if already linked", %{program_registry: program_registry, instance_process: instance_process} do
    assert :exists = ProgramRegistry.link_instance(program_registry, instance_process)
  end

  test "it starts up its own Supervisor for the programs" do
    {:ok, program_registry} = ProgramRegistry.start_link([])
    assert %{ program_supervisor: program_supervisor } = ProgramRegistry.get_state(program_registry)
    assert is_pid(program_supervisor)
    assert %ProgramRegistry{ program_supervisor: ps } = ProgramRegistry.get_state(program_registry)
    assert is_pid(ps)
  end

  describe "lookup/1" do
    test "it returns the program struct given the program id", %{program_registry: program_registry} do
      assert program_process = ProgramRegistry.lookup(program_registry, "new_1")
      assert is_pid(program_process)
      assert %ProgramProcess{ program: program } = ProgramProcess.get_state(program_process)
      assert %Program{pc: 1,
                      wait_cycles: 5,
                      instructions: %{1 => [:halt, [""]],
                                      2 => [:noop, "TOUCH"],
                                      3 => [:text, ["*PimPom*"]]},
                      labels: %{"touch" => [[2, true]]},
                      status: :alive
             } = program

      refute ProgramRegistry.lookup(program_registry, "fake_id")
    end
  end

  describe "list_all_program_ids/1" do
    test "it returns a list of all program ids", %{program_registry: program_registry} do
      assert ["new_1"] == ProgramRegistry.list_all_program_ids(program_registry)
    end
  end

  describe "change_program_id/3" do
    test "changes the old id for the new one", %{program_registry: program_registry} do
      %{inverse_refs: %{ "new_1" => expected_ref },
        program_ids: %{ "new_1" => expected_process } } = ProgramRegistry.get_state(program_registry)

      assert :ok = ProgramRegistry.change_program_id(program_registry, "new_1", 1)
      assert %{ refs: %{^expected_ref => 1},
                inverse_refs: %{ 1 => ^expected_ref },
                program_ids: %{1 => ^expected_process} } = ProgramRegistry.get_state(program_registry)
    end

    test "does nothing if old program id not found", %{program_registry: program_registry} do
      expected_state = ProgramRegistry.get_state(program_registry)
      assert :ok = ProgramRegistry.change_program_id(program_registry, "goof", 1)
      assert expected_state == ProgramRegistry.get_state(program_registry)
    end
  end

  describe "start_program/2" do
    test "good program starts", %{program_registry: program_registry} do
      ProgramRegistry.start_program(program_registry, "new_2", "#become character: y")

      assert program_process = ProgramRegistry.lookup(program_registry, "new_2")
      assert %ProgramProcess{ program: program } = ProgramProcess.get_state(program_process)
      assert %Program{pc: 1,
                      wait_cycles: 5,
                      instructions: %{1 => [:become, [%{character: "y"}]]},
                      labels: %{},
                      status: :alive
             } = program
    end

    test "replaces a program if id already exists", %{program_registry: program_registry} do
      program_process = ProgramRegistry.lookup(program_registry, "new_1")
      original_program = ProgramProcess.get_state(program_process)

      ProgramRegistry.start_program(program_registry, "new_1", "#become character: y")

      assert program_process = ProgramRegistry.lookup(program_registry, "new_1")
      assert %ProgramProcess{ program: new_program } = ProgramProcess.get_state(program_process)
      assert %Program{pc: 1,
                      wait_cycles: 5,
                      instructions: %{1 => [:become, [%{character: "y"}]]},
                      labels: %{},
                      status: :alive
             } = new_program
      assert new_program.instructions != original_program.program.instructions
    end
  end

  describe "pause_all_programs/1 and resume_all_programs/1" do
    test "it pauses all programs", %{program_registry: program_registry}  do
      program_processes = ProgramRegistry.list_all_program_ids(program_registry)
                          |> Enum.map(&(ProgramRegistry.lookup(program_registry, &1)))

      ProgramRegistry.pause_all_programs(program_registry)
      :timer.sleep 1 # give the cast time to cure
      assert [{false, nil}] == program_processes
                             |> Enum.map(&(ProgramProcess.get_state(&1)))
                             |> Enum.map(fn process_state -> {process_state.active, process_state.timer_ref} end)
                             |> Enum.uniq()

      ProgramRegistry.resume_all_programs(program_registry)
      :timer.sleep 1 # give the cast time to cure
      program_processes
      |> Enum.map(&(ProgramProcess.get_state(&1)))
      |> Enum.map(fn process_state -> {process_state.active, process_state.timer_ref} end)
      |> Enum.each(fn {active, ref} ->
           assert active
           assert ref
         end)
    end
  end

  describe "stop_program/2" do
    test "stops and removes the program if it exists", %{program_registry: program_registry} do
      program_process = ProgramRegistry.lookup(program_registry, "new_1")
      prog_ref = Process.monitor(program_process)
      assert :ok = ProgramRegistry.stop_program(program_registry, "new_1")
      assert_receive {:DOWN, ^prog_ref, :process, ^program_process, :shutdown}
      refute ProgramRegistry.lookup(program_registry, "new_1")
    end

    test "does nothing if program does not exist", %{program_registry: program_registry} do
      assert :ok = ProgramRegistry.stop_program(program_registry, "fakeid")
    end
  end

  describe "stop_all_programs/1" do
    test "stops and removes the program if it exists", %{program_registry: program_registry} do
      program_process = ProgramRegistry.lookup(program_registry, "new_1")
      prog_ref = Process.monitor(program_process)
      assert :ok = ProgramRegistry.stop_all_programs(program_registry)
      assert_receive {:DOWN, ^prog_ref, :process, ^program_process, :shutdown}
      refute ProgramRegistry.lookup(program_registry, "new_1")
      assert %{ instance_process: nil } = ProgramRegistry.get_state(program_registry)
    end
  end

"""
  @tag capture_log: true
  test "create safely handles a dungeon instance that does not exist in the DB", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()
    DungeonCrawl.DungeonInstances.delete_map!(instance)
    log = ExUnit.CaptureLog.capture_log(fn -> InstanceRegistry.create(instance_registry, instance.id); :timer.sleep 2 end)
    assert :error = InstanceRegistry.lookup(instance_registry, instance.id)
    assert log =~ "Got a CREATE cast for # {instance.id} but its already been cleared"
   end

  test "remove", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()
    InstanceRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, instance.id)

    # seems to take a quick micro second for the cast to be done
    InstanceRegistry.remove(instance_registry, instance.id)
    :timer.sleep 1
    assert :error = InstanceRegistry.lookup(instance_registry, instance.id)
  end

  test "removes instances on exit", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()
    InstanceRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, instance.id)

    GenServer.stop(instance_process)
    assert :error = InstanceRegistry.lookup(instance_registry, instance.id)
  end

  test "removes instance on crash", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()
    InstanceRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, instance.id)

    # Stop the bucket with a non-normal reason
    GenServer.stop(instance_process, :shutdown)
    assert :error = InstanceRegistry.lookup(instance_registry, instance.id)
  end
"""
end
