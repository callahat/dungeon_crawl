defmodule DungeonCrawl.InstanceProcessTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.Scripting.Program

  setup do
    {:ok, instance_process} = InstanceProcess.start_link([])
    %{instance_process: instance_process}
  end

  test "load_map", %{instance_process: instance_process} do

  end

  test "start_scheduler", %{instance_process: instance_process} do

  end

  test "inspect_state", %{instance_process: instance_process} do

  end

  test "send_event", %{instance_process: instance_process} do

  end

  test "responds_to_event?", %{instance_process: instance_process} do

  end
end
