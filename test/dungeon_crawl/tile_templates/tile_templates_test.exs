defmodule DungeonCrawl.TileTemplatesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileTemplates

  describe "tile_templates" do
    alias DungeonCrawl.TileTemplates.TileTemplate

    @valid_attrs %{name: "A Big X", description: "A big capital X", character: "X", color: "red", background_color: "black"}
    @update_attrs %{color: "puce", character: "█"}
    @invalid_attrs %{name: "", character: "BIG"}

    def tile_template_fixture(attrs \\ %{}) do
      {:ok, tile_template} =
        attrs
        |> Enum.into(@valid_attrs)
        |> TileTemplates.create_tile_template()

      tile_template
    end

    test "list_tile_templates/0 returns all tile_templates" do
      tile_template = tile_template_fixture()
      assert Enum.count(TileTemplates.list_tile_templates()) == 1
      assert TileTemplates.list_tile_templates() == [tile_template]
    end

    test "get_tile_template!/1 returns the tile_template with given id" do
      tile_template = tile_template_fixture()
      assert TileTemplates.get_tile_template!(tile_template.id) == tile_template
      assert TileTemplates.get_tile_template(tile_template.id) == tile_template
    end

    test "create_tile_template/1 with valid data creates a tile_template" do
      assert {:ok, %TileTemplate{} = tile_template} = TileTemplates.create_tile_template(@valid_attrs)
      assert tile_template.background_color == "black"
      assert tile_template.character == "X"
      assert tile_template.color == "red"
      assert tile_template.description == "A big capital X"
      assert tile_template.name == "A Big X"
      assert tile_template.responders == "{}"
    end

    test "create_tile_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TileTemplates.create_tile_template(@invalid_attrs)
    end

    test "create_tile_template/1 with bad responders" do
      assert {:error, changeset} = TileTemplates.create_tile_template(Map.merge(@valid_attrs, %{responders: "junk", character: "BIG"}))
      assert "Problem parsing - junk" in errors_on(changeset).responders
      assert "should be at most 1 character(s)" in errors_on(changeset).character
      assert %{responders: ["Problem parsing - junk"], character: ["should be at most 1 character(s)"]} = errors_on(changeset)
    end

    test "find_or_create_tile_template/1 finds existing tile_template" do
      {:ok, %TileTemplate{} = existing_tile_template} = TileTemplates.create_tile_template(@valid_attrs)

      assert {:ok, existing_tile_template} == TileTemplates.find_or_create_tile_template(@valid_attrs)
    end

    test "find_or_create_tile_template!/1 finds existing tile_template" do
      {:ok, %TileTemplate{} = existing_tile_template} = TileTemplates.create_tile_template(@valid_attrs)

      assert existing_tile_template == TileTemplates.find_or_create_tile_template!(@valid_attrs)
    end

    test "find_or_create_tile_template/1 creates tile_template when matching one not found" do
      {:ok, %TileTemplate{} = existing_tile_template} = TileTemplates.create_tile_template(Map.put(@valid_attrs, :character, "Y"))
      assert {:ok, %TileTemplate{} = tile_template} = TileTemplates.find_or_create_tile_template(@valid_attrs)

      refute existing_tile_template == tile_template
      assert tile_template.background_color == "black"
      assert tile_template.character == "X"
      assert tile_template.color == "red"
      assert tile_template.description == "A big capital X"
      assert tile_template.name == "A Big X"
      assert tile_template.responders == "{}"
    end

    test "find_or_create_tile_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TileTemplates.find_or_create_tile_template(@invalid_attrs)
    end

    test "update_tile_template/2 with valid data updates the tile_template" do
      tile_template = tile_template_fixture()
      assert {:ok, tile_template} = TileTemplates.update_tile_template(tile_template, @update_attrs)
      assert %TileTemplate{} = tile_template
      assert tile_template.color == "puce"
    end

    test "update_tile_template/2 with invalid data returns error changeset" do
      tile_template = tile_template_fixture()
      assert {:error, %Ecto.Changeset{}} = TileTemplates.update_tile_template(tile_template, @invalid_attrs)
      assert tile_template == TileTemplates.get_tile_template!(tile_template.id)
    end

    test "delete_tile_template/1 deletes the tile_template if not in use" do
      tile_template = tile_template_fixture()
      assert {:ok, %TileTemplate{}} = TileTemplates.delete_tile_template(tile_template)
      assert_raise Ecto.NoResultsError, fn -> TileTemplates.get_tile_template!(tile_template.id) end
    end

    test "delete_tile_template/1 raises if the tile_template is associated with a map_tile" do
      tile_template = tile_template_fixture()
      insert_stubbed_dungeon(%{}, [%{row: 1, col: 1, tile: "!", tile_template_id: tile_template.id}])
      assert {:error, "Cannot delete a tile template that is in use"} = TileTemplates.delete_tile_template(tile_template)
    end

    test "change_tile_template/1 returns a tile_template changeset" do
      tile_template = tile_template_fixture()
      assert %Ecto.Changeset{} = TileTemplates.change_tile_template(tile_template)
    end
  end
end
