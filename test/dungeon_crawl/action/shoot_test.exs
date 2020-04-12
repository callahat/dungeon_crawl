defmodule DungeonCrawl.Action.ShootTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Shoot
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Player.Location

  setup config do
    instance = insert_stubbed_dungeon_instance(%{},
      [%MapTile{character: ".", row: 1, col: 2, z_index: 0},
       %MapTile{character: ".", row: 2, col: 2, z_index: 0},
       %MapTile{character: "#", row: 3, col: 2, z_index: 0, state: "blocking: true"},
       %MapTile{character: "@", row: 2, col: 2, z_index: 1, state: config[:ammo] || ""}])

    # Quik and dirty state init
    state = Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles
            |> Enum.reduce(%Instances{}, fn(dmt, state) -> 
                 {_, state} = Instances.create_map_tile(state, dmt)
                 state
               end)

    shooter = Instances.get_map_tile(state, %{row: 2, col: 2})
    %{state: state, shooter: shooter}
  end

  test "shoot/3 into an passable space spawns a bullet facing that way", %{state: state, shooter: shooter} do
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Instances.get_map_tile(updated_state, %{row: 1, col: 2})

    assert bullet.character == "◦"
    assert bullet.parsed_state[:facing] == "north"
    assert updated_state.program_contexts[bullet.id]
    assert updated_state.program_messages == []
    assert updated_state.new_pids == [bullet.id]
    assert updated_state.program_contexts[bullet.id].program.status == :alive
  end

  test "shoot/3 does nothing when the space is nil", %{state: state, shooter: shooter} do
    assert {:invalid} = Shoot.shoot(shooter, "east", state)
    refute Instances.get_map_tile(state, %{row: 2, col: 3})
  end

  test "shoot/3 bad direction or idle does nothing", %{state: state, shooter: shooter} do
    assert {:invalid} = Shoot.shoot(shooter, "gibberish", state)
    tile = Instances.get_map_tile(state, %{row: 2, col: 2})

    assert tile.character == "@"
  end

  test "shoot/3 into something blocking or responding to SHOT does not spawn a bullet", %{state: state, shooter: shooter} do
    # Its up to the caller to actually send the shot message to the hit program's tile at this point
    assert {:shot, shot_tile} = Shoot.shoot(shooter, "south", state)
    assert wall = Instances.get_map_tile(state, %{row: 3, col: 2})

    assert shot_tile.id == wall.id
    assert wall.character == "#"
  end

  test "shoot/3 can use the objects state variable", %{state: state, shooter: shooter} do
    shooter = %{shooter | parsed_state: %{facing: "north"}}
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Instances.get_map_tile(updated_state, %{row: 1, col: 2})

    assert bullet.character == "◦"
  end

  @tag ammo: "ammo: 1"
  test "shoot/3 when its a player with ammo", %{state: state, shooter: shooter} do
    player_location = %Location{map_tile_instance_id: shooter.id}

    assert {:ok, updated_state} = Shoot.shoot(player_location, "north", state)
    assert bullet = Instances.get_map_tile(updated_state, %{row: 1, col: 2})
    assert bullet.character == "◦"
  end

  @tag ammo: "ammo: 0"
  test "shoot/3 when its a player without ammo", %{state: state, shooter: shooter} do
    player_location = %Location{map_tile_instance_id: shooter.id}

    assert {:no_ammo} = Shoot.shoot(player_location, "north", state)
  end
end

