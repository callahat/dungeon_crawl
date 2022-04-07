defmodule DungeonCrawlWeb.ImportStatusLive do
  # In Phoenix v1.6+ apps, the line below should be: use MyAppWeb, :live_view
  use DungeonCrawl.Web, :live_view

  alias DungeonCrawl.Account
  alias DungeonCrawl.Account.User
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Shipping
  alias DungeonCrawl.Shipping.{DockWorker, Json}

  def render(assigns) do
    DungeonCrawlWeb.DungeonView.render("import_live.html", assigns)
  end

  def mount(_params, %{"user_id_hash" => user_id_hash} = session, socket) do
    user = Account.get_by_user_id_hash(user_id_hash)
    DungeonCrawlWeb.Endpoint.subscribe("import_status_#{user.id}")
    {:ok, _assign_stuff(socket, user)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload", params, socket) do
    uploaded_file =
      consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->

        import = File.read!(path)
                 |> Json.decode!()

        dungeon_import = Shipping.create_import!(%{
          data: Json.encode!(import),
          user_id: socket.assigns.user_id,
          file_name: entry.client_name,
          line_identifier: params["line_identifier"],
          importing: true
        })

        DockWorker.import(dungeon_import)

        {:ok, "junk"}
      end)

    {:noreply, socket}
  rescue
    Jason.DecodeError -> {:noreply, put_flash(socket, :error, "Import failed; could not parse file")}
    e in Ecto.InvalidChangesetError ->  {:noreply, put_flash(socket, :error, "Import failed; bad input")} # _humanize_errors(e.changeset))
    e -> {:noreply, put_flash(socket, :error, "Import failed; #{ Exception.format(:error, e) }")}
  end

  def handle_event("delete" <> import_id, _params, socket) do
    import = Shipping.get_import!(import_id)

    if import.user_id == socker.user_id do #|| conn.assigns.current_user.is_admin
      Shipping.delete_import(import)
      {:noreply, put_flash(_assign_imports(socket), :info, "Deleted import.")}
    else
      {:noreply, put_flash(_assign_imports(socket), :error, "Could not delete import.")}
    end
  end

  def handle_info(_event, socket) do
    {:noreply, _assign_imports(socket)}
  end

  defp _assign_stuff(socket, user) do
    is_admin = user.is_admin
    user_id_hash = user.user_id_hash
    dungeons = Dungeons.list_dungeons_by_lines(user)
               |> Enum.map(fn dungeon ->
                  {"#{dungeon.name} (id: #{dungeon.id}) v #{dungeon.version} #{unless dungeon.active, do: "(inactive)"}",
                    dungeon.line_identifier}
                end)
    socket
    |> assign(:user_id, user.id)
    |> assign(:user_id_hash, user.user_id_hash)
    |> assign(:dungeons, dungeons)
    |> assign(:is_admin, is_admin)
    |> _assign_imports()
    |> assign(:uploaded_files, [])
    |> allow_upload(:file, accept: ~w(.json))
  end

  # TOOD: let the admin see all imports, have another pubsub channel for all import/export status changes
  defp _assign_imports(socket) do
    imports = if socket.assigns.is_admin,
                 do: Repo.preload(Shipping.list_dungeon_imports(), :user),
                 else: Shipping.list_dungeon_imports(socket.assigns.user_id)

    assign(socket, :imports, imports)
  end
end