defmodule DungeonCrawl.ShippingTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping

  describe "dungeon_exports" do
    alias DungeonCrawl.Shipping.Export

    import DungeonCrawl.ShippingFixtures

    @invalid_attrs %{data: nil, status: nil}

    test "list_dungeon_exports/0 returns all dungeon_exports" do
      export = export_fixture()
      assert Shipping.list_dungeon_exports() == [export]
    end

    test "list_dungeon_exports/1 returns all dungeon_exports" do
      export = export_fixture()
      export_fixture(%{user_id: insert_user().id})
      assert Shipping.list_dungeon_exports(export.user_id) == [export]
    end

    test "get_export!/1 returns the export with given id" do
      export = export_fixture()
      assert Shipping.get_export!(export.id) == export
    end

    test "create_export/1 with valid data creates a export" do
      valid_attrs = %{
        user_id: insert_user().id,
        dungeon_id: insert_dungeon().id,
        data: "some data",
        file_name: "dungeon.json",
        status: :completed}

      assert {:ok, %Export{} = export} = Shipping.create_export(valid_attrs)
      assert export.data == "some data"
      assert export.status == :completed
    end

    test "create_export/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Shipping.create_export(@invalid_attrs)
    end

    test "update_export/2 with valid data updates the export" do
      export = export_fixture()
      update_attrs = %{data: "some updated data", status: :completed}

      assert {:ok, %Export{} = export} = Shipping.update_export(export, update_attrs)
      assert export.data == "some updated data"
      assert export.status == :completed
    end

    test "update_export/2 with invalid data returns error changeset" do
      export = export_fixture()
      assert {:error, %Ecto.Changeset{}} = Shipping.update_export(export, @invalid_attrs)
      assert export == Shipping.get_export!(export.id)
    end

    test "delete_export/1 deletes the export" do
      export = export_fixture()
      assert {:ok, %Export{}} = Shipping.delete_export(export)
      assert_raise Ecto.NoResultsError, fn -> Shipping.get_export!(export.id) end
    end

    test "change_export/1 returns a export changeset" do
      export = export_fixture()
      assert %Ecto.Changeset{} = Shipping.change_export(export)
    end
  end

  describe "dungeon_imports" do
    alias DungeonCrawl.Shipping.Import

    import DungeonCrawl.ShippingFixtures

    @invalid_attrs %{data: nil, line_identifier: nil, status: nil}

    test "list_dungeon_imports/0 returns all dungeon_imports" do
      import = import_fixture()
      import_fixture(%{user_id: insert_user().id})
      assert Shipping.list_dungeon_imports(import.user_id) == [import]
    end

    test "list_dungeon_imports/1 returns all dungeon_imports" do
      import = import_fixture()
      assert Shipping.list_dungeon_imports() == [import]
    end

    test "get_import!/1 returns the import with given id" do
      import = import_fixture()
      assert Shipping.get_import!(import.id) == import
    end

    test "create_import/1 with valid data creates a import" do
      valid_attrs = %{
        user_id: insert_user().id,
        dungeon_id: insert_dungeon().id,
        data: "some data",
        line_identifier: 42,
        file_name: "dungeon.json",
        status: :completed}

      assert {:ok, %Import{} = import} = Shipping.create_import(valid_attrs)
      assert import.data == "some data"
      assert import.line_identifier == 42
      assert import.status == :completed
    end

    test "create_import/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Shipping.create_import(@invalid_attrs)
    end

    test "update_import/2 with valid data updates the import" do
      import = import_fixture()
      update_attrs = %{data: "some updated data", line_identifier: 43, status: :completed}

      assert {:ok, %Import{} = import} = Shipping.update_import(import, update_attrs)
      assert import.data == "some updated data"
      assert import.line_identifier == 43
      assert import.status == :completed
    end

    test "update_import/2 with invalid data returns error changeset" do
      import = import_fixture()
      assert {:error, %Ecto.Changeset{}} = Shipping.update_import(import, @invalid_attrs)
      assert import == Shipping.get_import!(import.id)
    end

    test "delete_import/1 deletes the import" do
      import = import_fixture()
      assert {:ok, %Import{}} = Shipping.delete_import(import)
      assert_raise Ecto.NoResultsError, fn -> Shipping.get_import!(import.id) end
    end

    test "change_import/1 returns a import changeset" do
      import = import_fixture()
      assert %Ecto.Changeset{} = Shipping.change_import(import)
    end
  end
end
