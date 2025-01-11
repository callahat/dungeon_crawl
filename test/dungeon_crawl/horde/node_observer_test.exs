defmodule DungeonCrawl.Horde.NodeObserverTest do
  use ExUnit.Case, async: false

  alias DungeonCrawl.Horde.NodeObserver

  test "nodeup" do
    {:ok, pid} = NodeObserver.start_link([[name: "TEST"]])
    Process.send(pid, {:nodeup, :node, :node_type}, [])

    members = Horde.Cluster.members(DungeonCrawl.Horde.DungeonSupervisor)

    assert length(members) == 1
  end

  test "nodedown" do
    {:ok, pid} = NodeObserver.start_link([[name: "TEST"]])
    Process.send(pid, {:nodedown, :node, :node_type}, [])

    members = Horde.Cluster.members(DungeonCrawl.Horde.DungeonSupervisor)

    assert length(members) == 1
  end
end