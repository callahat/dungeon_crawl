defmodule DungeonCrawl.PlayerChannelTest do
  use DungeonCrawlWeb.ChannelCase
  use AssertEventually, timeout: 50, interval: 5

  alias DungeonCrawlWeb.PlayerChannel
  alias DungeonCrawl.DungeonProcesses.{LevelProcess, Registrar, DungeonRegistry}

  setup config do
    state = if is_nil(config["fog"]), do: "", else: "visibility: #{config[:visibility]}"
    level_instance = insert_autogenerated_level_instance(%{state: state})

    player_location = insert_player_location(%{level_instance_id: level_instance.id, row: 1, col: 5, state: %{"ammo" => 6, "health" => 100, "deaths" => 1}})
                      |> Repo.preload(:tile)

    {:ok, _, socket} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: player_location.user_id_hash})
      |> subscribe_and_join(PlayerChannel, "players:#{player_location.id}")

    on_exit(fn -> DungeonRegistry.remove(DungeonInstanceRegistry, level_instance.dungeon_instance_id) end)

    {:ok, socket: socket, location: player_location, level_instance: level_instance}
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

  test "with a location with bad tile", %{location: player_location} do
    DungeonCrawl.Repo.preload(player_location, :tile).tile |> DungeonCrawl.Repo.delete!
    assert {:error, %{message: "Not found", reload: true}} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: player_location.user_id_hash})
      |> subscribe_and_join(PlayerChannel, "players:#{player_location.id}")
  end

  test "refresh_level triggers the change_dungeon message to rerender the current level",
       %{socket: socket, level_instance: level_instance} do
    level_number = level_instance.number
    owner_id = level_instance.player_location_id
    push socket, "refresh_level", %{}
    assert_broadcast "change_level", %{level_number: ^level_number, level_owner_id: ^owner_id, level_render: _html}
    assert_broadcast "stat_update", %{stats: stats}
    assert Map.keys(stats) == ["ammo", "cash", "equipment", "equipped", "gems", "health", "keys", "lives", "score", "torch_light", "torches"]
  end

  @tag visibility: "fog"
  test "refresh_level triggers the change_dungeon message to rerender the current level, fog",
       %{socket: socket, level_instance: level_instance} do
    level_number = level_instance.number
    owner_id = level_instance.player_location_id
    push socket, "refresh_level", %{}
    assert_broadcast "change_level", %{level_number: ^level_number, level_owner_id: ^owner_id, level_render: _html}
    {:ok, instance_process} = Registrar.instance_process(level_instance)
    assert %{players_visible_coords: _pvcs} = LevelProcess.get_state(instance_process)
  end

  @tag visibility: "fog"
  test "update_visible deletes the players visible coords which forces an update when foggy",
       %{socket: socket, location: location, level_instance: level_instance} do
    {:ok, instance_process} = Registrar.instance_process(level_instance)
    LevelProcess.run_with(instance_process, fn(state) ->
      {:ok, %{ state | players_visible_coords: %{ location.tile_instance_id => %{} } }}
    end)

    push socket, "update_visible", %{}

    eventually refute Map.has_key?(
                        LevelProcess.get_state(instance_process).players_visible_coords,
                        location.tile_instance_id)
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push socket, "ping", %{"hello" => "there"}
    assert_reply ref, :ok, %{"hello" => "there"}
  end
end
