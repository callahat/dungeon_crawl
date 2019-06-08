defmodule DungeonCrawlWeb.ManageTileTemplateControllerTest do
  use DungeonCrawlWeb.ConnCase

  import Plug.Conn, only: [assign: 3]

  alias DungeonCrawl.TileTemplates.TileTemplate

  @valid_attrs %{name: "A Big X", description: "A big capital X", character: "X", color: "red", background_color: "black"}
  @update_attrs %{color: "puce", character: "█"}
  @invalid_attrs %{name: "", character: "BIG"}

  setup config do
    user = insert_user(%{username: "maxheadroom", is_admin: !config[:not_admin]})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end

  @tag not_admin: true
  test "redirects non admin users", %{conn: conn} do
    conn = get conn, manage_tile_template_path(conn, :index)
    assert redirected_to(conn) == page_path(conn, :index)
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, manage_tile_template_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing tile templates"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, manage_tile_template_path(conn, :new)
    assert html_response(conn, 200) =~ "New tile template"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, manage_tile_template_path(conn, :create), tile_template: @valid_attrs
    assert redirected_to(conn) == manage_tile_template_path(conn, :index)
    new_tile_template = Repo.get_by(TileTemplate, @valid_attrs)
    assert new_tile_template
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, manage_tile_template_path(conn, :create), tile_template: @invalid_attrs
    assert html_response(conn, 200) =~ "New tile template"
  end

  test "shows chosen resource", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = get conn, manage_tile_template_path(conn, :show, target_tile_template)
    assert html_response(conn, 200) =~ "Show tile template"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, manage_tile_template_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = get conn, manage_tile_template_path(conn, :edit, target_tile_template)
    assert html_response(conn, 200) =~ "Edit tile template"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = put conn, manage_tile_template_path(conn, :update, target_tile_template), tile_template: @update_attrs
    assert redirected_to(conn) == manage_tile_template_path(conn, :show, target_tile_template)
    assert Repo.get_by(TileTemplate, Map.merge(@valid_attrs,@update_attrs))
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = put conn, manage_tile_template_path(conn, :update, target_tile_template), tile_template: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit tile template"
  end

  test "deletes chosen resource", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = delete conn, manage_tile_template_path(conn, :delete, target_tile_template)
    assert redirected_to(conn) == manage_tile_template_path(conn, :index)
    refute Repo.get(TileTemplate, target_tile_template.id)
  end

  test "does not delete chosen resource if its in use", %{conn: conn} do
    tile_template = insert_tile_template @valid_attrs
    insert_stubbed_dungeon(%{}, [%{row: 1, col: 1, tile: "!", tile_template_id: tile_template.id}])
    conn = delete conn, manage_tile_template_path(conn, :delete, tile_template)
    assert redirected_to(conn) == manage_tile_template_path(conn, :index)
    assert Repo.get(TileTemplate, tile_template.id)
    assert get_flash(conn, :error) == "Cannot delete a tile template that is in use"
  end
end
