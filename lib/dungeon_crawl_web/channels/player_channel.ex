defmodule DungeonCrawlWeb.PlayerChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player
  alias DungeonCrawl.Repo
  alias DungeonCrawl.DungeonProcesses.{InstanceProcess, MapSets}

  def join("players:" <> location_id, _payload, socket) do
    user_id_hash = socket.assigns.user_id_hash

    with location when not is_nil(location) <- Repo.preload(Player.get_location(%{id: location_id}), [map_tile: :dungeon]),
         true <- not is_nil(location.map_tile),
         %{user_id_hash: ^user_id_hash} <- location do
      socket = socket
               |> assign(:location_id, location_id)
               |> assign(:map_instance_id, location.map_tile.map_instance_id)
               |> assign(:map_set_instance_id, location.map_tile.dungeon.map_set_instance_id)
               |> assign(:player_map_tile_id, location.map_tile.id)

      {:ok, %{location_id: location_id}, socket}
    else
      %{user_id_hash: _} ->
        {:error, %{message: "Could not join channel"}}
      _ ->
        {:error, %{message: "Not found", reload: true}}
    end
  end

  def handle_in("refresh_dungeon", _, socket) do
    {:ok, instance_process} = MapSets.instance_process(socket.assigns.map_set_instance_id, socket.assigns.map_instance_id)
    state = InstanceProcess.get_state(instance_process)

    dungeon_table = DungeonCrawlWeb.SharedView.dungeon_as_table(state, state.state_values[:rows], state.state_values[:cols])
    DungeonCrawlWeb.Endpoint.broadcast "players:#{socket.assigns.location_id}",
                                       "change_dungeon",
                                       %{dungeon_id: socket.assigns.map_instance_id, dungeon_render: dungeon_table}

    {:noreply, socket}
  end

  def handle_in("update_visible", _, socket) do
    {:ok, instance_process} = MapSets.instance_process(socket.assigns.map_set_instance_id, socket.assigns.map_instance_id)

    InstanceProcess.run_with(instance_process, fn (state) ->
      {:ok, %{ state | players_visible_coords: Map.delete(state.players_visible_coords, socket.assigns.player_map_tile_id)}}
    end)

    {:noreply, socket}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
end
