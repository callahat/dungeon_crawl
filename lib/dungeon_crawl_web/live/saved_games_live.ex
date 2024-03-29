defmodule DungeonCrawlWeb.SavedGamesLive do
  # In Phoenix v1.6+ apps, the line below should be: use MyAppWeb, :live_view
  use DungeonCrawl.Web, :live_view

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Games
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Scores

  def render(assigns) do
    DungeonCrawlWeb.DungeonView.render("saved_games_live.html", assigns)
  end

  def mount(_params, %{"user_id_hash" => user_id_hash, "controller_csrf" => controller_csrf} = _session, socket) do
    {:ok, _assign_stuff(socket, user_id_hash, controller_csrf)}
  end

  def handle_event("focus" <> dungeon_id, _params, socket) do
    {:noreply, _assign_focused_dungeon(socket, dungeon_id)}
  end

  def handle_event("unfocus", _params, socket) do
    {:noreply, _assign_focused_dungeon(socket, nil)}
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

  defp _assign_stuff(socket, user_id_hash, controller_csrf) do
    socket
    |> assign(:user_id_hash, user_id_hash)
    |> assign(:controller_csrf, controller_csrf)
    |> assign(:dungeon, nil)
    |> _assign_dungeons()
  end

  defp _assign_dungeons(socket) do
    dungeons = Dungeons.list_active_dungeons(%{has_saves: true}, socket.assigns.user_id_hash)

    assign(socket, :dungeons, dungeons)
  end

  defp _assign_focused_dungeon(socket, nil), do: assign(socket, :dungeon, nil)

  defp _assign_focused_dungeon(socket, dungeon_id) do
    dungeon = Dungeons.get_dungeon(dungeon_id)
              |> Repo.preload([:user, :levels, [public_dungeon_instances: :locations]])
    author_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"
    saves = Repo.preload(dungeon, :saves).saves
            |> Enum.filter(fn(save) -> save.user_id_hash == socket.assigns.user_id_hash end)

    scores = Scores.list_new_scores(dungeon.id, 10)

    assign(socket, :scores, scores)
    |> assign(:author_name, author_name)
    |> assign(:dungeon, dungeon)
    |> assign(:saves, saves)
  end

  defp _update_dungeon_field_and_reply(socket, line_identifier, field, value) do
    dungeons =
      Enum.map(socket.assigns.dungeons, fn dungeon ->
        if dungeon.line_identifier == line_identifier,
           do: %{ dungeon | field => value },
           else: dungeon
      end)

    {:noreply, assign(socket, :dungeons, dungeons)}
  end
end
