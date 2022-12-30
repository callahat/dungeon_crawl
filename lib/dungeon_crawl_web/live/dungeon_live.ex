defmodule DungeonCrawlWeb.DungeonLive do
  # In Phoenix v1.6+ apps, the line below should be: use MyAppWeb, :live_view
  use DungeonCrawl.Web, :live_view

  alias DungeonCrawl.Account
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeons

  alias DungeonCrawlWeb.Endpoint

  def render(assigns) do
    DungeonCrawlWeb.DungeonView.render("dungeon_live.html", assigns)
  end

  def mount(_params, %{"user_id_hash" => user_id_hash} = _session, socket) do
    DungeonCrawlWeb.Endpoint.subscribe("dungeon_list_#{user_id_hash}")

    {:ok, _assign_stuff(socket, user_id_hash)}
  end

  def handle_event("focus" <> dungeon_id, _params, socket) do

    {:noreply, _assign_focused_dungeon(socket, dungeon_id)}
  end

  def handle_event("search", %{"search" => filters}, socket) do
    IO.puts "here's the originial"
    IO.inspect filters
    IO.inspect Map.keys(socket)
    changeset = _filter_changeset(filters)
    dungeons = Dungeons.list_active_dungeons(changeset.changes, socket.assigns.user_id_hash)
#               |> Enum.map(fn(%{dungeon: dungeon}) -> Repo.preload(dungeon, [:levels, :locations, :dungeon_instances]) end)

    socket = assign(socket, :dungeons, dungeons)
             |> assign(:changeset, changeset)
    {:noreply, socket}
  end

  def handle_info(%{event: "error"}, socket) do
    {:noreply, put_flash(socket, :error, "Something went wrong.")}
  end

  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  defp _assign_stuff(socket, user_id_hash) do
    IO.puts "Assinging suff"
    socket
    |> assign(:user_id_hash, user_id_hash)
    |> assign(:dungeon, nil)
    |> _assign_dungeons(nil)
    |> _assign_changeset()
  end

  defp _assign_dungeons(socket, filter_params) do
    dungeons = Dungeons.list_active_dungeons_with_player_count()
    # might not need this preload anymore
               |> Enum.map(fn(%{dungeon: dungeon}) -> Repo.preload(dungeon, [:levels, :locations, :dungeon_instances]) end)

    assign(socket, :dungeons, dungeons)
  end

  defp _assign_focused_dungeon(socket, dungeon_id) do
    dungeon = Dungeons.get_dungeon(dungeon_id)
              |> Repo.preload([:levels, :locations, :dungeon_instances])

    assign(socket, :dungeon, dungeon)
  end

  defp _assign_changeset(socket) do
    changeset = _filter_changeset()

    assign(socket, :changeset, changeset)
  end

  defp _filter_changeset(data \\ %{}) do
    Ecto.Changeset.change(
      {
        %{name: nil, favorite: false, unplayed: false, not_won: false},
        %{name: :string, favorite: :boolean, unplayed: :boolean, not_won: :boolean}
      },
      %{}
    )
    |> Ecto.Changeset.cast(data, [:name, :favorite, :unplayed, :not_won])
  end
end
