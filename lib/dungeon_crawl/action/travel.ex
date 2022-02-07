defmodule DungeonCrawl.Action.Travel do
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.DungeonProcess
  alias DungeonCrawl.DungeonProcesses.DungeonRegistry
  alias DungeonCrawl.DungeonProcesses.Player
  alias DungeonCrawl.DungeonProcesses.Registrar
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonGeneration.InfiniteDungeon
  alias DungeonCrawl.Player.Location

  @moduledoc """
  Handles when a player moves from level to level in a dungeon.
  """

  @doc """
  Moves from one level to another. The player characters tile will be removed from the source
  instance and put into the target instance. The location in the target instance will be one of
  the spawn tiles (if any exist on the target level), otherwise the location will be choosen at random
  from a floor space.
  """
  def passage(%Location{} = player_location, passage, level_number, %Levels{} = state) do
    target_level = DungeonInstances.get_level(state.dungeon_instance_id, level_number)

    _passage(player_location, passage, target_level, state)
  end

  defp _passage(player_location, passage, target_level, state, adjacent_level \\ false) do
    player_tile = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
    cond do
      is_nil(target_level)->
        {:ok, state}

      player_tile.level_instance_id == target_level.id ->
        {_player_tile, state} = Player.place(state, player_tile, player_location, passage)
        {:ok, state}

      true ->
        {:ok, dest_instance} = Registrar.instance_process(target_level.dungeon_instance_id, target_level.number)

        Task.async fn ->
          LevelProcess.run_with(dest_instance, fn (other_instance_state) ->
            {updated_tile, other_instance_state} = Player.place(other_instance_state, player_tile, player_location, passage)

            level_table = DungeonCrawlWeb.SharedView.level_as_table(other_instance_state, target_level.height, target_level.width)
            player_coord_id = "#{updated_tile.row}_#{updated_tile.col}"
            fade_overlay_table = unless _no_overlay?(other_instance_state.state_values, adjacent_level),
                                   do: DungeonCrawlWeb.SharedView.fade_overlay_table(target_level.height, target_level.width, player_coord_id)
            DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                               "change_level",
                                               %{level_number: target_level.number,
                                                 level_owner_id: target_level.player_location_id,
                                                 level_render: level_table,
                                                 fade_overlay: fade_overlay_table}
            DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                               "stat_update",
                                               %{stats: Player.current_stats(other_instance_state, updated_tile)}

            DungeonInstances.update_tiles([Tile.changeset(player_tile, Elixir.Map.take(updated_tile, [:level_instance_id, :row, :col, :z_index]))])

            {:ok, other_instance_state}
          end)
        end

        _autogenerated_dungeon_hook(target_level, player_location.id, state)

        {_, state} = Levels.delete_tile(state, player_tile, false)

        {:ok, state}
    end
  end

  defp _autogenerated_dungeon_hook(target_level, player_location_id, state) do
    # This will do nothing if it is not an autogenerated dungeon, otherwise if the player moves
    # to the top existing level, a level will be generated above that so the player can continue, forever.
    {:ok, dungeon_process} = DungeonRegistry.lookup_or_create(DungeonInstanceRegistry, state.dungeon_instance_id)
    %{dungeon: dungeon, dungeon_instance: dungeon_instance} = DungeonProcess.get_state(dungeon_process)

    if dungeon.autogenerated && (target_level.number - state.number) == 1 do
      DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location_id}",
                                         "message",
                                         %{message: "*** Now on level #{target_level.number}"}

      {:ok, %{level: next_level}} = InfiniteDungeon.generate_next_level(dungeon)
      {:ok, level_header} = DungeonInstances.create_level_header(next_level, dungeon_instance.id)
      {:ok, %{level: _level}} = DungeonInstances.create_level(next_level, level_header.id, dungeon_instance.id)

      Dungeons.get_level(dungeon.id, state.number)
      |> Dungeons.delete_level()
    end
  end

  defp _no_overlay?(instance_state_values, adjacent_level) do
    Enum.member?(["fog", "dark"], instance_state_values[:visibility]) or
      instance_state_values[:fade_overlay] == "off" or
      (Enum.member?(["passages", nil], instance_state_values[:fade_overlay]) and adjacent_level)
  end
end
