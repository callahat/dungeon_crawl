defmodule DungeonCrawl.PlayerChannelTest do
  use DungeonCrawlWeb.ChannelCase

  alias DungeonCrawlWeb.PlayerChannel

  setup do
    {:ok, _, socket} =
      socket(DungeonCrawlWeb.UserSocket, "user_id_hash", %{user_id_hash: "junkhashreal"})
      |> subscribe_and_join(PlayerChannel, "players:12345")

    {:ok, socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push socket, "ping", %{"hello" => "there"}
    assert_reply ref, :ok, %{"hello" => "there"}
  end
end
