defmodule DungeonCrawl.PlayerChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.PlayerChannel
  alias DungeonCrawl.DungeonProcesses.{InstanceProcess, MapSets, MapSetRegistry}

  setup config do
    state = if is_nil(config[:fog]), do: "", else: "visibility: #{config[:visibility]}"
    map_instance = insert_autogenerated_dungeon_instance(%{state: state})

    player_location = insert_player_location(%{map_instance_id: map_instance.id, row: 1, col: 5, state: "ammo: 6, health: 100, deaths: 1"})
                      |> Repo.preload(:map_tile)

    {:ok, _, socket} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: player_location.user_id_hash})
      |> subscribe_and_join(PlayerChannel, "players:#{player_location.id}")

    on_exit(fn -> MapSetRegistry.remove(MapSetInstanceRegistry, map_instance.map_set_instance_id) end)

    {:ok, socket: socket, location: player_location, map_instance: map_instance}
  end

  test "with the wrong player", %{location: player_location} do
    bad_user = insert_user(%{is_admin: false, user_id_hash: "hackerman"})

    assert {:error, %{message: "Could not join channel"}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: bad_user.user_id_hash})
      |> subscribe_and_join(PlayerChannel, "players:#{player_location.id}")
  end

  test "with a bad location" do
    assert {:error, %{message: "Not found", reload: true}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: "user_id_hash"})
      |> subscribe_and_join(PlayerChannel, "players:12345")
  end

  test "with a location with bad map tile", %{location: player_location} do
    DungeonCrawl.Repo.preload(player_location, :map_tile).map_tile |> DungeonCrawl.Repo.delete!
    assert {:error, %{message: "Not found", reload: true}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: player_location.user_id_hash})
      |> subscribe_and_join(PlayerChannel, "players:#{player_location.id}")
  end

  test "refresh_dungeon triggers the change_dungeon message to rerender the current map", %{socket: socket, location: location} do
    instance_id = location.map_tile.map_instance_id
    push socket, "refresh_dungeon", %{}
    assert_broadcast "change_dungeon", %{dungeon_id: ^instance_id, dungeon_render: _html}
  end

  @tag visibility: "fog"
  test "refresh_dungeon triggers the change_dungeon message to rerender the current map, fog",
       %{socket: socket, location: location, map_instance: map_instance} do
    instance_id = location.map_tile.map_instance_id
    push socket, "refresh_dungeon", %{}
    assert_broadcast "change_dungeon", %{dungeon_id: ^instance_id, dungeon_render: _html}
    {:ok, instance_process} = MapSets.instance_process(map_instance.map_set_instance_id, instance_id)
    assert %{players_visible_coords: _pvcs} = InstanceProcess.get_state(instance_process)
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push socket, "ping", %{"hello" => "there"}
    assert_reply ref, :ok, %{"hello" => "there"}
  end
end
