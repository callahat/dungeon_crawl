defmodule DungeonCrawl.TileTemplatesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileTemplates

  describe "tile_templates" do
    alias DungeonCrawl.TileTemplates.TileTemplate

    @valid_attrs %{name: "A Big X", description: "A big capital X", character: "X", color: "red", background_color: "black", active: true, state: %{blocking: true}, script: ""}
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

    test "list_placeable_tile_templates/2 returns all tile_templates placeable for the given user partitioned" do
      user = insert_user()
      different_user = insert_user()
      tile_template = tile_template_fixture(%{user_id: user.id, group_name: "monsters"})
      inactive_tile_template = tile_template_fixture(%{user_id: user.id, active: false})
      tile_template_fixture(%{user_id: different_user.id})
      public_tile_template = tile_template_fixture(%{user_id: different_user.id, public: true})
      _unlisted_tile_template = tile_template_fixture(%{user_id: different_user.id, public: true, unlisted: true})
      deleted_tile_template_fixture()
      assert TileTemplates.list_placeable_tile_templates(user) ==
               %{active: %{"monsters" => [tile_template], "custom" => [public_tile_template]},
                 inactive: %{"custom" => [inactive_tile_template]}}
    end

    test "get_tile_template/1 returns an empty struct for nil" do
      assert TileTemplates.get_tile_template(nil) == %TileTemplate{}
    end

    test "get_tile_template/1 returns nil for a nonexistant id" do
      refute TileTemplates.get_tile_template(1234134)
    end

    test "get_tile_template!/1 returns the tile_template with given id" do
      tile_template = tile_template_fixture()
      assert TileTemplates.get_tile_template!(tile_template.id) == tile_template
      assert TileTemplates.get_tile_template(tile_template.id) == tile_template
    end

    test "get_tile_template_by_slug/1 returns the tile_template with given slug" do
      tile_template = tile_template_fixture(%{active: true})
      assert TileTemplates.get_tile_template_by_slug(tile_template.slug) == tile_template
    end

    test "get_tile_template_by_slug/1 returns nil on bad slug" do
      refute TileTemplates.get_tile_template_by_slug("fake")
    end

    test "get_tile_template_by_slug/1 returns nil on slug with no active tile template" do
      tile_template = tile_template_fixture(%{active: false})
      refute TileTemplates.get_tile_template_by_slug(tile_template.slug)
    end

    test "get_tile_template_by_slug/2 returns slug even when no active tile template" do
      tile_template = tile_template_fixture(%{active: false})
      assert TileTemplates.get_tile_template_by_slug(tile_template.slug, :validation)
    end

    test "get_tile_template_by_slug!/1 returns the tile_template with given slug" do
      tile_template = tile_template_fixture(%{active: true})
      assert TileTemplates.get_tile_template_by_slug(tile_template.slug) == tile_template
    end

    test "get_tile_template_by_slug!/1 raises exception when not found" do
      assert_raise Ecto.NoResultsError, fn -> TileTemplates.get_tile_template_by_slug!("cloud_chaser") end
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

    test "create_tile_template/1 with valid data and no user creates a tile_template" do
      assert {:ok, %TileTemplate{} = tile_template} = TileTemplates.create_tile_template(@valid_attrs)
      assert tile_template.background_color == "black"
      assert tile_template.character == "X"
      assert tile_template.color == "red"
      assert tile_template.description == "A big capital X"
      assert tile_template.name == "A Big X"
      assert tile_template.script == ""
      assert tile_template.slug == "a_big_x"
    end

    test "create tile_template/1 with an admin user sets the slug" do
      user = insert_user(%{is_admin: true})
      # creates the slug
      assert {:ok, %TileTemplate{} = tile_template} = TileTemplates.create_tile_template(Map.put(@valid_attrs, :user_id, user.id))
      assert tile_template.slug == "a_big_x"

      # when the slug already exists, the id is appended to the slug
      assert {:ok, %TileTemplate{} = tile_template_2} = TileTemplates.create_tile_template(Map.put(@valid_attrs, :user_id, user.id))
      assert tile_template_2.slug == "a_big_x_#{tile_template_2.id}"

      # slug cannot be explicitly set
      assert {:ok, %TileTemplate{} = tile_template_3} = TileTemplates.create_tile_template(Map.put(@valid_attrs, :slug, "goober"))
      refute tile_template_3.slug == "goober"
      assert tile_template_3.slug == "a_big_x_#{tile_template_3.id}"
    end

    test "create tile_template/1 with a normal user sets the slug" do
      user = insert_user(%{is_admin: false})
      # creates the slug with id appended
      assert {:ok, %TileTemplate{} = tile_template} = TileTemplates.create_tile_template(Map.put(@valid_attrs, :user_id, user.id))
      assert tile_template.slug == "a_big_x_#{tile_template.id}"
    end

    test "create_tile_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TileTemplates.create_tile_template(@invalid_attrs)
    end

    test "create_tile_template/1 with bad script" do
      assert {:error, changeset} = TileTemplates.create_tile_template(Map.merge(@valid_attrs, %{script: "#junk", character: "BIG"}))
      assert %{script: ["Unknown command: `junk` - near line 1"],
               character: ["should be at most 1 character(s)"]} == errors_on(changeset)
    end

    test "create_new_tile_template_version/1 does not create a new version of an inactive tile_template" do
      tile_template = tile_template_fixture(%{active: false})
      assert {:error, "Inactive tile template"} = TileTemplates.create_new_tile_template_version(tile_template)
    end

    test "create_new_tile_template_version/1 creates a new version" do
      tile_template = tile_template_fixture(%{active: true, animate_characters: "a,b,c", group_name: "items"})
      assert {:ok, new_tile_template} = TileTemplates.create_new_tile_template_version(tile_template)
      assert new_tile_template.version == tile_template.version + 1
      refute new_tile_template.active
      assert Map.take(tile_template, [:name, :background_color, :character, :color, :user_id, :public,
                                      :description, :state, :script, :slug,
                                      :animate_random, :animate_colors, :animate_background_colors,
                                      :animate_characters, :animate_period, :group_name]) ==
             Map.take(new_tile_template, [:name, :background_color, :character, :color, :user_id, :public,
                                          :description, :state, :script, :slug,
                                          :animate_random, :animate_colors, :animate_background_colors,
                                          :animate_characters, :animate_period, :group_name])
    end

    test "create_new_tile_template_version/1 does not create a new version if the next one exists" do
      tile_template = tile_template_fixture(%{active: true})
      tile_template_fixture(%{previous_version_id: tile_template.id})
      assert {:error, "New version already exists"} = TileTemplates.create_new_tile_template_version(tile_template)
    end

    test "find_tile_template/1" do
      {:ok, %TileTemplate{} = existing_tile_template} = TileTemplates.create_tile_template(@valid_attrs)

      assert existing_tile_template == TileTemplates.find_tile_template(@valid_attrs)
      refute TileTemplates.find_tile_template(%{name: "junk that does not exist"})
    end

    test "find_tile_templates/1" do
      {:ok, %TileTemplate{} = existing_tile_template1} = TileTemplates.create_tile_template(@valid_attrs)
      {:ok, %TileTemplate{} = existing_tile_template2} = TileTemplates.create_tile_template(Map.put(@valid_attrs, :name, "A Big X 2"))

      assert [existing_tile_template1, existing_tile_template2]
             == TileTemplates.find_tile_templates(%{description: "A big capital X", character: "X", user_id: nil})
      assert [] == TileTemplates.find_tile_templates(%{name: "junk that does not exist"})
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
      assert tile_template.state == %{blocking: true}
      assert tile_template.script == ""
      assert tile_template.slug == "a_big_x_#{tile_template.id}"
    end

    test "find_or_create_tile_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TileTemplates.find_or_create_tile_template(@invalid_attrs)
    end

    test "update_or_create_tile_template/2" do
      {:ok, existing_tile_template} = TileTemplates.create_tile_template(@valid_attrs)
      # finds existing template by slug and updates it
      assert {:ok, tile_template} = TileTemplates.update_or_create_tile_template("a_big_x", Map.put(@valid_attrs, :character, "Y"))
      assert tile_template.id == existing_tile_template.id
      assert tile_template.character == "Y"

      # does not find the slug, but finds a matching tile for the other attrs
      assert {:ok, tile_template} = TileTemplates.update_or_create_tile_template("a_big_y", Map.put(@valid_attrs, :character, "Y"))
      assert tile_template.id == existing_tile_template.id
      assert tile_template.character == "Y"
      assert tile_template.slug == "a_big_x"

      # creates the unfound tile
      assert {:ok, tile_template} = TileTemplates.update_or_create_tile_template("not", Map.merge(@valid_attrs, %{character: "Z", name: "Big Z"}))
      assert tile_template.id != existing_tile_template.id
      assert tile_template.character == "Z"
      assert tile_template.slug == "big_z"
    end

    test "update_or_create_tile_template!/2" do
      {:ok, existing_tile_template} = TileTemplates.create_tile_template(@valid_attrs)
      # finds existing template by slug and updates it
      assert tile_template = TileTemplates.update_or_create_tile_template!("a_big_x", Map.put(@valid_attrs, :character, "Y"))
      assert tile_template.id == existing_tile_template.id
      assert tile_template.character == "Y"

      # does not find the slug, but finds a matching tile for the other attrs
      assert tile_template = TileTemplates.update_or_create_tile_template!("a_big_y", Map.put(@valid_attrs, :character, "Y"))
      assert tile_template.id == existing_tile_template.id
      assert tile_template.character == "Y"
      assert tile_template.slug == "a_big_x"

      # creates the unfound tile
      assert tile_template = TileTemplates.update_or_create_tile_template!("not", Map.merge(@valid_attrs, %{character: "Z", name: "Big Z"}))
      assert tile_template.id != existing_tile_template.id
      assert tile_template.character == "Z"
      assert tile_template.slug == "big_z"
    end

    test "update_tile_template/2 with valid data updates the tile_template" do
      tile_template = tile_template_fixture()
      assert {:ok, tile_template} = TileTemplates.update_tile_template(tile_template, @update_attrs)
      assert %TileTemplate{} = tile_template
      assert tile_template.color == "puce"
    end

    test "update_tile_template/2 will not update the slug" do
      tile_template = tile_template_fixture()
      assert {:ok, tile_template} = TileTemplates.update_tile_template(tile_template, %{slug: "somethingelse"})
      refute tile_template.slug == "somethingelse"
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

    test  "copy_fields/1" do
      tile_template = tile_template_fixture()
      assert %{animate_background_colors: nil,
               animate_characters: nil,
               animate_colors: nil,
               animate_period: nil,
               animate_random: nil,
               background_color: "black",
               character: "X",
               color: "red",
               name: "A Big X",
               script: "",
               state: %{blocking: true},
               description: "A big capital X",
               group_name: "custom",
               public: false,
               slug: "a_big_x",
               unlisted: false,
               user_id: nil} == TileTemplates.copy_fields(tile_template)
      assert %{} == TileTemplates.copy_fields(nil)
    end

    test "autogenerated_dungeon_tile_mapping/0" do
      assert %{
               ?▟ => _, "▟" => _,
               # items
               ?ä => _, "ä" => _,
               ?▪ => _, "▪" => _,
               ?♂ => _, "♂" => _,
               ?$ => _, "$" => _,
               ?♦ => _, "♦" => _,
               ?♥ => _, "♥" => _,
               ?✚ => _, "✚" => _,
               # monsters
               ?♣ => _, "♣" => _,
               ?ö => _, "ö" => _,
               ?Ω => _, "Ω" => _,
               ?π => _, "π" => _,
               ?x => _, "x" => _,
               ?r => _, "r" => _,
               ?Z => _, "Z" => _,
             } = TileTemplates.autogenerated_dungeon_tile_mapping()
    end
  end
end
