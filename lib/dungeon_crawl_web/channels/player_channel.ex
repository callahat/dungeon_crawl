defmodule DungeonCrawlWeb.PlayerChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player

  def join("players:" <> location_id, _payload, socket) do
    instance_id = String.to_integer(location_id)

    {:ok, %{location_id: location_id}, assign(socket, :location_id, location_id)}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
end
