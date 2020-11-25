defmodule DungeonCrawl.ProgramProcessTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.ProgramProcess
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.Scripting.Program

  setup do
    {:ok, instance_process} = InstanceProcess.start_link([])
    {:ok, program_process} = ProgramProcess.start_link([])

    %{instance_process: instance_process, program_process: program_process}
  end

  describe "initialize_program" do
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

  describe "responds_to_event?" do
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

  describe "send_event" do
    setup %{instance_process: instance_process, program_process: program_process} do
      assert :ok = ProgramProcess.initialize_program(program_process, instance_process, 1, "#END\n:TOUCH\nHEY")
      %{instance_process: instance_process, program_process: program_process}
    end

    test "when program has that label it changes the pc", %{program_process: program_process} do
      ProgramProcess.send_event(program_process, "touch", %{})
      assert %{program: %Program{pc: 2, status: :alive}} = ProgramProcess.get_state(program_process)
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
end

