defmodule DungeonCrawl.TileTemplatesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileTemplates

  describe "tile_templates" do
    alias DungeonCrawl.TileTemplates.TileTemplate

    @valid_attrs %{background_color: "some background_color", blocking: true, character: "some character", closeable: true, color: "some color", description: "some description", durability: 42, name: "some name", openable: true}
    @update_attrs %{background_color: "some updated background_color", blocking: false, character: "some updated character", closeable: false, color: "some updated color", description: "some updated description", durability: 43, name: "some updated name", openable: false}
    @invalid_attrs %{background_color: nil, blocking: nil, character: nil, closeable: nil, color: nil, description: nil, durability: nil, name: nil, openable: nil}

    def tile_template_fixture(attrs \\ %{}) do
      {:ok, tile_template} =
        attrs
        |> Enum.into(@valid_attrs)
        |> TileTemplates.create_tile_template()

      tile_template
    end

    test "list_tile_templates/0 returns all tile_templates" do
      tile_template = tile_template_fixture()
      assert TileTemplates.list_tile_templates() == [tile_template]
    end

    test "get_tile_template!/1 returns the tile_template with given id" do
      tile_template = tile_template_fixture()
      assert TileTemplates.get_tile_template!(tile_template.id) == tile_template
    end

    test "create_tile_template/1 with valid data creates a tile_template" do
      assert {:ok, %TileTemplate{} = tile_template} = TileTemplates.create_tile_template(@valid_attrs)
      assert tile_template.background_color == "some background_color"
      assert tile_template.blocking == true
      assert tile_template.character == "some character"
      assert tile_template.closeable == true
      assert tile_template.color == "some color"
      assert tile_template.description == "some description"
      assert tile_template.durability == 42
      assert tile_template.name == "some name"
      assert tile_template.openable == true
    end

    test "create_tile_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TileTemplates.create_tile_template(@invalid_attrs)
    end

    test "update_tile_template/2 with valid data updates the tile_template" do
      tile_template = tile_template_fixture()
      assert {:ok, tile_template} = TileTemplates.update_tile_template(tile_template, @update_attrs)
      assert %TileTemplate{} = tile_template
      assert tile_template.background_color == "some updated background_color"
      assert tile_template.blocking == false
      assert tile_template.character == "some updated character"
      assert tile_template.closeable == false
      assert tile_template.color == "some updated color"
      assert tile_template.description == "some updated description"
      assert tile_template.durability == 43
      assert tile_template.name == "some updated name"
      assert tile_template.openable == false
    end

    test "update_tile_template/2 with invalid data returns error changeset" do
      tile_template = tile_template_fixture()
      assert {:error, %Ecto.Changeset{}} = TileTemplates.update_tile_template(tile_template, @invalid_attrs)
      assert tile_template == TileTemplates.get_tile_template!(tile_template.id)
    end

    test "delete_tile_template/1 deletes the tile_template" do
      tile_template = tile_template_fixture()
      assert {:ok, %TileTemplate{}} = TileTemplates.delete_tile_template(tile_template)
      assert_raise Ecto.NoResultsError, fn -> TileTemplates.get_tile_template!(tile_template.id) end
    end

    test "change_tile_template/1 returns a tile_template changeset" do
      tile_template = tile_template_fixture()
      assert %Ecto.Changeset{} = TileTemplates.change_tile_template(tile_template)
    end
  end
end
