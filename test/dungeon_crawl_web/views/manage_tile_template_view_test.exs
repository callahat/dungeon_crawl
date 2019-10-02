defmodule DungeonCrawlWeb.ManageTileTemplateViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawlWeb.ManageTileTemplateView

  test "activate_or_new_version_button/2 renders activate if tile_template inactive", %{conn: conn} do
    tile_template = insert_tile_template(%{active: false})
    assert Regex.match?(~r{Activate}, inspect(ManageTileTemplateView.activate_or_new_version_button(conn, tile_template)))
  end

  test "activate_or_new_version_button/2 renders nothing if a new version already exists", %{conn: conn} do
    tile_template = insert_tile_template(%{active: true})
    _new_version = insert_tile_template(%{previous_version_id: tile_template.id})
    refute ManageTileTemplateView.activate_or_new_version_button(conn, tile_template)
  end

  test "activate_or_new_version_button/2 renders new_version if dungeon active", %{conn: conn} do
    tile_template = insert_tile_template(%{active: true})
    assert Regex.match?(~r{New Version}, inspect(ManageTileTemplateView.activate_or_new_version_button(conn, tile_template)))
  end

  test "error_pre_tag/2 is like the error_tag, but uses a pre tag instead of default span" do
    {:error, changeset} = DungeonCrawl.TileTemplates.create_tile_template(%{script: "#IF @bob, NOLABLE"})
    assert Phoenix.HTML.safe_to_string(ManageTileTemplateView.error_pre_tag(changeset, :script)) ==
           "<pre class=\"help-block\">Line 1: IF command references nonexistant label `NOLABLE`</pre>"
  end
end
