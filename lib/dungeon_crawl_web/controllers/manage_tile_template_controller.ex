defmodule DungeonCrawlWeb.ManageTileTemplateController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

  def index(conn, _params) do
    tile_templates = TileTemplates.list_tile_templates
    render(conn, "index.html", tile_templates: tile_templates)
  end

  def new(conn, _params) do
    changeset = TileTemplates.change_tile_template(%TileTemplate{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"tile_template" => tile_template_params}) do
    case TileTemplates.create_tile_template(tile_template_params) do
      {:ok, _tile_template} ->
        conn
        |> put_flash(:info, "Tile Template created successfully.")
        |> redirect(to: manage_tile_template_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    tile_template = TileTemplates.get_tile_template!(id)
    render(conn, "show.html", tile_template: tile_template)
  end

  def edit(conn, %{"id" => id}) do
    tile_template = TileTemplates.get_tile_template!(id)
    changeset = TileTemplates.change_tile_template(tile_template)
    render(conn, "edit.html", tile_template: tile_template, changeset: changeset)
  end

  def update(conn, %{"id" => id, "tile_template" => tile_template_params}) do
    tile_template = TileTemplates.get_tile_template!(id)

    case TileTemplates.update_tile_template(tile_template, tile_template_params) do
      {:ok, tile_template} ->
        conn
        |> put_flash(:info, "Tile Template updated successfully.")
        |> redirect(to: manage_tile_template_path(conn, :show, tile_template))
      {:error, changeset} ->
        render(conn, "edit.html", tile_template: tile_template, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    tile_template =  TileTemplates.get_tile_template!(id)

    case TileTemplates.delete_tile_template(tile_template) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Tile Template deleted successfully.")
        |> redirect(to: manage_tile_template_path(conn, :index))
    end
  end
end
