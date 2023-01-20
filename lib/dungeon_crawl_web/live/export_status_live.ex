defmodule DungeonCrawlWeb.ExportStatusLive do
  # In Phoenix v1.6+ apps, the line below should be: use MyAppWeb, :live_view
  use DungeonCrawl.Web, :live_view

  alias DungeonCrawl.Account
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Shipping

  alias DungeonCrawlWeb.Endpoint

  def render(assigns) do
    DungeonCrawlWeb.Editor.DungeonView.render("export_live.html", assigns)
  end

  def mount(_params, %{"user_id_hash" => user_id_hash} = _session, socket) do
    user = Account.get_by_user_id_hash(user_id_hash)

    if user.is_admin do
      DungeonCrawlWeb.Endpoint.subscribe("export_status")
    else
      DungeonCrawlWeb.Endpoint.subscribe("export_status_#{user.id}")
    end

    {:ok, _assign_stuff(socket, user)}
  end

  def handle_event("delete" <> export_id, _params, socket) do
    export = Shipping.get_export!(export_id)

    if export.user_id == socket.assigns.user_id || socket.assigns.is_admin do
      Shipping.delete_export(export)
      _broadcast_status(export.user_id)
      {:noreply, put_flash(_assign_exports(socket), :info, "Deleted export.")}
    else
      {:noreply, put_flash(_assign_exports(socket), :error, "Could not delete export.")}
    end
  end

  def handle_info(%{event: "error"}, socket) do
    {:noreply, put_flash(_assign_exports(socket), :error, "Something went wrong.")}
  end

  def handle_info(_event, socket) do
    {:noreply, _assign_exports(socket)}
  end

  defp _assign_stuff(socket, user) do
    socket
    |> assign(:user_id, user.id)
    |> assign(:user_id_hash, user.user_id_hash)
    |> assign(:is_admin, user.is_admin)
    |> _assign_exports()
  end

  defp _assign_exports(socket) do
    exports = if socket.assigns.is_admin,
                 do: Repo.preload(Shipping.list_dungeon_exports(), :user),
                 else: Shipping.list_dungeon_exports(socket.assigns.user_id)

    assign(socket, :exports, exports)
  end

  defp _broadcast_status(user_id) do
    Endpoint.broadcast("export_status_#{user_id}", "refresh_status", nil)
    Endpoint.broadcast("export_status", "refresh_status", nil)
  end
end
