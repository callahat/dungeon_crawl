defmodule DungeonCrawl.EquipmentTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Equipment

  describe "items" do
    alias DungeonCrawl.Equipment.Item

    @valid_attrs %{name: "thing", description: "A thing", public: true, script: "#give gems, 1, @facing", slug: "some slug"}
    @update_attrs %{name: "updated thing", description: "An updated thing", public: false, script: "#take gems, 1, @facing", slug: "some updated slug"}
    @invalid_attrs %{name: "Bob", script: "#fakecommand"}

    def item_fixture(attrs \\ %{}) do
      {:ok, item} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Equipment.create_item()

      item
    end

    test "list_items/0 returns all items" do
      item = item_fixture()
      assert Equipment.list_items() == [item]
    end

    test "list_items/0 returns all items owned by the given user" do
      user = insert_user()
      different_user = insert_user()
      item = item_fixture(%{user_id: user.id})
      item_fixture(%{user_id: different_user.id})
      assert Equipment.list_items(user) == [item]
    end

    test "list_items/0 returns all items owned by no one" do
      user = insert_user()
      item = item_fixture(%{user_id: nil})
      item_fixture(%{user_id: user.id})
      assert Equipment.list_items(:nouser) == [item]
    end

    test "get_item/1 returns the item with given id" do
      item = item_fixture()
      assert Equipment.get_item(item.id) == item
    end

    test "get_item/1 returns the item with given slug" do
      item = item_fixture()
      assert Equipment.get_item(item.slug) == item
    end

    test "get_item/1 returns nil if not found" do
      refute Equipment.get_item(1)
      refute Equipment.get_item("fake_item")
      refute Equipment.get_item(nil)
    end

    test "get_item!/1 returns the item with given id" do
      item = item_fixture()
      assert Equipment.get_item!(item.id) == item
      assert_raise Ecto.NoResultsError, fn -> Equipment.get_item!(item.id+1) end
    end

    test "get_item!/1 returns the item with given slug" do
      item = item_fixture()
      assert Equipment.get_item!(item.slug) == item
      assert_raise Ecto.NoResultsError, fn -> Equipment.get_item!("fakeslug") end
    end

    test "get_item/2 takes into consideration the author" do
      user = insert_user()
      item = item_fixture(%{user_id: user.id})
      other_item = item_fixture(%{name: "other thing", public: false, user_id: user.id})
      assert Equipment.get_item(item.slug, user) == item
      refute Equipment.get_item(other_item.id, %{ user | id: user.id + 1})
    end

    test "create_item/1 with valid data creates a item" do
      assert {:ok, %Item{} = item} = Equipment.create_item(@valid_attrs)
      assert item.name == "thing"
      assert item.public == true
      assert item.script == @valid_attrs.script
      assert item.slug == "thing"
    end

    test "create_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Equipment.create_item(@invalid_attrs)
    end

    test "find_item/1" do
      {:ok, %Item{} = existing_item} = Equipment.create_item(@valid_attrs)

      assert existing_item == Equipment.find_item(@valid_attrs)
      refute Equipment.find_item(%{name: "item that does not exist"})
    end

    test "find_items/2" do
      {:ok, %Item{} = existing_item1} = Equipment.create_item(@valid_attrs)
      {:ok, %Item{} = existing_item2} = Equipment.create_item(Map.put(@valid_attrs, :name, "thing2"))

      assert [existing_item1, existing_item2] == Equipment.find_items(%{description: "A thing", public: true, user_id: nil})
    end

    test "find_or_create_item/1 finds existing item" do
      {:ok, %Item{} = existing_item} = Equipment.create_item(@valid_attrs)

      assert {:ok, existing_item} == Equipment.find_or_create_item(@valid_attrs)
    end

    test "find_or_create_item!/1 finds existing item" do
      {:ok, %Item{} = existing_item} = Equipment.create_item(@valid_attrs)

      assert existing_item == Equipment.find_or_create_item!(@valid_attrs)
    end

    test "find_or_create_item/1 creates item when matching one not found" do
      {:ok, %Item{} = existing_item} = Equipment.create_item(@valid_attrs)
      assert {:ok, %Item{} = item} = Equipment.find_or_create_item(%{@valid_attrs | description: "different thing"})

      refute existing_item == item
      assert item.description == "different thing"
      assert item.name == "thing"
      assert item.script == @valid_attrs.script
      assert item.slug == "thing_#{item.id}"
    end

    test "find_or_create_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Equipment.find_or_create_item(@invalid_attrs)
    end

    test "update_or_create_item/2" do
      {:ok, existing_item} = Equipment.create_item(@valid_attrs)
      updated_attrs = Map.put(@valid_attrs, :description, "Y")
      # finds existing template by slug and updates it
      assert {:ok, item} = Equipment.update_or_create_item("thing", updated_attrs)
      assert item.id == existing_item.id
      assert item.description == "Y"

      # does not find the slug, but finds a matching tile for the other attrs
      assert {:ok, item} = Equipment.update_or_create_item("thing2", updated_attrs)
      assert item.id == existing_item.id
      assert item.slug == "thing"

      # creates the unfound tile
      assert {:ok, item} = Equipment.update_or_create_item("not", Map.merge(updated_attrs, %{name: "Big Z"}))
      assert item.id != existing_item.id
      assert item.slug == "big_z"
    end

    test "update_or_create_item!/2" do
      {:ok, existing_item} = Equipment.create_item(@valid_attrs)
      updated_attrs = Map.put(@valid_attrs, :description, "Y")
      # finds existing template by slug and updates it
      assert item = Equipment.update_or_create_item!("thing", updated_attrs)
      assert item.id == existing_item.id
      assert item.description == "Y"

      # does not find the slug, but finds a matching tile for the other attrs
      assert item = Equipment.update_or_create_item!("thing2", updated_attrs)
      assert item.id == existing_item.id
      assert item.slug == "thing"

      # creates the unfound tile
      assert item = Equipment.update_or_create_item!("not", Map.merge(updated_attrs, %{name: "Big Z"}))
      assert item.id != existing_item.id
      assert item.slug == "big_z"
    end

    test "update_item/2 with valid data updates the item" do
      item = item_fixture()
      assert {:ok, %Item{} = item} = Equipment.update_item(item, @update_attrs)
      assert item.name == "updated thing"
      assert item.public == false
      assert item.script == @update_attrs.script
      assert item.slug == "thing"
    end

    test "update_item/2 with invalid data returns error changeset" do
      item = item_fixture()
      assert {:error, %Ecto.Changeset{}} = Equipment.update_item(item, @invalid_attrs)
      assert item == Equipment.get_item(item.id)
    end

    test "delete_item/1 deletes the item" do
      item = item_fixture()
      assert {:ok, %Item{}} = Equipment.delete_item(item)
      refute Equipment.get_item(item.id)
    end

    test "change_item/1 returns a item changeset" do
      item = item_fixture()
      assert %Ecto.Changeset{} = Equipment.change_item(item)
    end

    test  "copy_fields/1" do
      item = item_fixture()
      assert %{description: "A thing",
               name: "thing",
               public: true,
               script: "#give gems, 1, @facing",
               slug: "thing",
               user_id: nil,
               consumable: false,
               weapon: false} == Equipment.copy_fields(item)
      assert %{} == Equipment.copy_fields(nil)
    end
  end
end
