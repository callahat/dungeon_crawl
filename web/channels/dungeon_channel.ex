defmodule DungeonCrawl.DungeonChannel do
  use DungeonCrawl.Web, :channel

  def join("dungeons:" <> dungeon_id, _payload, socket) do
    dungeon_id = String.to_integer(dungeon_id)
    dungeon = Repo.get(DungeonCrawl.Dungeon, dungeon_id)

    {:ok, %{dungeon: dungeon}, assign(socket, :dungeon_id, dungeon_id)}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (dungeon:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end
end
