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
                                               row: 23,
                                               col: 24,
                                               state: "ammo: 4, health: 100, cash: 420, gems: 1, red_key: 1, orange_key: 0",
                                               user_id_hash: @user_id_hash})
                      |> Repo.preload(:map_tile)

    # Quik and dirty state init
    state = Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles
            |> Enum.reduce(%Instances{instance_id: instance.id}, fn(dmt, state) ->
                 {_, state} = Instances.create_map_tile(state, dmt)
                 state
               end)
    state = %{ state | spawn_coordinates: [{2,3}],
                       player_locations: %{player_location.map_tile.id => player_location},
                       state_values: %{height: 10, width: 10} }

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
    assert grave.z_index == 1

    assert grave.script =~ ~r/#GIVE ammo, 4, \?sender/i
    assert grave.script =~ ~r/#GIVE cash, 420, \?sender/i
    assert grave.script =~ ~r/#GIVE gems, 1, \?sender/i
    assert grave.script =~ ~r/#GIVE red_key, 1, \?sender/i

    assert 0 = state.map_by_ids[player_map_tile.id].z_index
    assert 0 = state.map_by_ids[player_map_tile.id].parsed_state[:health]
    assert 0 = state.map_by_ids[player_map_tile.id].parsed_state[:red_key]
    assert 0 = state.map_by_ids[player_map_tile.id].parsed_state[:orange_key]
    assert 0 = state.map_by_ids[player_map_tile.id].parsed_state[:cash]
    assert 0 = state.map_by_ids[player_map_tile.id].parsed_state[:gems]
    assert 0 = state.map_by_ids[player_map_tile.id].parsed_state[:ammo]
    assert 1 = state.map_by_ids[player_map_tile.id].parsed_state[:deaths]

    # doesnt break when called twice
    {grave, state} = Player.bury(state, player_map_tile)
    refute grave.script =~ ~r/#GIVE ammo, 4, \?sender/i
    assert 2 = state.map_by_ids[player_map_tile.id].parsed_state[:deaths]
  end

  test "drop_all_items/2", %{state: state, player_map_tile: player_map_tile} do
    {junk_pile, _state} = Player.drop_all_items(state, player_map_tile)

    assert %{z_index: player_map_tile.z_index + 1,
             row: player_map_tile.row,
             col: player_map_tile.col,
             character: "Д"} == Map.take(junk_pile, [:z_index, :row, :col, :character])
    # CYRILLIC CAPITAL LETTER DE
    assert junk_pile.z_index == 2

    assert junk_pile.script =~ ~r/#GIVE ammo, 4, \?sender/i
    assert junk_pile.script =~ ~r/#GIVE cash, 420, \?sender/i
    assert junk_pile.script =~ ~r/#GIVE gems, 1, \?sender/i
    assert junk_pile.script =~ ~r/#GIVE red_key, 1, \?sender/i
  end

  test "petrify/2", %{state: state, player_map_tile: player_map_tile} do
    {statue, state} = Player.petrify(state, player_map_tile)

    [top, junk_pile | _others] = Instances.get_map_tiles(state, statue)

    assert top == statue

    assert %{row: player_map_tile.row,
             col: player_map_tile.col,
             character: "@"} == Map.take(statue, [:row, :col, :character])
    assert statue.z_index == 3

    assert %{row: player_map_tile.row,
             col: player_map_tile.col,
             character: "Д"} == Map.take(junk_pile, [:row, :col, :character])
    assert junk_pile.z_index == 2

    assert junk_pile.script =~ ~r/#GIVE ammo, 4, \?sender/i
    assert junk_pile.script =~ ~r/#GIVE cash, 420, \?sender/i
    assert junk_pile.script =~ ~r/#GIVE gems, 1, \?sender/i
    assert junk_pile.script =~ ~r/#GIVE red_key, 1, \?sender/i

    refute state.map_by_ids[player_map_tile.id]
  end

  test "respawn/2", %{state: state, player_map_tile: player_map_tile} do
    {player_map_tile, state} = Instances.update_map_tile_state(state, player_map_tile, %{entry_row: 5, entry_col: 8})
    state = %{ state | spawn_coordinates: [{3,7}]}
    # prefers player's entry location
    {respawned_player_map_tile, updated_state} = Player.respawn(state, player_map_tile)

    respawned_tile = Instances.get_map_tile(updated_state, respawned_player_map_tile)
    assert respawned_tile.character == "@"
    assert respawned_tile.parsed_state[:health] == 100
    assert respawned_tile.parsed_state[:buried] == false
    assert respawned_tile.row == 5
    assert respawned_tile.col == 8

    # uses spawn location when no entry coordinates
    player_map_tile = Map.put(player_map_tile, :parsed_state, %{})
    {respawned_player_map_tile, updated_state} = Player.respawn(state, player_map_tile)

    respawned_tile = Instances.get_map_tile(updated_state, respawned_player_map_tile)
    assert respawned_tile.row == 3
    assert respawned_tile.col == 7

    # when respawn_at_entry is false, falls back to spawn coordinates
    state = %{ state | state_values: Map.put(state.state_values, :respawn_at_entry, false)}
    {respawned_player_map_tile, updated_state} = Player.respawn(state, player_map_tile)

    respawned_tile = Instances.get_map_tile(updated_state, respawned_player_map_tile)
    assert respawned_tile.row == 3
    assert respawned_tile.col == 7

    # still can respawn even without spawn coordinates
    {respawned_player_map_tile, updated_state} =
      Player.respawn(%{ state | spawn_coordinates: []}, player_map_tile)

    respawned_tile = Instances.get_map_tile(updated_state, respawned_player_map_tile)
    assert respawned_tile.row == 3
    assert respawned_tile.col == 4
  end

  test "reset/2", %{state: state, player_map_tile: player_map_tile} do
    {player_map_tile, state} = Instances.update_map_tile_state(state, player_map_tile, %{entry_row: 5, entry_col: 8})

    # prefers player's entry location; logic is the same for respawn, only reset changes just coordinates
    {reset_player_map_tile, updated_state} = Player.reset(state, player_map_tile)

    reset_tile = Instances.get_map_tile(updated_state, reset_player_map_tile)

    assert Map.take(reset_tile, [:parsed_state, :character]) == Map.take(player_map_tile, [:parsed_state, :character])
    assert reset_tile.row == 5
    assert reset_tile.col == 8
  end

  test "place/3", %{player_map_tile: player_map_tile, player_location: player_location} do
    {other_instance, other_state} = _setup_other_instance_and_state()

    {placed_player_map_tile, updated_other_state} = Player.place(other_state, player_map_tile, player_location)
    placed_tile = Instances.get_map_tile(updated_other_state, placed_player_map_tile)
    assert Map.take(placed_tile, [:character, :health, :ammo, :gems, :cash]) == Map.take(player_map_tile, [:character, :health, :ammo, :gems, :cash])

    assert placed_tile.row == 6
    assert placed_tile.col == 9
    assert placed_tile.z_index == 0
    assert placed_tile.map_instance_id == other_instance.id
  end

  test "place/3 when already in that instance", %{player_map_tile: player_map_tile, player_location: player_location, state: state} do
    state = Map.put(state, :spawn_coordinates, [{2, 2}])
            |> Map.put(:instance_id, player_map_tile.map_instance_id)
    {placed_player_map_tile, updated_state} = Player.place(state, player_map_tile, player_location)
    placed_tile = Instances.get_map_tile(updated_state, placed_player_map_tile)
    assert Map.take(placed_tile, [:character, :health, :ammo, :gems, :cash]) == Map.take(player_map_tile, [:character, :health, :ammo, :gems, :cash])

    assert placed_tile.row == 2
    assert placed_tile.col == 2
    assert placed_tile.z_index == 1
    assert placed_tile.map_instance_id == state.instance_id
  end

  test "place/3 when there are no spawn_coordinates", %{player_map_tile: player_map_tile, player_location: player_location} do
    {other_instance, other_state} = _setup_other_instance_and_state()
    other_state = Map.put(other_state, :spawn_coordinates, [])

    {placed_player_map_tile, updated_other_state} = Player.place(other_state, player_map_tile, player_location)
    placed_tile = Instances.get_map_tile(updated_other_state, placed_player_map_tile)
    assert Map.take(placed_tile, [:character, :health, :ammo, :gems, :cash]) == Map.take(player_map_tile, [:character, :health, :ammo, :gems, :cash])

    assert placed_tile.row == 3
    assert placed_tile.col == 4
    assert placed_tile.z_index == 0
    assert placed_tile.map_instance_id == other_instance.id
  end

  test "place/4", %{player_map_tile: player_map_tile, player_location: player_location} do
    {other_instance, other_state} = _setup_other_instance_and_state()

    {placed_player_map_tile, updated_other_state} = Player.place(other_state, player_map_tile, player_location, %{match_key: "red"})
    placed_tile = Instances.get_map_tile(updated_other_state, placed_player_map_tile)
    assert Map.take(placed_tile, [:character, :health, :ammo, :gems, :cash]) == Map.take(player_map_tile, [:character, :health, :ammo, :gems, :cash])

    assert placed_tile.row == 1
    assert placed_tile.col == 6
    assert placed_tile.z_index == 1
    assert placed_tile.map_instance_id == other_instance.id
  end

  test "place/4 at the same level prefers different passage exit", %{state: state, player_map_tile: player_map_tile, player_location: player_location} do
    passage_tiles = [%MapTile{name: "Passage", character: "0", row: 1, col: 1, z_index: 2, state: "blocking: true", color: "red"},
                     %MapTile{name: "Passage", character: "0", row: 1, col: 6, z_index: 2, state: "blocking: true", color: "red"}]

    state = Enum.reduce(passage_tiles, state, fn(dmt, state) ->
              {_, state} = Instances.create_map_tile(state, dmt)
              state
            end)
    passage_1 = Instances.get_map_tile(state, %{row: 1, col: 1})
    passage_2 = Instances.get_map_tile(state, %{row: 1, col: 6})
    state = %{ state | passage_exits: [{passage_1.id, "red"}, {passage_2.id, "red"}] }

    {placed_player_map_tile, updated_state} = Player.place(state, player_map_tile, player_location, Map.put(passage_1, :match_key, "red"))
    placed_tile = Instances.get_map_tile(updated_state, placed_player_map_tile)
    assert Map.take(placed_tile, [:character, :health, :ammo, :gems, :cash]) ==
           Map.take(player_map_tile, [:character, :health, :ammo, :gems, :cash])

    assert placed_tile.row == 1
    assert placed_tile.col == 6
    assert placed_tile.z_index == 3
    assert placed_tile.map_instance_id == state.instance_id
  end

  test "place/4 when no keys match", %{player_map_tile: player_map_tile, player_location: player_location} do
    {other_instance, other_state} = _setup_other_instance_and_state()

    {placed_player_map_tile, updated_other_state} = Player.place(other_state, player_map_tile, player_location, %{match_key: "fakecolor"})
    placed_tile = Instances.get_map_tile(updated_other_state, placed_player_map_tile)
    assert Map.take(placed_tile, [:character, :health, :ammo, :gems, :cash]) ==
           Map.take(player_map_tile, [:character, :health, :ammo, :gems, :cash])

    # falls back to spawn location logic
    assert placed_tile.row == 6
    assert placed_tile.col == 9
    assert placed_tile.z_index == 0
    assert placed_tile.map_instance_id == other_instance.id
  end

  test "place/4 when match_key nil can use any exit", %{player_map_tile: player_map_tile, player_location: player_location} do
    {other_instance, other_state} = _setup_other_instance_and_state()

    {placed_player_map_tile, updated_other_state} = Player.place(other_state, player_map_tile, player_location, %{match_key: nil})
    placed_tile = Instances.get_map_tile(updated_other_state, placed_player_map_tile)
    assert Map.take(placed_tile, [:character, :health, :ammo, :gems, :cash]) ==
           Map.take(player_map_tile, [:character, :health, :ammo, :gems, :cash])

    assert placed_tile.row == 1
    assert placed_tile.col == 6
    assert placed_tile.z_index == 1
    assert placed_tile.map_instance_id == other_instance.id
  end

  test "place/4 when coming from an adjacent map", %{player_map_tile: player_map_tile, player_location: player_location} do
    {other_instance, other_state} = _setup_other_instance_and_state()
    other_state = %{ other_state | state_values: %{rows: 20, cols: 20} }

    {placed_player_map_tile, updated_other_state} = Player.place(other_state, player_map_tile, player_location, %{edge: "north"})
    placed_tile = Instances.get_map_tile(updated_other_state, placed_player_map_tile)
    assert Map.take(placed_tile, [:character, :health, :ammo, :gems, :cash]) ==
           Map.take(player_map_tile, [:character, :health, :ammo, :gems, :cash])

    assert placed_tile.row == 0
    assert placed_tile.col == 4 # col was mod by cols to keep it within the borders
    assert placed_tile.z_index == 0
    assert placed_tile.map_instance_id == other_instance.id

    # when other is within the range, no mod needed for the static coord
    other_state = %{ other_state | state_values: %{rows: 20, cols: 30} }

    {placed_player_map_tile, updated_other_state} = Player.place(other_state, player_map_tile, player_location, %{edge: "north"})
    placed_tile = Instances.get_map_tile(updated_other_state, placed_player_map_tile)

    assert placed_tile.row == 0
    assert placed_tile.col == player_map_tile.col
    assert placed_tile.z_index == 0
    assert placed_tile.map_instance_id == other_instance.id
  end

  defp _setup_other_instance_and_state() do
    tiles = [%MapTile{name: "Stairs Down", character: ">", row: 1, col: 6, z_index: 0, state: "blocking: false", color: "red"}]
    other_instance = insert_stubbed_dungeon_instance(%{height: 20, width: 20}, tiles)
    passage = Enum.at(Repo.preload(other_instance, :dungeon_map_tiles).dungeon_map_tiles, 0)
    other_state = Repo.preload(other_instance, :dungeon_map_tiles).dungeon_map_tiles
                  |> Enum.reduce(%Instances{}, fn(dmt, state) ->
                       {_, state} = Instances.create_map_tile(state, dmt)
                       state
                     end)
                  |> Map.merge(%{ spawn_coordinates: [{6,9}], instance_id: other_instance.id })
                  |> Map.put(:state_values, %{height: other_instance.height, width: other_instance.width})
                  |> Map.put(:passage_exits, [{passage.id, "red"}])
    {other_instance, other_state}
  end
end
