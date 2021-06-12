defmodule DungeonCrawlWeb.TileShortlistControllerTest do
  use DungeonCrawlWeb.ConnCase

  @create_attrs %{name: "ampersand", character: "&", state: "flag: true", script: "#end\n:touch\nHEY", color: "green"}
  @invalid_attrs %{character: "XXX", state: "derp", color: "red", script: "#alsoderp"}

  # Without registered user
  describe "add an item to the shortlist without a registered user" do
    test "redirects", %{conn: conn} do
      conn = post conn, tile_shortlist_path(conn, :create), tile_shortlist: @create_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "validate_tile" do
    setup [:create_user]

    test "returns empty array of errors when its all good", %{conn: conn} do
      conn = post conn, tile_shortlist_path(conn, :create), tile_shortlist: @create_attrs
      assert %{"attr_hash" => "KC5pOg+1FJk79NA2U7xf83HM8t7iG9SuYuD5lczePX0=",
               "tile_pre" => _tile_pre,
               "tile_shortlist" => %{"animate_background_colors" => nil,
                                     "animate_characters" => nil,
                                     "animate_colors" => nil,
                                     "animate_period" => nil,
                                     "animate_random" => nil,
                                     "background_color" => nil,
                                     "character" => "&",
                                     "color" => "green",
                                     "description" => nil,
                                     "name" => "ampersand",
                                     "script" => "#end\n:touch\nHEY",
                                     "slug" => nil,
                                     "state" => "flag: true",
                                     "tile_template_id" => nil}} = json_response(conn, 200)
    end

    test "returns array of validation errors when there are problems", %{conn: conn} do
      conn = post conn,
                  tile_shortlist_path(conn, :create),
                  tile_shortlist: @invalid_attrs
      assert json_response(conn, 200) == %{"errors" => [%{"detail" => "Unknown command: `alsoderp` - near line 1", "field" => "script"},
                                                        %{"detail" => "Error parsing around: derp", "field" => "state"},
                                                        %{"detail" => "should be at most 1 character(s)", "field" => "character"}]
                                         }
    end
  end

  defp create_user(_) do
    user = insert_user(%{username: "CSwaggins"})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end
end
