defmodule DungeonCrawlWeb.PlayerChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player
  alias DungeonCrawl.Repo
  alias DungeonCrawl.DungeonProcesses.{LevelProcess, Registrar}
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance

  def join("players:" <> location_id, _payload, socket) do
    user_id_hash = socket.assigns.user_id_hash

    with location when not is_nil(location) <- Repo.preload(Player.get_location(%{id: location_id}), [tile: :level]),
         true <- not is_nil(location.tile),
         %{user_id_hash: ^user_id_hash} <- location do
      socket = socket
               |> assign(:location_id, location_id)
               |> assign(:level_instance_id, location.tile.level_instance_id)
               |> assign(:dungeon_instance_id, location.tile.level.dungeon_instance_id)
               |> assign(:player_tile_id, location.tile.id)

      {:ok, %{location_id: location_id}, socket}
    else
      %{user_id_hash: _} ->
        {:error, %{message: "Could not join channel"}}
      _ ->
        {:error, %{message: "Not found", reload: true}}
    end
  end

  def handle_in("refresh_level", _, socket) do
    {:ok, instance_process} = Registrar.instance_process(socket.assigns.dungeon_instance_id, socket.assigns.level_instance_id)
    state = LevelProcess.get_state(instance_process)

    level_table = DungeonCrawlWeb.SharedView.level_as_table(state, state.state_values[:rows], state.state_values[:cols])
    DungeonCrawlWeb.Endpoint.broadcast "players:#{socket.assigns.location_id}",
                                       "change_level",
                                       %{level_id: socket.assigns.level_instance_id, level_render: level_table}
    DungeonCrawlWeb.Endpoint.broadcast "players:#{socket.assigns.location_id}",
                                       "stat_update",
                                       %{stats: PlayerInstance.current_stats(state, %{id: socket.assigns.player_tile_id})}

    {:noreply, socket}
  end

  def handle_in("update_visible", _, socket) do
    case Registrar.instance_process(socket.assigns.dungeon_instance_id, socket.assigns.level_instance_id) do
      {:ok, instance_process} ->
        LevelProcess.run_with(instance_process, fn (state) ->
          {:ok, %{ state | players_visible_coords: Map.delete(state.players_visible_coords, socket.assigns.player_tile_id),
                           players_los_coords: Map.delete(state.players_los_coords, socket.assigns.player_tile_id)}}
        end)
      _ ->
        nil
    end

    {:noreply, socket}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
end
