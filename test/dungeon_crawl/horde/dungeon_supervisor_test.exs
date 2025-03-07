defmodule DungeonCrawl.Horde.DungeonSupervisorTest do
  use DungeonCrawl.DataCase
  use ExUnit.Case, async: false

  alias DungeonCrawl.Horde.{DungeonSupervisor, Registry}
  alias DungeonCrawl.DungeonProcesses.DungeonProcess

  # Mostly smoke testing, the supervisor is hit by many other parts of the system

  @tag :horde
  test "start_child/1" do
    di = insert_stubbed_dungeon_instance()

    child_spec = %{
      id: di.id,
      start: {DungeonProcess, :start_link, [[name: _via_tuple(di.id)]]},
      restart: :temporary,
    }

    assert {:ok, dpid} = DungeonSupervisor.start_child(child_spec)
    assert {:error, {:already_started, ^dpid}} = DungeonSupervisor.start_child(child_spec)
  end

  @tag :horde
  test "which_children/0" do
    # nothing started yet
    assert [] == DungeonSupervisor.which_children()

    di = insert_stubbed_dungeon_instance()
    child_spec = %{
      id: di.id,
      start: {DungeonProcess, :start_link, [[name: _via_tuple(di.id)]]},
      restart: :temporary,
    }
    assert {:ok, dpid} = DungeonSupervisor.start_child(child_spec)

    assert [{:undefined, dpid, :worker, [DungeonProcess]}] == DungeonSupervisor.which_children()
  end

  defp _via_tuple(name) do
    {:via, Horde.Registry, {Registry, name}}
  end
end