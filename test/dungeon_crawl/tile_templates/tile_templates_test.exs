defmodule DungeonCrawl.TileTemplatesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileTemplates

  describe "tile_templates" do
    alias DungeonCrawl.TileTemplates.TileTemplate

    @valid_attrs %{name: "A Big X", description: "A big capital X", character: "X", color: "red", background_color: "black", active: true, state: "blocking: true", script: ""}
    @update_attrs %{color: "puce", character: "█"}
    @invalid_attrs %{name: "", character: "BIG"}

    def tile_template_fixture(attrs \\ %{}) do
      {:ok, tile_template} =
        attrs
        |> Enum.into(@valid_attrs)
        |> TileTemplates.create_tile_template()

      tile_template
    end

    def deleted_tile_template_fixture(attrs \\ %{}) do
      TileTemplates.delete_tile_template(tile_template_fixture(attrs))
    end

    test "list_tile_templates/1 returns all tile_templates owned by the given user" do
      user = insert_user()
      different_user = insert_user()
      tile_template = tile_template_fixture(%{user_id: user.id})
      tile_template_fixture(%{user_id: different_user.id})
      deleted_tile_template_fixture()
      assert TileTemplates.list_tile_templates(user) == [tile_template]
    end

    test "list_tile_templates/0 returns all tile_templates" do
      tile_template = tile_template_fixture()
      deleted_tile_template_fixture()
      assert TileTemplates.list_tile_templates() == [tile_template]
    end

    test "list_placeable_tile_templates/1 returns all tile_templates placeable for the given user" do
      user = insert_user()
      different_user = insert_user()
      tile_template = tile_template_fixture(%{user_id: user.id})
      inactive_tile_template = tile_template_fixture(%{user_id: user.id, active: false})
      tile_template_fixture(%{user_id: different_user.id})
      public_tile_template = tile_template_fixture(%{user_id: different_user.id, public: true})
      deleted_tile_template_fixture()
      assert TileTemplates.list_placeable_tile_templates(user) == %{active: [tile_template, public_tile_template], inactive: [inactive_tile_template]}
    end

    test "get_tile_template!/1 returns the tile_template with given id" do
      tile_template = tile_template_fixture()
      assert TileTemplates.get_tile_template!(tile_template.id) == tile_template
      assert TileTemplates.get_tile_template(tile_template.id) == tile_template
    end

    test "next_version_exists?/1 is true if the tile_template has a next version" do
      tile_template = tile_template_fixture()
      tile_template_fixture(%{previous_version_id: tile_template.id})
      assert TileTemplates.next_version_exists?(tile_template)
    end

    test "next_version_exists?/1 is false if the tile_template does not have a next version" do
      tile_template = tile_template_fixture()
      refute TileTemplates.next_version_exists?(tile_template)
    end

    test "create_tile_template/1 with valid data creates a tile_template" do
      assert {:ok, %TileTemplate{} = tile_template} = TileTemplates.create_tile_template(@valid_attrs)
      assert tile_template.background_color == "black"
      assert tile_template.character == "X"
      assert tile_template.color == "red"
      assert tile_template.description == "A big capital X"
      assert tile_template.name == "A Big X"
      assert tile_template.script == ""
    end

    test "create_tile_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TileTemplates.create_tile_template(@invalid_attrs)
    end

#TODO: once the script parser is ready
#    test "create_tile_template/1 with bad script" do
#      assert {:error, changeset} = TileTemplates.create_tile_template(Map.merge(@valid_attrs, %{script: "junk", character: "BIG"}))
#      assert "Problem parsing - junk" in errors_on(changeset).script
#      assert "should be at most 1 character(s)" in errors_on(changeset).character
#      assert %{script: ["Problem parsing - junk"], character: ["should be at most 1 character(s)"]} = errors_on(changeset)
#    end

    test "create_new_tile_template_version/1 does not create a new version of an inactive tile_template" do
      tile_template = tile_template_fixture(%{active: false})
      assert {:error, "Inactive tile template"} = TileTemplates.create_new_tile_template_version(tile_template)
    end

    test "create_new_tile_template_version/1 creates a new version" do
      tile_template = tile_template_fixture(%{active: true})
      assert {:ok, new_tile_template} = TileTemplates.create_new_tile_template_version(tile_template)
      assert new_tile_template.version == tile_template.version + 1
      refute new_tile_template.active
      assert Map.take(tile_template, [:name, :background_color, :character, :color, :user_id, :public, :description, :state, :script]) ==
             Map.take(new_tile_template, [:name, :background_color, :character, :color, :user_id, :public, :description, :state, :script])
    end

    test "create_new_tile_template_version/1 does not create a new version if the next one exists" do
      tile_template = tile_template_fixture(%{active: true})
      tile_template_fixture(%{previous_version_id: tile_template.id})
      assert {:error, "New version already exists"} = TileTemplates.create_new_tile_template_version(tile_template)
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
      assert tile_template.state == "blocking: true"
      assert tile_template.script == ""
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

    test "delete_tile_template/1 soft deletes the tile_template" do
      tile_template = tile_template_fixture()
      assert {:ok, %TileTemplate{}} = TileTemplates.delete_tile_template(tile_template)
      refute TileTemplates.get_tile_template!(tile_template.id).deleted_at == nil
    end

    test "change_tile_template/1 returns a tile_template changeset" do
      tile_template = tile_template_fixture()
      assert %Ecto.Changeset{} = TileTemplates.change_tile_template(tile_template)
    end
  end
end
