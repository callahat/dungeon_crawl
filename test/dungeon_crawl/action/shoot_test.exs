defmodule DungeonCrawl.Action.ShootTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Shoot
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Player.Location

  setup config do
    DungeonCrawl.TileTemplates.TileSeeder.BasicTiles.bullet_tile

    instance = insert_stubbed_level_instance(%{},
      [%Tile{character: ".", row: 1, col: 2, z_index: 0},
       %Tile{character: ".", row: 2, col: 2, z_index: 0},
       %Tile{character: "#", row: 3, col: 2, z_index: 0, state: "blocking: true"},
       %Tile{character: "@", row: 2, col: 2, z_index: 1, state: config[:ammo] || ""}])

    # Quik and dirty state init
    state = Repo.preload(instance, :tiles).tiles
            |> Enum.reduce(%Instances{}, fn(t, state) ->
                 {_, state} = Instances.create_tile(state, t)
                 state
               end)

    shooter = Instances.get_tile(state, %{row: 2, col: 2})
    %{state: state, shooter: shooter}
  end

  test "shoot/3 spawns a bullet facing that way", %{state: state, shooter: shooter} do
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Instances.get_tile(updated_state, %{row: 2, col: 2})

    assert bullet.character == "◦"
    assert bullet.parsed_state[:facing] == "north"
    assert updated_state.program_contexts[bullet.id]
    assert updated_state.program_messages == []
    assert updated_state.new_pids == [bullet.id]
    assert updated_state.program_contexts[bullet.id].program.status == :alive
  end

  test "shoot/3 spawns a bullet utilizing the shooters bullet damage", %{state: state, shooter: shooter} do
    # damage defaults to five if shooter does not have bullet_damage in their state
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Instances.get_tile(updated_state, %{row: 2, col: 2})
    assert bullet.parsed_state[:damage] == 5

    # when shooter has state var bullet_damage set
    {shooter, state} = Instances.update_tile_state(state, shooter, %{bullet_damage: 20})
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Instances.get_tile(updated_state, %{row: 2, col: 2})
    assert bullet.parsed_state[:damage] == 20
  end

  test "shoot/3 idle does nothing", %{state: state, shooter: shooter} do
    assert {:invalid} = Shoot.shoot(shooter, "gibberish", state)
    tile = Instances.get_tile(state, %{row: 2, col: 2})

    assert tile.character == "@"
  end

  test "shoot/3 can use the objects state variable", %{state: state, shooter: shooter} do
    shooter = %{shooter | parsed_state: %{facing: "north"}}
    assert {:ok, updated_state} = Shoot.shoot(shooter, "north", state)
    assert bullet = Instances.get_tile(updated_state, %{row: 2, col: 2})

    assert bullet.character == "◦"
  end

  @tag ammo: "ammo: 1"
  test "shoot/3 when its a player with ammo", %{state: state, shooter: shooter} do
    player_location = %Location{tile_instance_id: shooter.id}

    assert {:ok, updated_state} = Shoot.shoot(player_location, "north", state)
    assert bullet = Instances.get_tile(updated_state, %{row: 2, col: 2})
    assert bullet.character == "◦"
  end

  @tag ammo: "ammo: 0"
  test "shoot/3 when its a player without ammo", %{state: state, shooter: shooter} do
    player_location = %Location{tile_instance_id: shooter.id}

    assert {:no_ammo} = Shoot.shoot(player_location, "north", state)
  end
end

