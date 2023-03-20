defmodule DungeonCrawlWeb.SavedGamesLive do
  # In Phoenix v1.6+ apps, the line below should be: use MyAppWeb, :live_view
  use DungeonCrawl.Web, :live_view

  alias DungeonCrawl.Account
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
    with save <- Games.get_save(save_id),
         true <- save.user_id_hash == socket.assigns.user_id_hash do
      Games.delete_save(save)
      {:noreply, assign(socket, :dungeon, Repo.preload(socket.assigns.dungeon, :saves, force: true))}
    else
      _ -> {:noreply, socket}
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
              |> Repo.preload([:user, :levels, :saves, [public_dungeon_instances: :locations]])
    author_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"

    scores = Scores.list_new_scores(dungeon.id, 10)

    assign(socket, :scores, scores)
    |> assign(:author_name, author_name)
    |> assign(:dungeon, dungeon)
  end
end
