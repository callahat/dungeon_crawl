defmodule DungeonCrawl.LevelAdminChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.LevelAdminChannel
  alias DungeonCrawl.DungeonProcesses.DungeonRegistry

  setup do
    dungeon_instance = insert_stubbed_dungeon_instance()

    level_instance = Enum.sort(Repo.preload(dungeon_instance, :levels).levels, fn(a, b) -> a.number < b.number end)
                     |> Enum.at(0)

    on_exit(fn -> DungeonRegistry.remove(DungeonInstanceRegistry, dungeon_instance.id) end)

    {:ok, dungeon_instance: dungeon_instance, level_instance: level_instance}
  end

  test "admin can subscribe", %{dungeon_instance: dungeon_instance, level_instance: level_instance} do
    user = insert_user(%{is_admin: true, user_id_hash: "user_id_hash"})

    assert {:ok, _, _socket} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: user.user_id_hash})
      |> subscribe_and_join(LevelAdminChannel, "level_admin:#{dungeon_instance.id}:#{level_instance.id}")
  end

  test "with a bad instance", %{dungeon_instance: dungeon_instance, level_instance: level_instance} do
    user = insert_user(%{is_admin: true, user_id_hash: "user_id_hash"})

    assert {:error, %{message: "Not found", reload: true}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: user.user_id_hash})
      |> subscribe_and_join(LevelAdminChannel, "level_admin:#{dungeon_instance.id + 1}:#{level_instance.id}")
  end

  test "when user is not admin", %{dungeon_instance: dungeon_instance, level_instance: level_instance} do
    user = insert_user(%{is_admin: false, user_id_hash: "user_id_hash"})

    assert {:error, %{message: "Could not join channel"}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: user.user_id_hash})
      |> subscribe_and_join(LevelAdminChannel, "level_admin:#{dungeon_instance.id}:#{level_instance.id}")
  end

  test "ping replies with status ok", %{dungeon_instance: dungeon_instance, level_instance: level_instance}  do
    user = insert_user(%{is_admin: true, user_id_hash: "user_id_hash"})

    {:ok, _, socket} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: user.user_id_hash})
      |> subscribe_and_join(LevelAdminChannel, "level_admin:#{dungeon_instance.id}:#{level_instance.id}")

    ref = push socket, "ping", %{"hello" => "there"}
    assert_reply ref, :ok, %{"hello" => "there"}
  end
end
