defmodule DungeonCrawlWeb.DungeonMapControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  @create_attrs %{name: "some name", height: 40, width: 80}
  @update_attrs %{name: "new name", height: 40, width: 40}
  @invalid_attrs %{height: 1}
  @tile_attrs %{"background_color" => "",
                "character" => " ",
                "col" => "42",
                "color" => "",
                "row" => "8",
                "script" => "",
                "state" => "",
                "tile_name" => "",
                "z_index" => "2"}

  def fixture(:map_set, user_id) do
    insert_map_set(%{user_id: user_id, active: false})
  end

  def fixture(:dungeon, user_id) do
    map_set = fixture(:map_set, user_id)
    {:ok, dungeon} = Dungeons.create_map(Map.merge(@create_attrs, %{user_id: user_id, map_set_id: map_set.id}))
    space = insert_tile_template(%{active: true})
    Dungeons.create_map_tile(%{dungeon_id: dungeon.id, row: 1, col: 1, character: ".", tile_template_id: space.id})
    Dungeons.set_spawn_locations(dungeon.id, [{1,1,}])
    dungeon
  end

  # Without registered user
  describe "new dungeon without a registered user" do
    setup [:create_map_set]

    test "redirects", %{conn: conn, map_set: map_set} do
      conn = get conn, dungeon_map_path(conn, :new, map_set.id)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "create dungeon without a registered user" do
    setup [:create_map_set]

    test "redirects", %{conn: conn, map_set: map_set} do
      conn = post conn, dungeon_map_path(conn, :create, map_set.id), map: @create_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "edit dungeon without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = get conn, dungeon_map_path(conn, :edit, dungeon.map_set_id, dungeon)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "update dungeon without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = put conn, dungeon_map_path(conn, :update, dungeon.map_set_id, dungeon), map: @update_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "validate_map_tile" do
    setup [:create_user, :create_dungeon]

    test "returns empty array of errors when its all good", %{conn: conn, dungeon: dungeon} do
      conn = post conn, dungeon_map_path(conn, :validate_map_tile, dungeon.map_set_id, dungeon), map_tile: @tile_attrs
      assert json_response(conn, 200) == %{"errors" => []}
    end

    test "returns array of validation errors when there are problems", %{conn: conn, dungeon: dungeon} do
      conn = post conn,
                  dungeon_map_path(conn, :validate_map_tile, dungeon.map_set_id, dungeon),
                  map_tile: Map.merge(@tile_attrs, %{"character" => "toobig", "state" => "derp"})
      assert json_response(conn, 200) == %{"errors" => [%{"detail" => "Error parsing around: derp", "field" => "state"},
                                                        %{"detail" => "should be at most 1 character(s)", "field" => "character"}]}
    end
  end

  describe "map edge without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = get conn, dungeon_map_path(conn, :map_edge, dungeon.map_set_id), edge: "north"
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "delete dungeon without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = delete conn, dungeon_map_path(conn, :delete, dungeon.map_set_id, dungeon)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end
  # /Without registered user

  describe "with a registered user but edit dungeons is disabled" do
    setup [:create_user, :create_dungeon]

    test "lists all map set", %{conn: conn, dungeon: dungeon} do
      Admin.update_setting(%{non_admin_dungeons_enabled: false})
      conn = get conn, dungeon_map_path(conn, :edit, dungeon.map_set_id, dungeon)
      assert redirected_to(conn) == crawler_path(conn, :show)
    end
  end

  describe "with a registered admin user but edit dungeons is disabled" do
    setup [:create_admin, :create_dungeon]

    test "lists all dungeons", %{conn: conn, dungeon: dungeon} do
      Admin.update_setting(%{non_admin_dungeons_enabled: false})
      conn = get conn, dungeon_map_path(conn, :edit, dungeon.map_set_id, dungeon)
      assert html_response(conn, 200) =~ "Edit dungeon"
    end
  end

  # With a registered user
  describe "new dungeon with a registered user" do
    setup [:create_user, :create_map_set]

    test "renders form", %{conn: conn, map_set: map_set} do
      conn = get conn, dungeon_map_path(conn, :new, map_set.id)
      assert html_response(conn, 200) =~ "New dungeon"
    end
  end

  describe "create dungeon with a registered user" do
    setup [:create_user, :create_map_set]

    test "redirects to show when data is valid", %{conn: conn, map_set: map_set} do
      conn = post conn, dungeon_map_path(conn, :create, map_set.id), map: @create_attrs

      assert %{id: id} = redirected_params(conn)
      assert "#{map_set.id}" == id
      assert redirected_to(conn) == dungeon_path(conn, :show, id)
    end

    test "renders errors when data is invalid", %{conn: conn, map_set: map_set} do
      conn = post conn, dungeon_map_path(conn, :create, map_set.id), map: @invalid_attrs
      assert html_response(conn, 200) =~ "New dungeon"
    end
  end

  describe "edit dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "renders form for editing chosen dungeon", %{conn: conn, dungeon: dungeon} do
      conn = get conn, dungeon_map_path(conn, :edit, Repo.preload(dungeon, :map_set).map_set, dungeon)
      assert html_response(conn, 200) =~ "Edit dungeon"
    end

    test "cannot edit active dungeon", %{conn: conn, dungeon: dungeon} do
      {:ok, _map_set} = Dungeons.update_map_set(Repo.preload(dungeon, :map_set).map_set, %{active: true})
      conn = get conn, dungeon_map_path(conn, :edit, dungeon.map_set_id, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon.map_set_id)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
    end

    test "dungeon is in a map set belonging to someone else", %{conn: conn, dungeon: dungeon} do
      other_user = insert_user()
      {:ok, _map_set} = Dungeons.update_map_set(Repo.preload(dungeon, :map_set).map_set, %{user_id: other_user.id})
      conn = get conn, dungeon_map_path(conn, :edit, dungeon.map_set_id, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "dungeon is for a different map set", %{conn: conn, dungeon: dungeon} do
      other_dungeon = insert_autogenerated_dungeon()
      conn = get conn, dungeon_map_path(conn, :edit, dungeon.map_set_id, other_dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "gracefully handles bad dungeon id", %{conn: conn, dungeon: dungeon} do
      conn = get conn, dungeon_map_path(conn, :edit, dungeon.map_set_id, "foo")
      assert redirected_to(conn) == dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end
  end

  describe "update dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "redirects when data is valid", %{conn: conn, dungeon: dungeon} do
      tile_template = insert_tile_template(%{character: "X", color: "white", background_color: "blue"})
      dmt_attrs = Map.take(Dungeons.get_map_tile(dungeon.id, 1, 1), [:dungeon_id, :row, :col, :tile_template_id, :character, :color, :background_color])
      {:ok, other_tile} = Dungeons.create_map_tile(Map.put(dmt_attrs, :z_index, -1))

      tile_data = %{tile_changes: "[{\"row\": 1, \"col\": 1, \"z_index\": 0, \"tile_template_id\": #{tile_template.id}, \"color\": \"red\"}]",
                    tile_additions: "[{\"row\": 1, \"col\": 1, \"z_index\": 1, \"tile_template_id\": #{tile_template.id}, \"color\": \"blue\"},{\"row\": 1, \"col\": 2, \"z_index\": 1, \"character\": \"#{tile_template.character}\", \"color\": \"gold\", \"tile_template_id\": #{tile_template.id + 30}}]",
                    tile_deletions: "[{\"row\": 0, \"col\": 1, \"z_index\": 0}]",
                    spawn_tiles: "[[4,1],[4,2],[4,3],[500,500]]"}

      conn = put conn, dungeon_map_path(conn, :update, dungeon.map_set_id, dungeon),
                   map: Elixir.Map.merge(@update_attrs, tile_data)

      assert Dungeons.get_map_tile(dungeon.id, 1, 1, 0).character == tile_template.character
      refute Dungeons.get_map_tile(dungeon.id, 1, 1, 0).color == tile_template.color
      assert Dungeons.get_map_tile(dungeon.id, 1, 1, 0).color == "red"
      assert Dungeons.get_map_tile(dungeon.id, 1, 1, 0).background_color == tile_template.background_color

      assert Dungeons.get_map_tile(dungeon.id, 1, 1, -1).character == other_tile.character
      assert Dungeons.get_map_tile(dungeon.id, 1, 1, -1).color == other_tile.color
      assert Dungeons.get_map_tile(dungeon.id, 1, 1, -1).background_color == other_tile.background_color

      assert Dungeons.get_map_tile(dungeon.id, 1, 1, 1).character == tile_template.character
      assert Dungeons.get_map_tile(dungeon.id, 1, 1, 1).color == "blue"
      assert Dungeons.get_map_tile(dungeon.id, 1, 1, 1).background_color == tile_template.background_color

      assert tile_without_valid_template = Dungeons.get_map_tile(dungeon.id, 1, 2, 1)
      assert tile_without_valid_template.character == tile_template.character
      assert tile_without_valid_template.color == "gold"

      refute Dungeons.get_map_tile(dungeon.id, 0, 1, 1)

      spawn_locations = DungeonCrawl.Repo.preload(dungeon, :spawn_locations).spawn_locations
      assert [%{row: 4, col: 1}, %{row: 4, col: 2}, %{row: 4, col: 3}] = spawn_locations

      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon.map_set_id)
    end

    test "renders errors when data is invalid", %{conn: conn, dungeon: dungeon} do
      conn = put conn, dungeon_map_path(conn, :update, dungeon.map_set_id, dungeon), map: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit dungeon"
    end

    test "cannot update active dungeon", %{conn: conn, dungeon: dungeon} do
      {:ok, _map_set} = Dungeons.update_map_set(Repo.preload(dungeon, :map_set).map_set, %{active: true})
      conn = put conn, dungeon_map_path(conn, :update, dungeon.map_set_id, dungeon), map: @update_attrs
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon.map_set_id)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
    end
  end

  describe "delete dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "deletes the dungeon", %{conn: conn, dungeon: dungeon} do
      conn = delete conn, dungeon_map_path(conn, :delete, dungeon.map_set_id, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon.map_set_id)
      refute Repo.get(Dungeons.Map, dungeon.id)
    end
  end

  describe "map edge with a registered user" do
    setup [:create_user, :create_dungeon]

    test "gets the adjacent edge tiles", %{conn: conn, dungeon: dungeon} do
      other_dungeon = insert_autogenerated_dungeon(%{number: 2, map_set_id: dungeon.map_set_id, number_east: 1})
      expected_json = Enum.map(0..4, fn i -> %{"html" => "<div>#</div>", "id" => "east_#{ i }"} end) ++
                      Enum.map(5..20, fn i -> %{"html" => "<div> </div>", "id" => "east_#{ i }"} end)
      got_conn = get conn, dungeon_map_path(conn, :map_edge, other_dungeon.map_set_id, edge: "east", level_number: other_dungeon.number)
      assert Enum.sort(json_response(got_conn, 200), fn a,b -> a["id"] < b["id"] end)  ==
             Enum.sort(expected_json, fn a,b -> a["id"] < b["id"] end)

      got_conn = get conn, dungeon_map_path(conn, :map_edge, other_dungeon.map_set_id, edge: "north", level_number: dungeon.number)
      assert json_response(got_conn, 200) == []
    end
  end
  # /With a registered user

  defp create_map_set(opts) do
    map_set = fixture(:map_set, (opts.conn.assigns[:current_user] || insert_user(%{username: "CSwaggins"})).id )
    {:ok, conn: opts.conn, map_set: map_set}
  end

  defp create_dungeon(opts) do
    dungeon = fixture(:dungeon, (opts.conn.assigns[:current_user] || insert_user(%{username: "CSwaggins"})).id )
    {:ok, conn: opts.conn, dungeon: dungeon}
  end

  defp create_user(_) do
    user = insert_user(%{username: "CSwaggins"})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end

  defp create_admin(_) do
    user = insert_user(%{username: "CSwaggins", is_admin: true})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end
end
