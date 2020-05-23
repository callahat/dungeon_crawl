defmodule DungeonCrawl.DungeonProcesses.PlayerTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.Player

  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances

  @user_id_hash "goodhash"

  setup do
    instance = insert_stubbed_dungeon_instance(%{},
      [%MapTile{character: ".", row: 2, col: 2, z_index: 0, state: "blocking: false"}])

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

    %{state: state, player_map_tile: player_location.map_tile}
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
end
