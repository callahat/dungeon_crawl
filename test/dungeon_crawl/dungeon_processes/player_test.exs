defmodule DungeonCrawl.DungeonProcesses.PlayerTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.Player

  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances

  @user_id_hash "goodhash"

  setup do
    instance = insert_stubbed_dungeon_instance(%{},
      [%MapTile{name: "Floor", character: ".", row: 2, col: 2, z_index: 0, state: "blocking: false"},
       %MapTile{name: "Floor", character: ".", row: 2, col: 3, z_index: 0, state: "blocking: false"}])

    player_location = insert_player_location(%{map_instance_id: instance.id,
                                               row: 2,
                                               col: 2,
                                               state: "ammo: 4, health: 100, cash: 420, gems: 1, red_key: 1, orange_key: 0",
                                               user_id_hash: @user_id_hash})
                      |> Repo.preload(:map_tile)

    # Quik and dirty state init
    state = Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles
            |> Enum.reduce(%Instances{}, fn(dmt, state) -> 
                 {_, state} = Instances.create_map_tile(state, dmt)
                 state
               end)
    state = %{ state | spawn_coordinates: [{2,3}] }

    %{state: state, player_map_tile: player_location.map_tile, player_location: player_location}
  end

  test "current_stats/2", %{state: state, player_map_tile: player_map_tile} do
    assert %{ammo: 4, cash: 420, gems: 1, health: 100, keys: keys} = Player.current_stats(state, player_map_tile)
    assert "<pre class='tile_template_preview'><span style='color: red;'>♀</span></pre>" = keys
  end

  test "current_stats/2 when the map tile does not exist (this path should not happen)", %{player_map_tile: player_map_tile} do
    assert %{} == Player.current_stats(%Instances{}, player_map_tile)
  end

  test "current_stats/1" do
    assert %{ammo: 4, cash: 420, gems: 1, health: 100, keys: keys} = Player.current_stats(@user_id_hash)
    assert "<pre class='tile_template_preview'><span style='color: red;'>♀</span></pre>" = keys
  end

  test "current_stats/1 handles someone not in a dungeon" do
    assert %{} == Player.current_stats("notinadungeonhash")
  end

  test "bury/2", %{state: state, player_map_tile: player_map_tile} do
    {grave, state} = Player.bury(state, player_map_tile)

    assert %{z_index: player_map_tile.z_index,
             row: player_map_tile.row,
             col: player_map_tile.col,
             character: "✝"} == Map.take(grave, [:z_index, :row, :col, :character])

    assert grave.script =~ ~r/#GIVE ammo, 4, \?sender/i
    assert grave.script =~ ~r/#GIVE cash, 420, \?sender/i
    assert grave.script =~ ~r/#GIVE gems, 1, \?sender/i
    assert grave.script =~ ~r/#GIVE red_key, 1, \?sender/i

    assert -1 = state.map_by_ids[player_map_tile.id].z_index
    assert  0 = state.map_by_ids[player_map_tile.id].parsed_state[:health]
    assert  0 = state.map_by_ids[player_map_tile.id].parsed_state[:red_key]
    assert  0 = state.map_by_ids[player_map_tile.id].parsed_state[:orange_key]
    assert  0 = state.map_by_ids[player_map_tile.id].parsed_state[:cash]
    assert  0 = state.map_by_ids[player_map_tile.id].parsed_state[:gems]
    assert  0 = state.map_by_ids[player_map_tile.id].parsed_state[:ammo]
  end

  test "respawn/2", %{state: state, player_map_tile: player_map_tile} do
    {respawned_player_map_tile, updated_state} = Player.respawn(state, player_map_tile)
    respawned_tile = Instances.get_map_tile(updated_state, respawned_player_map_tile)
    assert respawned_tile.character == "@"
    assert respawned_tile.parsed_state[:health] == 100
    assert respawned_tile.parsed_state[:buried] == false
  end

  test "place/3", %{player_map_tile: player_map_tile, player_location: player_location} do
    other_instance = insert_stubbed_dungeon_instance()
    other_state = Repo.preload(other_instance, :dungeon_map_tiles).dungeon_map_tiles
                  |> Enum.reduce(%Instances{}, fn(dmt, state) ->
                       {_, state} = Instances.create_map_tile(state, dmt)
                       state
                     end)
                  |> Map.merge(%{ spawn_coordinates: [{6,9}], instance_id: other_instance.id })

    {placed_player_map_tile, updated_other_state} = Player.place(other_state, player_map_tile, player_location)
    placed_tile = Instances.get_map_tile(updated_other_state, placed_player_map_tile)
    assert Map.take(placed_tile, [:character, :health, :ammo, :gems, :cash]) == Map.take(player_map_tile, [:character, :health, :ammo, :gems, :cash])

    assert placed_tile.row == 6
    assert placed_tile.col == 9
    assert placed_tile.z_index == 0
    assert placed_tile.map_instance_id == other_instance.id
  end
end
