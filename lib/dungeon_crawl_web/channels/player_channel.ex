defmodule DungeonCrawlWeb.PlayerChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player
  alias DungeonCrawl.Repo
  alias DungeonCrawl.DungeonProcesses.{InstanceRegistry, InstanceProcess}

  def join("players:" <> location_id, _payload, socket) do
    # TODO: verify the player joining the channel is the player

    {:ok, %{location_id: location_id}, assign(socket, :location_id, location_id)}
  end

  def handle_in("refresh_dungeon", _, socket) do
    location = Player.get_location(%{id: socket.assigns.location_id})
               |> Repo.preload(:map_tile)
    {:ok, instance_process} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, location.map_tile.map_instance_id)
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
