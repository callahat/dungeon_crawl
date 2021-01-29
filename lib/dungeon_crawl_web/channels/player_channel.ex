defmodule DungeonCrawlWeb.PlayerChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player
  alias DungeonCrawl.Repo
  alias DungeonCrawl.DungeonProcesses.{InstanceRegistry, InstanceProcess, MapSets}

  def join("players:" <> location_id, _payload, socket) do
    # TODO: verify the player joining the channel is the player
    location = Player.get_location(%{id: location_id})
               |> Repo.preload(:map_tile)
    if location && location.map_tile do
      {:ok, %{location_id: location_id}, assign(socket, :location_id, location_id)}
    else
      {:error, %{message: "Not found", reload: true}}
    end
  end

  def handle_in("refresh_dungeon", _, socket) do
    location = Player.get_location(%{id: socket.assigns.location_id})
               |> Repo.preload(map_tile: :dungeon)
    {:ok, instance_registry} = MapSets.instance_registry(location.map_tile.dungeon.map_set_instance_id)
    {:ok, instance_process} = InstanceRegistry.lookup_or_create(instance_registry, location.map_tile.map_instance_id)
    state = InstanceProcess.get_state(instance_process)

    dungeon_table = DungeonCrawlWeb.SharedView.dungeon_as_table(state, state.state_values[:rows], state.state_values[:cols])
    DungeonCrawlWeb.Endpoint.broadcast "players:#{location.id}",
                                       "change_dungeon",
                                       %{dungeon_id: location.map_tile.map_instance_id, dungeon_render: dungeon_table}

    {:noreply, socket}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
end
