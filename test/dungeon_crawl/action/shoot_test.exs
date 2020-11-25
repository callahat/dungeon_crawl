defmodule DungeonCrawl.Action.ShootTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Shoot
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.ProgramRegistry
  alias DungeonCrawl.DungeonProcesses.ProgramProcess
  alias DungeonCrawl.Player.Location

  setup config do
    {:ok, instance_process} = InstanceProcess.start_link([])

    instance = insert_stubbed_dungeon_instance(%{},
      [%MapTile{character: ".", row: 1, col: 2, z_index: 0},
       %MapTile{character: ".", row: 2, col: 2, z_index: 0},
       %MapTile{character: "#", row: 3, col: 2, z_index: 0, state: "blocking: true"},
       %MapTile{character: "@", row: 2, col: 2, z_index: 1, state: config[:ammo] || ""}])


    InstanceProcess.load_map(instance_process, Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles)

    # Quik and dirty state init
    state = InstanceProcess.get_state(instance_process)

    shooter = Instances.get_map_tile(state, %{row: 2, col: 2})
    %{state: state, shooter: shooter}
  end

  test "shoot/3 spawns a bullet facing that way", %{state: state, shooter: shooter} do
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Enum.at(Instances.get_map_tiles(updated_state, %{row: 2, col: 2}), -1)

    assert bullet.character == "◦"
    assert bullet.parsed_state[:facing] == "north"

    assert program_process = ProgramRegistry.lookup(updated_state.program_registry, bullet.id)
    assert ProgramProcess.get_state(program_process).program.status == :alive
  end

  test "shoot/3 spawns a bullet utilizing the shooters bullet damage", %{state: state, shooter: shooter} do
    # damage defaults to five if shooter does not have bullet_damage in their state
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Enum.at(Instances.get_map_tiles(updated_state, %{row: 2, col: 2}), -1)
    assert bullet.parsed_state[:damage] == 5

    # when shooter has state var bullet_damage set
    {shooter, state} = Instances.update_map_tile_state(state, shooter, %{bullet_damage: 20})
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Enum.at(Instances.get_map_tiles(updated_state, %{row: 2, col: 2}), -1)
    assert bullet.parsed_state[:damage] == 20
  end

  test "shoot/3 idle does nothing", %{state: state, shooter: shooter} do
    assert {:invalid} = Shoot.shoot(shooter, "gibberish", state)
    tile = Instances.get_map_tile(state, %{row: 2, col: 2})

    assert tile.character == "@"
  end

  test "shoot/3 can use the objects state variable", %{state: state, shooter: shooter} do
    shooter = %{shooter | parsed_state: %{facing: "north"}}
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Enum.at(Instances.get_map_tiles(updated_state, %{row: 2, col: 2}), -1)

    assert bullet.character == "◦"
  end

  @tag ammo: "ammo: 1"
  test "shoot/3 when its a player with ammo", %{state: state, shooter: shooter} do
    player_location = %Location{map_tile_instance_id: shooter.id}

    assert {:ok, updated_state} = Shoot.shoot(player_location, "north", state)
    assert bullet = Enum.at(Instances.get_map_tiles(updated_state, %{row: 2, col: 2}), -1)
    assert bullet.character == "◦"
  end

  @tag ammo: "ammo: 0"
  test "shoot/3 when its a player without ammo", %{state: state, shooter: shooter} do
    player_location = %Location{map_tile_instance_id: shooter.id}

    assert {:no_ammo} = Shoot.shoot(player_location, "north", state)
  end
end

