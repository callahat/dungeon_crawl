defmodule DungeonCrawlWeb.PlayerChannel do
  use DungeonCrawl.Web, :channel

  def join("players:" <> location_id, _payload, socket) do
    # TODO: verify the player joining the channel is the player

    {:ok, %{location_id: location_id}, assign(socket, :location_id, location_id)}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
end
