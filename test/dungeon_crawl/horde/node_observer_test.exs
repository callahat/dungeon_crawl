defmodule DungeonCrawl.Horde.NodeObserverTest do
  use ExUnit.Case, async: false

  alias DungeonCrawl.Horde.NodeObserver

  @tag :horde
  test "nodeup" do
    {:ok, pid} = NodeObserver.start_link([[name: "TEST1"]])
    Process.send(pid, {:nodeup, :node, :node_type}, [])

    members = Horde.Cluster.members(DungeonCrawl.Horde.DungeonSupervisor)

    assert length(members) == 1
  end

  @tag :horde
  test "nodedown" do
    {:ok, pid} = NodeObserver.start_link([[name: "TEST2"]])
    Process.send(pid, {:nodedown, :node, :node_type}, [])

    members = Horde.Cluster.members(DungeonCrawl.Horde.DungeonSupervisor)

    assert length(members) == 1
  end
end