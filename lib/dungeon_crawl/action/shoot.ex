defmodule DungeonCrawl.Action.Shoot do
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Player.Location

  @doc """
  Fires a bullet in the given direction. The bullet will spawn on the tile one away from the object
  in the direction, unless that tile is blocking or responds to "SHOT", in which case that tile
  will be sent the "SHOT" message and no bullet will spawn.
  Otherwise, the bullet will walk in given direction until it hits something, or something
  responds to the "SHOT" message.
  """
  def shoot(%Location{} = player_location, direction, %Instances{} = state) do
    player_tile = Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})

    if player_tile.parsed_state[:ammo] && player_tile.parsed_state[:ammo] > 0 do
      {player_tile, state} = Instances.update_map_tile_state(state, player_tile, %{ammo: player_tile.parsed_state[:ammo] -1})
      shoot(player_tile, direction, state)
    else
      {:no_ammo}
    end
  end

  def shoot(%MapTile{} = shooter_map_tile, direction, %Instances{} = state) do
    spawn_tile = Instances.get_map_tile(state, shooter_map_tile, direction)

    cond do
      is_nil(spawn_tile) ->
        # No tile means edge of map or someplace that a bullet cannot be
        {:invalid}

      Map.take(spawn_tile, [:row, :col]) == Map.take(shooter_map_tile, [:row, :col]) ->
        # direction was invalid
        {:invalid}

      spawn_tile.parsed_state[:blocking] || Instances.responds_to_event?(state, spawn_tile, "shot") ->
        {:shot, spawn_tile}

      true ->
        bullet_tile_template = DungeonCrawl.TileTemplates.TileSeeder.bullet_tile()

        # TODO: tile spawning (including player character tile) should probably live somewhere else once a pattern emerges
        bullet = Map.take(spawn_tile, [:map_instance_id, :row, :col])
                 |> Map.merge(%{tile_template_id: bullet_tile_template.id, z_index: spawn_tile.z_index + 1})
                 |> Map.merge(Map.take(bullet_tile_template, [:character, :color, :background_color, :script]))
                 |> Map.put(:state, bullet_tile_template.state <> ", facing: " <> direction)
                 |> DungeonCrawl.DungeonInstances.create_map_tile!()

        # Might also need to add to the program contexts
        {top, state} = Instances.create_map_tile(state, bullet)
        tile = if top, do: DungeonCrawlWeb.SharedView.tile_and_style(top), else: ""
        DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{bullet.map_instance_id}",
                                        "tile_changes",
                                        %{ tiles: [%{row: top.row, col: top.col, rendering: tile}] })
        {:ok, state}
    end
  end
end
