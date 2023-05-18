defmodule DungeonCrawlWeb.DungeonLive do
  # In Phoenix v1.6+ apps, the line below should be: use MyAppWeb, :live_view
  use DungeonCrawl.Web, :live_view

  alias DungeonCrawl.Account
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.Metadata
  alias DungeonCrawl.Games
  alias DungeonCrawl.Scores

  def render(assigns) do
    DungeonCrawlWeb.DungeonView.render("dungeon_live.html", assigns)
  end

  def mount(_params,
        %{"user_id_hash" => user_id_hash,
          "controller_csrf" => controller_csrf,
          "focus_dungeon_id" => dungeon_id} = _session,
        socket) do
    {:ok, _assign_stuff(socket, user_id_hash, controller_csrf, dungeon_id)}
  end

  def handle_event("focus" <> dungeon_id, _params, socket) do
    {:noreply, _assign_focused_dungeon(socket, dungeon_id)}
  end

  def handle_event("unfocus", _params, socket) do
    {:noreply, _assign_focused_dungeon(socket, nil)}
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

  def handle_event("convert_save_" <> save_id, _params, socket) do
    save = Games.get_save(save_id, socket.assigns.user_id_hash)
    # TODO: hook into the save conversion stuff here
    if save do
#      Games.delete_save(save)
      saves = socket.assigns.saves # |> Enum.reject(fn s -> s.id == save.id end)
      line_identifier = socket.assigns.dungeon.line_identifier

      assign(socket, :saves, saves)
      |> _update_dungeon_field_and_reply(line_identifier, :saved, saves != [])
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_save_" <> save_id, _params, socket) do
    save = Games.get_save(save_id, socket.assigns.user_id_hash)
    if save do
      Games.delete_save(save)
      saves = socket.assigns.saves |> Enum.reject(fn s -> s.id == save.id end)
      line_identifier = socket.assigns.dungeon.line_identifier

      assign(socket, :saves, saves)
      |> _update_dungeon_field_and_reply(line_identifier, :saved, saves != [])
    else
      {:noreply, socket}
    end
  end

  defp _update_dungeon_field_and_reply(socket, line_identifier, field, value) when is_binary(line_identifier),
       do: _update_dungeon_field_and_reply(socket, String.to_integer(line_identifier), field, value)
  defp _update_dungeon_field_and_reply(socket, line_identifier, field, value) do
    dungeons =
      Enum.map(socket.assigns.dungeons, fn dungeon ->
        if dungeon.line_identifier == line_identifier,
           do: %{ dungeon | field => value },
           else: dungeon
      end)

    {:noreply, assign(socket, :dungeons, dungeons)}
  end

  defp _assign_stuff(socket, user_id_hash, controller_csrf, dungeon_id) do
    user = Account.get_by_user_id_hash(user_id_hash)

    socket
    |> assign(:user_id_hash, user_id_hash)
    |> assign(:controller_csrf, controller_csrf)
    |> assign(:is_user, !!user)
    |> assign(:is_admin, user && user.is_admin)
    |> assign(:dungeon, nil)
    |> _assign_focused_dungeon(dungeon_id)
    |> _assign_dungeons(%{})
    |> _assign_changeset()
  end

  defp _assign_dungeons(socket, filter_params) do
    dungeons = Dungeons.list_active_dungeons(filter_params, socket.assigns.user_id_hash)

    dungeon = if socket.assigns.dungeon &&
                   Enum.member?(Enum.map(dungeons, &(&1.id)), socket.assigns.dungeon.id),
                do: socket.assigns.dungeon,
                else: nil

    assign(socket, :dungeons, dungeons)
    |> _assign_focused_dungeon(dungeon)
  end

  defp _assign_focused_dungeon(socket, nil), do: assign(socket, :dungeon, nil)

  defp _assign_focused_dungeon(socket, %{id: dungeon_id}), do: _assign_focused_dungeon(socket, dungeon_id)

  defp _assign_focused_dungeon(socket, dungeon_id) do
    dungeon = Dungeons.get_dungeon(dungeon_id)
              |> Repo.preload([:user, :levels, [public_dungeon_instances: :locations]])
    author_name = if dungeon.user_id, do: dungeon.user.name, else: "<None>"
    saves = Repo.preload(dungeon, :saves).saves
            |> Enum.filter(fn(save) -> save.user_id_hash == socket.assigns.user_id_hash end)
    old_saves = Games.list_saved_games_on_old_versions(%{dungeon_id: dungeon.id, user_id_hash: socket.assigns.user_id_hash})

    scores = Scores.list_new_scores(dungeon.id, 10)

    assign(socket, :scores, scores)
    |> assign(:author_name, author_name)
    |> assign(:dungeon, dungeon)
    |> assign(:saves, saves)
    |> assign(:old_saves, old_saves)
  end

  defp _assign_changeset(socket) do
    changeset = _filter_changeset()

    assign(socket, :changeset, changeset)
  end

  defp _filter_changeset(data \\ %{}) do
    Ecto.Changeset.change(
      {
        %{name: nil, favorite: false, unplayed: false, not_won: false, existing: false},
        %{name: :string, favorite: :boolean, unplayed: :boolean, not_won: :boolean, existing: :boolean}
      },
      %{}
    )
    |> Ecto.Changeset.cast(data, [:name, :favorite, :unplayed, :not_won, :existing])
  end
end
