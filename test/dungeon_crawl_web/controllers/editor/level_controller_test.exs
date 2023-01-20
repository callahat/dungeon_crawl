defmodule DungeonCrawlWeb.Editor.LevelControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  @create_attrs %{name: "some name", height: 40, width: 80, number_north: 1, generator: "Rooms"}
  @update_attrs %{name: "new name", height: 40, width: 40, number_north: 2}
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

  def fixture(:dungeon, user_id) do
    insert_dungeon(%{user_id: user_id, active: false})
  end

  def fixture(:level, user_id) do
    dungeon = fixture(:dungeon, user_id)
    {:ok, level} = Dungeons.create_level(Map.merge(@create_attrs, %{user_id: user_id, dungeon_id: dungeon.id}))
    space = insert_tile_template(%{active: true})
    Dungeons.create_tile(%{level_id: level.id, row: 1, col: 1, character: ".", tile_template_id: space.id})
    Dungeons.set_spawn_locations(level.id, [{1,1,}])
    level
  end

  # Without registered user
  describe "new level without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = get conn, edit_dungeon_level_path(conn, :new, dungeon.id)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "create level without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = post conn, edit_dungeon_level_path(conn, :create, dungeon.id), level: @create_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "edit level without a registered user" do
    setup [:create_level]

    test "redirects", %{conn: conn, level: level} do
      conn = get conn, edit_dungeon_level_path(conn, :edit, level.dungeon_id, level)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "update level without a registered user" do
    setup [:create_level]

    test "redirects", %{conn: conn, level: level} do
      conn = put conn, edit_dungeon_level_path(conn, :update, level.dungeon_id, level), level: @update_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "validate_tile" do
    setup [:create_user, :create_level]

    test "returns empty array of errors when its all good", %{conn: conn, level: level} do
      conn = post conn, edit_dungeon_level_path(conn, :validate_tile, level.dungeon_id, level), tile: @tile_attrs
      assert json_response(conn, 200) == %{"errors" => [], "tile" => %{"character" => " ", "col" => 42, "row" => 8, "z_index" => 2}}
    end

    test "returns array of validation errors when there are problems", %{conn: conn, level: level} do
      conn = post conn,
                  edit_dungeon_level_path(conn, :validate_tile, level.dungeon_id, level),
                  tile: Map.merge(@tile_attrs, %{"character" => "toobig", "state" => "derp", state_variables: ["foo"], state_values: ["bar"]})
      assert json_response(conn, 200) == %{"errors" => [%{"detail" => "should be at most 1 character(s)", "field" => "character"}],
                                           "tile" => %{"character" => "toobig", "col" => 42, "row" => 8, "state" => "foo: bar", "z_index" => 2}}
    end
  end

  describe "level edge without a registered user" do
    setup [:create_level]

    test "redirects", %{conn: conn, level: level} do
      conn = get conn, edit_dungeon_level_path(conn, :level_edge, level.dungeon_id), edge: "north"
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "delete level without a registered user" do
    setup [:create_level]

    test "redirects", %{conn: conn, level: level} do
      conn = delete conn, edit_dungeon_level_path(conn, :delete, level.dungeon_id, level)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end
  # /Without registered user

  describe "with a registered user but edit dungeons is disabled" do
    setup [:create_user, :create_level]

    test "lists all dungeons", %{conn: conn, level: level} do
      Admin.update_setting(%{non_admin_dungeons_enabled: false})
      conn = get conn, edit_dungeon_level_path(conn, :edit, level.dungeon_id, level)
      assert redirected_to(conn) == dungeon_path(conn, :index)
    end
  end

  describe "with a registered admin user but edit levels is disabled" do
    setup [:create_admin, :create_level]

    test "lists all levels", %{conn: conn, level: level} do
      Admin.update_setting(%{non_admin_dungeons_enabled: false})
      conn = get conn, edit_dungeon_level_path(conn, :edit, level.dungeon_id, level)
      assert html_response(conn, 200) =~ "Edit level"
    end
  end

  # With a registered user
  describe "new level with a registered user" do
    setup [:create_user, :create_dungeon]

    test "renders form", %{conn: conn, dungeon: dungeon} do
      conn = get conn, edit_dungeon_level_path(conn, :new, dungeon.id)
      assert html_response(conn, 200) =~ "New level"
    end
  end

  describe "create level with a registered user" do
    setup [:create_user, :create_dungeon]

    test "redirects to show when data is valid", %{conn: conn, dungeon: dungeon} do
      level = insert_autogenerated_level(%{dungeon_id: dungeon.id})

      conn = post conn, edit_dungeon_level_path(conn, :create, dungeon.id), level: @create_attrs

      assert %{id: id} = redirected_params(conn)
      assert "#{dungeon.id}" == id
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, id)

      [^level, new_level] = Repo.preload(dungeon, :levels).levels |> Enum.sort(&(&1.number < &2.number))
      assert new_level.number_north == 1
      refute level.number_south
    end

    test "renders errors when data is invalid", %{conn: conn, dungeon: dungeon} do
      conn = post conn, edit_dungeon_level_path(conn, :create, dungeon.id), level: @invalid_attrs
      assert html_response(conn, 200) =~ "New level"
    end

    test "links adjacent levels", %{conn: conn, dungeon: dungeon} do
      level = insert_autogenerated_level(%{dungeon_id: dungeon.id})
      attrs = Map.put(@create_attrs, :link_adjacent_levels, "true")

      post conn, edit_dungeon_level_path(conn, :create, dungeon.id), level: attrs

      [linked_level, new_level] = Repo.preload(dungeon, :levels).levels |> Enum.sort(&(&1.number < &2.number))
      assert new_level.number_north == 1
      assert linked_level.number_south == 2
      assert linked_level.id == level.id
    end
  end

  describe "edit level with a registered user" do
    setup [:create_user, :create_level]

    test "renders form for editing chosen level", %{conn: conn, level: level} do
      conn = get conn, edit_dungeon_level_path(conn, :edit, Repo.preload(level, :dungeon).dungeon, level)
      assert html_response(conn, 200) =~ "Edit level"
    end

    test "cannot edit active dungeon", %{conn: conn, level: level} do
      {:ok, _dungeon} = Dungeons.update_dungeon(Repo.preload(level, :dungeon).dungeon, %{active: true})
      conn = get conn, edit_dungeon_level_path(conn, :edit, level.dungeon_id, level)
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, level.dungeon_id)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
    end

    test "level is in a dungeon belonging to someone else", %{conn: conn, level: level} do
      other_user = insert_user()
      {:ok, _dungeon} = Dungeons.update_dungeon(Repo.preload(level, :dungeon).dungeon, %{user_id: other_user.id})
      conn = get conn, edit_dungeon_level_path(conn, :edit, level.dungeon_id, level)
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "level is for a different dungeon", %{conn: conn, level: level} do
      other_level = insert_autogenerated_level()
      conn = get conn, edit_dungeon_level_path(conn, :edit, level.dungeon_id, other_level)
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "gracefully handles bad level id", %{conn: conn, level: level} do
      conn = get conn, edit_dungeon_level_path(conn, :edit, level.dungeon_id, "foo")
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end
  end

  describe "update level with a registered user" do
    setup [:create_user, :create_level]

    test "redirects when data is valid", %{conn: conn, level: level} do
      other_level = insert_autogenerated_level(%{dungeon_id: level.dungeon_id, number: 2})

      tile_template = insert_tile_template(%{character: "X", color: "white", background_color: "blue"})
      tile_attrs = Map.take(Dungeons.get_tile(level.id, 1, 1), [:level_id, :row, :col, :tile_template_id, :character, :color, :background_color])
      {:ok, other_tile} = Dungeons.create_tile(Map.put(tile_attrs, :z_index, -1))

      tile_data = %{tile_changes: "[{\"row\": 1, \"col\": 1, \"z_index\": 0, \"tile_template_id\": #{tile_template.id}, \"color\": \"red\"}]",
                    tile_additions: "[{\"row\": 1, \"col\": 1, \"z_index\": 1, \"tile_template_id\": #{tile_template.id}, \"color\": \"blue\"},{\"row\": 1, \"col\": 2, \"z_index\": 1, \"character\": \"#{tile_template.character}\", \"color\": \"gold\", \"tile_template_id\": #{tile_template.id + 30}}]",
                    tile_deletions: "[{\"row\": 0, \"col\": 1, \"z_index\": 0}]",
                    spawn_tiles: "[[4,1],[4,2],[4,3],[500,500]]"}

      conn = put conn, edit_dungeon_level_path(conn, :update, level.dungeon_id, level),
                   level: Map.merge(@update_attrs, tile_data)

      assert Dungeons.get_tile(level.id, 1, 1, 0).character == tile_template.character
      refute Dungeons.get_tile(level.id, 1, 1, 0).color == tile_template.color
      assert Dungeons.get_tile(level.id, 1, 1, 0).color == "red"
      assert Dungeons.get_tile(level.id, 1, 1, 0).background_color == tile_template.background_color

      assert Dungeons.get_tile(level.id, 1, 1, -1).character == other_tile.character
      assert Dungeons.get_tile(level.id, 1, 1, -1).color == other_tile.color
      assert Dungeons.get_tile(level.id, 1, 1, -1).background_color == other_tile.background_color

      assert Dungeons.get_tile(level.id, 1, 1, 1).character == tile_template.character
      assert Dungeons.get_tile(level.id, 1, 1, 1).color == "blue"
      assert Dungeons.get_tile(level.id, 1, 1, 1).background_color == tile_template.background_color

      assert tile_without_valid_template = Dungeons.get_tile(level.id, 1, 2, 1)
      assert tile_without_valid_template.character == tile_template.character
      assert tile_without_valid_template.color == "gold"

      refute Dungeons.get_tile(level.id, 0, 1, 1)

      spawn_locations = DungeonCrawl.Repo.preload(level, :spawn_locations).spawn_locations
      assert [%{row: 4, col: 1}, %{row: 4, col: 2}, %{row: 4, col: 3}] = spawn_locations

      assert redirected_to(conn) == edit_dungeon_path(conn, :show, level.dungeon_id)


      [updated_level, ^other_level] = Repo.preload(level, dungeon: :levels).dungeon.levels |> Enum.sort(&(&1.number < &2.number))
      assert updated_level.number_north == 2
      refute other_level.number_south
    end

    test "links adjacent levels", %{conn: conn, level: level} do
      other_level = insert_autogenerated_level(%{dungeon_id: level.dungeon_id, number: 2})
      attrs = Map.put(@update_attrs, :link_adjacent_levels, "true")

      put conn, edit_dungeon_level_path(conn, :update, level.dungeon_id, level),
                 level: attrs

      [updated_level, linked_level] = Repo.preload(level, dungeon: :levels).dungeon.levels |> Enum.sort(&(&1.number < &2.number))
      assert updated_level.number_north == 2
      assert linked_level.number_south == 1
      assert linked_level.id == other_level.id
    end

    test "renders errors when data is invalid", %{conn: conn, level: level} do
      conn = put conn, edit_dungeon_level_path(conn, :update, level.dungeon_id, level), level: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit level"
    end

    test "cannot update active dungeon", %{conn: conn, level: level} do
      {:ok, _dungeon} = Dungeons.update_dungeon(Repo.preload(level, :dungeon).dungeon, %{active: true})
      conn = put conn, edit_dungeon_level_path(conn, :update, level.dungeon_id, level), level: @update_attrs
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, level.dungeon_id)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
    end
  end

  describe "delete level with a registered user" do
    setup [:create_user, :create_level]

    test "deletes the level", %{conn: conn, level: level} do
      conn = delete conn, edit_dungeon_level_path(conn, :delete, level.dungeon_id, level)
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, level.dungeon_id)
      refute Repo.get(Dungeons.Level, level.id)
    end
  end

  describe "level edge with a registered user" do
    setup [:create_user, :create_level]

    test "gets the adjacent edge tiles", %{conn: conn, level: level} do
      other_level = insert_autogenerated_level(%{number: 2, dungeon_id: level.dungeon_id, number_east: 1})
      expected_json = Enum.map(0..4, fn i -> %{"html" => "<div>#</div>", "id" => "east_#{ i }"} end) ++
                      Enum.map(5..20, fn i -> %{"html" => "<div> </div>", "id" => "east_#{ i }"} end)
      got_conn = get conn, edit_dungeon_level_path(conn, :level_edge, other_level.dungeon_id, edge: "east", level_number: other_level.number)
      assert Enum.sort(json_response(got_conn, 200), fn a,b -> a["id"] < b["id"] end)  ==
             Enum.sort(expected_json, fn a,b -> a["id"] < b["id"] end)

      got_conn = get conn, edit_dungeon_level_path(conn, :level_edge, other_level.dungeon_id, edge: "north", level_number: level.number)
      assert json_response(got_conn, 200) == []
    end
  end
  # /With a registered user

  defp create_dungeon(opts) do
    dungeon = fixture(:dungeon, (opts.conn.assigns[:current_user] || insert_user(%{username: "CSwaggins"})).id )
    {:ok, conn: opts.conn, dungeon: dungeon}
  end

  defp create_level(opts) do
    level = fixture(:level, (opts.conn.assigns[:current_user] || insert_user(%{username: "CSwaggins"})).id )
    {:ok, conn: opts.conn, level: level}
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
