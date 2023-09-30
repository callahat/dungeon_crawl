defmodule DungeonCrawl.Action.Shoot do
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.StateValue

  @doc """
  Fires a bullet in the given direction. The bullet will spawn on the tile one away from the object
  in the direction, unless that tile is blocking or responds to "SHOT", in which case that tile
  will be sent the "SHOT" message and no bullet will spawn.
  Otherwise, the bullet will walk in given direction until it hits something, or something
  responds to the "SHOT" message.
  """
  def shoot(%Location{} = player_location, direction, %Levels{} = state) do
    player_tile = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})

    if player_tile.state["ammo"] && player_tile.state["ammo"] > 0 do
      {player_tile, state} = Levels.update_tile_state(state, player_tile, %{"ammo" => player_tile.state["ammo"] -1})
      shoot(player_tile, direction, state)
    else
      {:no_ammo}
    end
  end

  def shoot(%Tile{} = shooter_tile, direction, %Levels{} = state) do
    if !Enum.member?(["north","south","east","west","up","down","left","right"], direction) do
      {:invalid}
    else
      {bullet_tile_template, state, _} = Levels.get_tile_template("bullet", state)
      top_z_index = Levels.get_tile(state, shooter_tile).z_index

      # TODO: tile spawning (including player character tile) should probably live somewhere else once a pattern emerges
      {:ok, bullet} = Map.take(shooter_tile, [:level_instance_id, :row, :col])
                      |> Map.merge(%{z_index: top_z_index + 1})
                      |> Map.merge(Map.take(bullet_tile_template, [:character, :color, :background_color, :script]))
                      |> Map.put(:state, Map.put(bullet_tile_template.state, "facing", direction))
                      |> DungeonCrawl.DungeonInstances.new_tile()
      {bullet, state} = Levels.create_tile(state, bullet)
      extras = if bullet_damage = StateValue.get_int(shooter_tile, "bullet_damage"), do: %{"damage" => bullet_damage}, else: %{}

      extras = if StateValue.get_bool(shooter_tile, "player"), do: Map.put(extras, "owner", shooter_tile.id),
                                                                  else: Map.put(extras, "owner", "enemy")

      {_, state} = Levels.update_tile_state(state, bullet, extras)
      {:ok, state}
    end
  end
end
