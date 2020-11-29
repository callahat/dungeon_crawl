defmodule DungeonCrawl.ProgramProcessTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.ProgramProcess
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonInstances.MapTile

  setup do
    {:ok, instance_process} = InstanceProcess.start_link([])
    InstanceProcess.load_map(instance_process, [%MapTile{id: 1, row: 1, col: 1, character: "B"}])
    {:ok, program_process} = ProgramProcess.start_link([])

    %{instance_process: instance_process, program_process: program_process}
  end

  describe "initialize_program/4" do
    test "with a good script", %{instance_process: instance_process, program_process: program_process} do
      script = "#END\n:TOUCH\nHEY"
      assert :ok = ProgramProcess.initialize_program(program_process, instance_process, 1, script)

      assert %ProgramProcess{ program: program } = ProgramProcess.get_state(program_process)
      assert %Program{pc: 1,
                      wait_cycles: 5,
                      instructions: %{1 => [:halt, [""]],
                                      2 => [:noop, "TOUCH"],
                                      3 => [:text, ["HEY"]]},
                      labels: %{"touch" => [[2, true]]},
                      status: :alive
             } = program
    end

    test "with empty script", %{instance_process: instance_process, program_process: program_process} do
      ref = Process.monitor(program_process)

      assert :ok = ProgramProcess.initialize_program(program_process, instance_process, 1, "")

      assert_receive {:DOWN, ^ref, :process, _object, :normal}
    end

    test "with bad script", %{instance_process: instance_process, program_process: program_process} do
      ref = Process.monitor(program_process)

      assert :ok = ProgramProcess.initialize_program(program_process, instance_process, 1, "#badcommand")

      assert_receive {:DOWN, ^ref, :process, _object, :normal}
    end
  end

  describe "end_program/1" do
    test "terminates the program", %{program_process: program_process} do
      ref = Process.monitor(program_process)
      ProgramProcess.end_program(program_process)
      assert_receive {:DOWN, ^ref, :process, ^program_process, :normal}
    end
  end

  describe "get_state/1" do
    test "it gets the state", %{program_process: program_process} do
      assert %ProgramProcess{} = ProgramProcess.get_state(program_process)
    end
  end

  describe "set_state/1" do
    test "it sets the state", %{program_process: program_process} do
      initial_state = ProgramProcess.get_state(program_process)
      assert %ProgramProcess{instance_process: "not_really_valid_value"} =
        ProgramProcess.set_state(program_process, %{ initial_state | instance_process: "not_really_valid_value" })
    end
  end

  describe "responds_to_event?/2" do
    setup %{instance_process: instance_process, program_process: program_process} do
      assert :ok = ProgramProcess.initialize_program(program_process, instance_process, 1, "#END\n:TOUCH\nHEY")
      %{instance_process: instance_process, program_process: program_process}
    end

    test "when program has that label", %{program_process: program_process} do
      assert ProgramProcess.responds_to_event?(program_process, "touch")
    end

    test "when program does not have that label", %{program_process: program_process} do
      refute ProgramProcess.responds_to_event?(program_process, "eat")
    end
  end

  describe "send_event/3" do
    setup %{instance_process: instance_process, program_process: program_process} do
      assert :ok = ProgramProcess.initialize_program(program_process, instance_process, 1, "#END\n:TOUCH\nHEY\n/s")
      %{instance_process: instance_process, program_process: program_process}
    end

    test "when program has that label it changes the pc", %{program_process: program_process} do
      ProgramProcess.send_event(program_process, "touch", %{})
      assert %{program: %Program{pc: 4, status: :alive}} = ProgramProcess.get_state(program_process)
    end

    test "when program is locked the event is ignored", %{program_process: program_process} do
      program_state = ProgramProcess.get_state(program_process)
      expected_state = %{ program_state | program: %{ program_state.program | locked: true }}
      ProgramProcess.set_state(program_process, expected_state)
      ProgramProcess.send_event(program_process, "touch", %{})
      assert expected_state == ProgramProcess.get_state(program_process)
    end

    test "when program does not have a matching label the event is ignored", %{program_process: program_process} do
      expected_state = ProgramProcess.get_state(program_process)
      ProgramProcess.send_event(program_process, "nolabel", %{})
      assert expected_state == ProgramProcess.get_state(program_process)
    end
  end

  describe "start_scheduler/1" do
    test "it starts the timer and sets it to active", %{program_process: program_process} do
      assert :started = ProgramProcess.start_scheduler(program_process)
      assert %{timer_ref: timer_ref, active: true} = ProgramProcess.get_state(program_process)
      assert timer_ref
    end

    test "it does not start another timer if one already running", %{program_process: program_process} do
      ProgramProcess.start_scheduler(program_process)
      assert %{timer_ref: timer_ref, active: true} = ProgramProcess.get_state(program_process)
      assert :exists = ProgramProcess.start_scheduler(program_process)
      assert %{timer_ref: ^timer_ref, active: true} = ProgramProcess.get_state(program_process)
    end
  end

  describe "stop_scheduler/1" do
    test "it stops any timer and sets it to inactive", %{program_process: program_process} do
      ProgramProcess.stop_scheduler(program_process)
      assert %{timer_ref: timer_ref, active: false} = ProgramProcess.get_state(program_process)
      refute timer_ref
    end
  end

  describe "performing actions" do
    setup %{instance_process: instance_process, program_process: program_process} do
      assert :ok = ProgramProcess.initialize_program(program_process, instance_process, 1, "#CYCLE 2\n/s")
      %{instance_process: instance_process, program_process: program_process}
    end

    test "it does nothing if not active", %{program_process: program_process} do
      state = ProgramProcess.get_state(program_process)
      ProgramProcess.stop_scheduler(program_process)
      Process.send(program_process, :perform_actions, [])
      assert state.program == ProgramProcess.get_state(program_process).program
    end

    test "does runs commands if active", %{program_process: program_process} do
      Process.send(program_process, :perform_actions, [])
       :timer.sleep 2
      assert %{pc: 2, status: :alive, wait_cycles: 2} = ProgramProcess.get_state(program_process).program
    end
  end
end

