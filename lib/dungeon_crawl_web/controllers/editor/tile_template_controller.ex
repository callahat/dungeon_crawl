defmodule DungeonCrawlWeb.Editor.TileTemplateController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

  plug :authenticate_user
  plug :assign_tile_template when action in [:show, :edit, :update, :delete, :activate, :new_version]
  plug :check_if_active when action in [:edit, :update]
  plug :assigns_tile_template_params when action in [:create, :update]
  plug :strip_user_id_when_invalid when action in [:update]

  def index(conn, params) do
    tile_templates = cond do
                       !conn.assigns.current_user.is_admin || params["list"] == "mine" ->
                         TileTemplates.list_tile_templates(conn.assigns.current_user)
                       params["list"] == "nil" -> TileTemplates.list_tile_templates(:nouser)
                       true                    -> TileTemplates.list_tile_templates
                     end

    render(conn, "index.html", tile_templates: tile_templates)
  end

  def new(conn, _params) do
    changeset = TileTemplates.change_tile_template(%TileTemplate{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"tile_template" => _tile_template_params}) do
    case TileTemplates.create_tile_template(conn.assigns.tile_template_params) do
      {:ok, _tile_template} ->
        conn
        |> put_flash(:info, "Tile Template created successfully.")
        |> redirect(to: Routes.tile_template_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => _id}) do
    tile_template = conn.assigns.tile_template
    owner_name = if tile_template.user_id, do: Repo.preload(tile_template, :user).user.name, else: "<None>"

    render(conn, "show.html", tile_template: tile_template, owner_name: owner_name)
  end

  def edit(conn, %{"id" => _id}) do
    tile_template = conn.assigns.tile_template
    changeset = TileTemplates.change_tile_template(tile_template)
    render(conn, "edit.html", tile_template: tile_template, changeset: changeset)
  end

  def update(conn, %{"id" => _id, "tile_template" => _tile_template_params}) do
    tile_template = conn.assigns.tile_template

    case TileTemplates.update_tile_template(tile_template, conn.assigns.tile_template_params) do
      {:ok, tile_template} ->
        conn
        |> put_flash(:info, "Tile Template updated successfully.")
        |> redirect(to: Routes.tile_template_path(conn, :show, tile_template))
      {:error, changeset} ->
        render(conn, "edit.html", tile_template: tile_template, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => _id}) do
    tile_template = conn.assigns.tile_template

    case TileTemplates.delete_tile_template(tile_template) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Tile Template deleted successfully.")
        |> redirect(to: Routes.tile_template_path(conn, :index))
    end
  end

  def activate(conn, %{"id" => _id}) do
    tile_template = conn.assigns.tile_template

    if tile_template.previous_version_id, do: TileTemplates.delete_tile_template(TileTemplates.get_tile_template!(tile_template.previous_version_id))

    {:ok, active_tile_template} = TileTemplates.update_tile_template(tile_template, %{active: true})
    conn
    |> put_flash(:info, "Tile template activated successfully.")
    |> redirect(to: Routes.tile_template_path(conn, :show, active_tile_template))
  end

  def new_version(conn, %{"id" => _id}) do
    tile_template = conn.assigns.tile_template

    case TileTemplates.create_new_tile_template_version(tile_template) do
      {:ok, new_tile_template_version} ->
        conn
        |> put_flash(:info, "New tile template version created successfully.")
        |> redirect(to: Routes.tile_template_path(conn, :show, new_tile_template_version))
      {:error, _ = %Ecto.Changeset{}} ->
        # Getting here probably if the original is corrupt; ie, invalid script or something.
        conn
        |> put_flash(:error, "Error creating new version.")
        |> redirect(to: Routes.tile_template_path(conn, :show, tile_template))
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.tile_template_path(conn, :show, tile_template))
    end
  end

  defp assign_tile_template(conn, _opts) do
    tile_template =  TileTemplates.get_tile_template!(conn.params["id"])

    if conn.assigns.current_user.is_admin || tile_template.user_id == conn.assigns.current_user.id do
      conn
      |> assign(:tile_template, tile_template)
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: Routes.tile_template_path(conn, :index))
      |> halt()
    end
  end

  defp check_if_active(conn, _opts) do
    if conn.assigns.current_user.is_admin || !conn.assigns.tile_template.active do
      conn
    else
      conn
      |> put_flash(:error, "Cannot edit active tile template")
      |> redirect(to: Routes.tile_template_path(conn, :index))
      |> halt()
    end
  end

  defp assigns_tile_template_params(conn, _opts) do
    filtered_params = cond do
      !conn.assigns.current_user.is_admin ->
        Map.take(conn.params["tile_template"],
                 ["name", "character", "description", "color", "background_color", "public", "state", "script"])
        |> params_with_owner(conn)

      conn.params["self_owned"] == "true" ->
        conn.params["tile_template"]
        |> params_with_owner(conn)

      true ->
        conn.params["tile_template"]
        |> Map.put("user_id", nil)
    end
    
    conn
    |> assign(:tile_template_params, filtered_params)
  end

  defp params_with_owner(params, conn) do
    Map.put(params, "user_id", conn.assigns.current_user.id)
  end

  defp strip_user_id_when_invalid(conn, _opts) do
    if (conn.assigns.tile_template.user_id == nil || conn.assigns.tile_template.user_id == conn.assigns.current_user.id) &&
        conn.assigns.current_user.is_admin do
      assign(conn, :tile_template_params, conn.assigns.tile_template_params)
    else
      assign(conn, :tile_template_params, Map.delete(conn.assigns.tile_template_params, "user_id"))
    end
  end
end
