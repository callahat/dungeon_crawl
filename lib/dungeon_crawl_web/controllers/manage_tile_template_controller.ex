defmodule DungeonCrawlWeb.ManageTileTemplateController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

  plug :assign_tile_template when action in [:show, :edit, :update, :delete, :activate, :new_version]
  plug :assigns_tile_template_params when action in [:create, :update]

  def index(conn, _params) do
    tile_templates = TileTemplates.list_tile_templates
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
        |> redirect(to: manage_tile_template_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    tile_template = conn.assigns.tile_template
    owner_name = if tile_template.user_id, do: Repo.preload(tile_template, :user).user.name, else: "<None>"

    render(conn, "show.html", tile_template: tile_template, owner_name: owner_name)
  end

  def edit(conn, %{"id" => id}) do
    tile_template = conn.assigns.tile_template
    changeset = TileTemplates.change_tile_template(tile_template)
    render(conn, "edit.html", tile_template: tile_template, changeset: changeset)
  end

  def update(conn, %{"id" => id, "tile_template" => _tile_template_params}) do
    tile_template = conn.assigns.tile_template

    case TileTemplates.update_tile_template(tile_template, conn.assigns.tile_template_params) do
      {:ok, tile_template} ->
        conn
        |> put_flash(:info, "Tile Template updated successfully.")
        |> redirect(to: manage_tile_template_path(conn, :show, tile_template))
      {:error, changeset} ->
        render(conn, "edit.html", tile_template: tile_template, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    tile_template = conn.assigns.tile_template

    case TileTemplates.delete_tile_template(tile_template) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Tile Template deleted successfully.")
        |> redirect(to: manage_tile_template_path(conn, :index))
    end
  end

  def activate(conn, %{"id" => _id}) do
    tile_template = conn.assigns.tile_template

    if tile_template.previous_version_id, do: TileTemplates.delete_tile_template(TileTemplates.get_tile_template!(tile_template.previous_version_id))

    {:ok, active_tile_template} = TileTemplates.update_tile_template(tile_template, %{active: true})
    conn
    |> put_flash(:info, "Tile template activated successfully.")
    |> redirect(to: manage_tile_template_path(conn, :show, active_tile_template))
  end

  def new_version(conn, %{"id" => _id}) do
    tile_template = conn.assigns.tile_template

    case TileTemplates.create_new_tile_template_version(tile_template) do
      {:ok, new_tile_template_version} ->
        conn
        |> put_flash(:info, "New tile template version created successfully.")
        |> redirect(to: manage_tile_template_path(conn, :show, new_tile_template_version))
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: manage_tile_template_path(conn, :show, tile_template))
    end
  end

  # All tile templates accessible to the admin
  defp assign_tile_template(conn, _opts) do
    tile_template =  TileTemplates.get_tile_template!(conn.params["id"])

    conn
    |> assign(:tile_template, tile_template)
  end

  defp assigns_tile_template_params(conn, _opts) do
    conn
    |> assign(:tile_template_params, conn.params["tile_template"])
# TODO: the below is really for non admins; admins should be able to change whatever.
#              Map.take(conn.params["tile_template"],
#                       ["name", "character", "description", "color", "background_color", "responders","version","active","public"]))
  end
end
