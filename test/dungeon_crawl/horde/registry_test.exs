defmodule DungeonCrawl.Horde.RegistryTest do
  use ExUnit.Case, async: false

  alias DungeonCrawl.Horde.Registry

  test "add_dungeon_process_meta/2" do
    # adds dungeon ID and process
    assert :ok = Registry.add_dungeon_process_meta(123, "imma pid")

    # can lookup by either
    assert {:ok, {:pid, "imma pid"}} == Registry.get_dungeon_process_meta({:dungeon_id, 123})
    assert {:ok, {:dungeon_id, 123}} == Registry.get_dungeon_process_meta({:pid, "imma pid"})
  end

  test "get_dungeon_process_meta/1" do
    Registry.add_dungeon_process_meta("stubbedDungeonId", "stubbedPid")

    assert {:ok, {:pid, "stubbedPid"}} == Registry.get_dungeon_process_meta({:dungeon_id, "stubbedDungeonId"})
    assert {:ok, {:dungeon_id, "stubbedDungeonId"}} == Registry.get_dungeon_process_meta({:pid, "stubbedPid"})
  end

  @tag capture_log: true
  test "remove_dungeon_process_meta/1" do
    orig_level = Logger.level
    Logger.configure(level: :info)
    config = %{pid_tuple: {:pid, "stubbedPid"}, dungeon_id_tuple: {:dungeon_id, "stubbedDungeonId"}}

    [config.pid_tuple, config.dungeon_id_tuple]
    |> Enum.each(fn tuple ->
      # setting up
      Registry.add_dungeon_process_meta("stubbedDungeonId", "stubbedPid")
      assert {:ok, config.pid_tuple} == Registry.get_dungeon_process_meta(config.dungeon_id_tuple)
      assert {:ok, config.dungeon_id_tuple} == Registry.get_dungeon_process_meta(config.pid_tuple)

      # Run the test
      log = ExUnit.CaptureLog.capture_log([level: :info], fn ->
        assert :ok == Registry.remove_dungeon_process_meta(tuple)
      end)

      # nothing logged
      assert log == ""

      # registry entries are gone
      assert :error = Registry.get_dungeon_process_meta(config.dungeon_id_tuple)
      assert :error = Registry.get_dungeon_process_meta(config.pid_tuple)

      # Already removed, log an info
      log = ExUnit.CaptureLog.capture_log([level: :info], fn ->
        assert :ok == Registry.remove_dungeon_process_meta(tuple)
      end)

      assert log =~ ~r/\[info\] <> Recieved remove meta request for #{ inspect tuple }.*maybe already cleared\?/
    end)

    Logger.configure(level: orig_level)
  end

end
