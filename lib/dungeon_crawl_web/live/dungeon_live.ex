defmodule DungeonCrawlWeb.DungeonLive do
  # In Phoenix v1.6+ apps, the line below should be: use MyAppWeb, :live_view
  use DungeonCrawl.Web, :live_view

  alias DungeonCrawl.Account
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.Metadata

  def render(assigns) do
    DungeonCrawlWeb.DungeonView.render("dungeon_live.html", assigns)
  end

  def mount(_params, %{"user_id_hash" => user_id_hash} = _session, socket) do
    {:ok, _assign_stuff(socket, user_id_hash)}
  end

  def handle_event("focus" <> dungeon_id, _params, socket) do
    {:noreply, _assign_focused_dungeon(socket, dungeon_id)}
  end

  def handle_event("search", %{"search" => filters}, socket) do
    changeset = _filter_changeset(filters)

    socket = _assign_dungeons(socket, changeset.changes)
             |> assign(:changeset, changeset)
    {:noreply, socket}
  end

  def handle_event("favorite_" <> line_identifier, _params, socket) do
    Metadata.favorite(line_identifier, socket.assigns.user_id_hash)

    _update_dungeon_field_and_reply(socket, line_identifier, :favorited, true)
  end

  def handle_event("unfavorite_" <> line_identifier, _params, socket) do
    Metadata.unfavorite(line_identifier, socket.assigns.user_id_hash)

    _update_dungeon_field_and_reply(socket, line_identifier, :favorited, false)
  end

  def handle_event("pin_" <> line_identifier, _params, socket) do
    Metadata.pin(line_identifier)

    _update_dungeon_field_and_reply(socket, line_identifier, :pinned, true)
  end

  def handle_event("unpin_" <> line_identifier, _params, socket) do
    Metadata.unpin(line_identifier)

    _update_dungeon_field_and_reply(socket, line_identifier, :pinned, false)
  end

  defp _update_dungeon_field_and_reply(socket, line_identifier, field, value) do
    line_identifier = String.to_integer(line_identifier)

    dungeons =
      Enum.map(socket.assigns.dungeons, fn dungeon ->
        if dungeon.line_identifier == line_identifier,
           do: %{ dungeon | field => value },
           else: dungeon
      end)

    {:noreply, assign(socket, :dungeons, dungeons)}
  end

  defp _assign_stuff(socket, user_id_hash) do
    user = Account.get_by_user_id_hash(user_id_hash)

    socket
    |> assign(:user_id_hash, user_id_hash)
    |> assign(:is_user, !!user)
    |> assign(:is_admin, user && user.is_admin)
    |> assign(:dungeon, nil)
    |> _assign_dungeons(%{})
    |> _assign_changeset()
  end

  defp _assign_dungeons(socket, filter_params) do
    dungeons = Dungeons.list_active_dungeons(filter_params, socket.assigns.user_id_hash)

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
