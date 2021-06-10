defmodule DungeonCrawlWeb.CrawlerTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.LevelChannel
  alias DungeonCrawlWeb.Crawler

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.{Levels, LevelProcess, Registrar, DungeonRegistry}
  alias DungeonCrawl.Player

  test "join_and_broadcast/4 joining a dungeon" do
    dungeon = insert_autogenerated_dungeon()
    assert {dungeon_instance_id, location} = Crawler.join_and_broadcast(dungeon, "itsmehash", %{color: "red"}, true)
    assert %Player.Location{} = location
    tile = Repo.preload(location, [tile: :level]).tile
    assert dungeon_instance_id == tile.level.dungeon_instance_id

    # It registers the player location
    {:ok, instance} = Registrar.instance_process(tile.level.dungeon_instance_id, tile.level_instance_id)
    location_tile_id = tile.id
    assert %Levels{player_locations: %{^location_tile_id => ^location}} = LevelProcess.get_state(instance)

    # cleanup
    DungeonRegistry.remove(DungeonInstanceRegistry, tile.level.dungeon_instance_id)
  end

  test "join_and_broadcast/4 joining an instance" do
    di = insert_autogenerated_dungeon_instance()
    di_id = di.id
    instance = Repo.preload(di, :levels).levels |> Enum.at(0)
    location = insert_player_location(%{level_instance_id: instance.id, row: 1, user_id_hash: "itsmehash", state: "cash: 2"})

    {:ok, _, _socket} =
      socket("user_id_hash", %{user_id_hash: location.user_id_hash})
      |> subscribe_and_join(LevelChannel, "level:#{di.id}:#{instance.id}")

    assert {^di_id, location} = Crawler.join_and_broadcast(di, "itsmehash", %{color: "red", background_color: "green"}, nil)
    assert %Player.Location{} = location
    tile = Repo.preload(location, :tile).tile

    expected_row = tile.row
    expected_col = tile.col
    assert_broadcast "tile_changes", %{tiles: [%{row: ^expected_row, col: ^expected_col, rendering: "<div>@</div>"}]}
#    assert_broadcast "tile_changes", payload
#    assert %{tiles: [%{row: tile.row, col: tile.col, rendering: "<div>@</div>"}]} == payload

    # It registers the player location
    {:ok, instance} = Registrar.instance_process(di.id, instance.id)
    location_tile_id = tile.id
    assert %Levels{player_locations: %{^location_tile_id => ^location}} = LevelProcess.get_state(instance)

    # cleanup
    DungeonRegistry.remove(DungeonInstanceRegistry, di.id)
  end

  test "leave_and_broadcast" do
    di = insert_autogenerated_dungeon_instance()
    DungeonCrawl.Repo.update DungeonInstances.Dungeon.changeset(di, %{autogenerated: false})
    level_instance = Repo.preload(di, :levels).levels |> Enum.at(0)
    location = insert_player_location(%{level_instance_id: level_instance.id, row: 1, user_id_hash: "itsmehash", state: "cash: 2"})
    location2 = insert_player_location(%{level_instance_id: level_instance.id, row: 2, user_id_hash: "someoneelsetokeeptheinstance"})
    location2_id = location2.tile_instance_id

    {:ok, _, _socket} =
      socket("user_id_hash", %{user_id_hash: "itsmehash"})
      |> subscribe_and_join(LevelChannel, "level:#{di.id}:#{level_instance.id}")

    # PLAYER LEAVES, AND ONE PLAYER IS LEFT ----
    assert %Player.Location{} = location = Repo.preload(Crawler.leave_and_broadcast(location), :tile)

    rendering = "<div style='color: gray;background-color: linen'>Д</div>"
    assert_broadcast "full_render", payload
    assert String.contains?(payload.level_render, rendering)

    # It unregisters the player location
    {:ok, instance} = Registrar.instance_process(di.id, level_instance.id)
    state = LevelProcess.get_state(instance)
    assert %{^location2_id => %{user_id_hash: "someoneelsetokeeptheinstance"}} = state.player_locations

    # It dropped the players stuff
    junk_pile = Levels.get_tile(state, location.tile)
    assert junk_pile.script =~ ~r/#GIVE cash, 2, \?sender/i

    # It did not destroy the dungeon as its not marked as autogenerated
    assert Dungeons.get_dungeon(di.dungeon_id)

    # cleanup
    DungeonRegistry.remove(DungeonInstanceRegistry, di.id)
  end

  test "leave_and_broadcast deletes dungeon when its autogenerated" do
    di = insert_autogenerated_dungeon_instance()
    level_instance = Repo.preload(di, :levels).levels |> Enum.at(0)
    location = insert_player_location(%{level_instance_id: level_instance.id, row: 1, user_id_hash: "itsmehash", state: "cash: 2"})
    _location2 = insert_player_location(%{level_instance_id: level_instance.id, row: 2, user_id_hash: "someoneelsetokeeptheinstance"})

    {:ok, _, _socket} =
      socket("user_id_hash", %{user_id_hash: "itsmehash"})
      |> subscribe_and_join(LevelChannel, "level:#{di.id}:#{level_instance.id}")

    # PLAYER LEAVES
    assert %Player.Location{} = Crawler.leave_and_broadcast(location)

    # It did not destroy the dungeon as its not marked as autogenerated
    refute Dungeons.get_dungeon(di.dungeon_id)

    # cleanup
    DungeonRegistry.remove(DungeonInstanceRegistry, di.id)
  end
end
