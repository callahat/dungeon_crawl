defmodule DungeonCrawlWeb.CrawlerTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.DungeonChannel
  alias DungeonCrawlWeb.Crawler

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonProcesses.{Instances, InstanceProcess, MapSets, MapSetRegistry}
  alias DungeonCrawl.Player

  test "join_and_broadcast/4 joining a dungeon" do
    map_set = insert_autogenerated_map_set()
    assert {map_set_instance_id, location} = Crawler.join_and_broadcast(map_set, "itsmehash", %{color: "red"}, true)
    assert %Player.Location{} = location
    map_tile = Repo.preload(location, [map_tile: :dungeon]).map_tile
    assert map_set_instance_id == map_tile.dungeon.map_set_instance_id

    # It registers the player location
    {:ok, instance} = MapSets.instance_process(map_tile.dungeon.map_set_instance_id, map_tile.map_instance_id)
    location_map_tile_id = map_tile.id
    assert %Instances{player_locations: %{^location_map_tile_id => ^location}} = InstanceProcess.get_state(instance)

    # cleanup
    MapSetRegistry.remove(MapSetInstanceRegistry, map_tile.dungeon.map_set_instance_id)
  end

  test "join_and_broadcast/4 joining an instance" do
    msi = insert_autogenerated_map_set_instance()
    msi_id = msi.id
    instance = Repo.preload(msi, :maps).maps |> Enum.at(0)
    location = insert_player_location(%{map_instance_id: instance.id, row: 1, user_id_hash: "itsmehash", state: "cash: 2"})

    {:ok, _, _socket} =
      socket("user_id_hash", %{user_id_hash: location.user_id_hash})
      |> subscribe_and_join(DungeonChannel, "dungeons:#{msi.id}:#{instance.id}")

    assert {^msi_id, location} = Crawler.join_and_broadcast(msi, "itsmehash", %{color: "red", background_color: "green"}, nil)
    assert %Player.Location{} = location
    map_tile = Repo.preload(location, :map_tile).map_tile

    expected_row = map_tile.row
    expected_col = map_tile.col
    assert_broadcast "tile_changes", %{tiles: [%{row: ^expected_row, col: ^expected_col, rendering: "<div>@</div>"}]}
#    assert_broadcast "tile_changes", payload
#    assert %{tiles: [%{row: map_tile.row, col: map_tile.col, rendering: "<div>@</div>"}]} == payload

    # It registers the player location
    {:ok, instance} = MapSets.instance_process(msi.id, instance.id)
    location_map_tile_id = map_tile.id
    assert %Instances{player_locations: %{^location_map_tile_id => ^location}} = InstanceProcess.get_state(instance)

    # cleanup
    MapSetRegistry.remove(MapSetInstanceRegistry, msi.id)
  end

  test "leave_and_broadcast" do
    msi = insert_autogenerated_map_set_instance()
    DungeonCrawl.Repo.update DungeonCrawl.DungeonInstances.MapSet.changeset(msi, %{autogenerated: false})
    map_instance = Repo.preload(msi, :maps).maps |> Enum.at(0)
    location = insert_player_location(%{map_instance_id: map_instance.id, row: 1, user_id_hash: "itsmehash", state: "cash: 2"})
    location2 = insert_player_location(%{map_instance_id: map_instance.id, row: 2, user_id_hash: "someoneelsetokeeptheinstance"})
    location2_id = location2.map_tile_instance_id

    {:ok, _, _socket} =
      socket("user_id_hash", %{user_id_hash: "itsmehash"})
      |> subscribe_and_join(DungeonChannel, "dungeons:#{msi.id}:#{map_instance.id}")

    # PLAYER LEAVES, AND ONE PLAYER IS LEFT ----
    assert %Player.Location{} = location = Repo.preload(Crawler.leave_and_broadcast(location), :map_tile)

    rendering = "<div style='color: gray;background-color: linen'>Д</div>"
    assert_broadcast "full_render", payload
    assert String.contains?(payload.dungeon_render, rendering)

    # It unregisters the player location
    {:ok, instance} = MapSets.instance_process(msi.id, map_instance.id)
    state = InstanceProcess.get_state(instance)
    assert %{^location2_id => %{user_id_hash: "someoneelsetokeeptheinstance"}} = state.player_locations

    # It dropped the players stuff
    junk_pile = Instances.get_map_tile(state, location.map_tile)
    assert junk_pile.script =~ ~r/#GIVE cash, 2, \?sender/i

    # It did not destroy the map as its not marked as autogenerated
    assert Dungeon.get_map_set(msi.map_set_id)

    # cleanup
    MapSetRegistry.remove(MapSetInstanceRegistry, msi.id)
  end

  test "leave_and_broadcast deletes map_set when its autogenerated" do
    msi = insert_autogenerated_map_set_instance()
    map_instance = Repo.preload(msi, :maps).maps |> Enum.at(0)
    location = insert_player_location(%{map_instance_id: map_instance.id, row: 1, user_id_hash: "itsmehash", state: "cash: 2"})
    _location2 = insert_player_location(%{map_instance_id: map_instance.id, row: 2, user_id_hash: "someoneelsetokeeptheinstance"})

    {:ok, _, _socket} =
      socket("user_id_hash", %{user_id_hash: "itsmehash"})
      |> subscribe_and_join(DungeonChannel, "dungeons:#{msi.id}:#{map_instance.id}")

    # PLAYER LEAVES
    assert %Player.Location{} = Crawler.leave_and_broadcast(location)

    # It did not destroy the map as its not marked as autogenerated
    refute Dungeon.get_map_set(msi.map_set_id)

    # cleanup
    MapSetRegistry.remove(MapSetInstanceRegistry, msi.id)
  end
end
