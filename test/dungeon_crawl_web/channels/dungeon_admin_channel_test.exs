defmodule DungeonCrawl.DungeonAdminChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.DungeonAdminChannel
  alias DungeonCrawl.DungeonProcesses.MapSetRegistry

  setup do
    map_set_instance = insert_stubbed_map_set_instance()

    map_instance = Enum.sort(Repo.preload(map_set_instance, :maps).maps, fn(a, b) -> a.number < b.number end)
                   |> Enum.at(0)

    on_exit(fn -> MapSetRegistry.remove(MapSetInstanceRegistry, map_set_instance.id) end)

    {:ok, map_set_instance: map_set_instance, map_instance: map_instance}
  end

  test "admin can subscribe", %{map_set_instance: map_set_instance, map_instance: map_instance} do
    user = insert_user(%{is_admin: true, user_id_hash: "user_id_hash"})

    assert {:ok, _, _socket} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: user.user_id_hash})
      |> subscribe_and_join(DungeonAdminChannel, "dungeon_admin:#{map_set_instance.id}:#{map_instance.id}")
  end

  test "with a bad instance", %{map_set_instance: map_set_instance, map_instance: map_instance} do
    user = insert_user(%{is_admin: true, user_id_hash: "user_id_hash"})

    assert {:error, %{message: "Not found", reload: true}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: user.user_id_hash})
      |> subscribe_and_join(DungeonAdminChannel, "dungeon_admin:#{map_set_instance.id + 1}:#{map_instance.id}")
  end

  test "when user is not admin", %{map_set_instance: map_set_instance, map_instance: map_instance} do
    user = insert_user(%{is_admin: false, user_id_hash: "user_id_hash"})

    assert {:error, %{message: "Could not join channel"}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: user.user_id_hash})
      |> subscribe_and_join(DungeonAdminChannel, "dungeon_admin:#{map_set_instance.id}:#{map_instance.id}")
  end

  test "ping replies with status ok", %{map_set_instance: map_set_instance, map_instance: map_instance}  do
    user = insert_user(%{is_admin: true, user_id_hash: "user_id_hash"})

    {:ok, _, socket} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: user.user_id_hash})
      |> subscribe_and_join(DungeonAdminChannel, "dungeon_admin:#{map_set_instance.id}:#{map_instance.id}")

    ref = push socket, "ping", %{"hello" => "there"}
    assert_reply ref, :ok, %{"hello" => "there"}
  end
end
