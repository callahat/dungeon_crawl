defmodule DungeonCrawl.Dungeons.AssetImportTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.AssetImport

  import DungeonCrawl.ShippingFixtures

  @valid_attrs %{
    dungeon_import_id: 1,
    type: :sounds,
    importing_slug: "tmp_sound_1",
    action: :waiting,
    attributes: %{"zzfx_params" => "1,2,3,..."},
    existing_slug: "existing",
    existing_attributes: %{"zzfx_params" => "1,2,5,..."}}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = AssetImport.changeset(%AssetImport{}, @valid_attrs)
    assert changeset.valid?
    # since the action is the default, its not counted as a change so not among
    # the changes
    assert Map.drop(changeset.changes, [:attributes, :existing_attributes])
           == Map.drop(@valid_attrs, [:action, :attributes, :existing_attributes])
    # Custom Ecto type atomizes these keys
    assert changeset.changes.attributes == %{zzfx_params: "1,2,3,..."}
    assert changeset.changes.existing_attributes == %{zzfx_params: "1,2,5,..."}
  end

  test "changeset with invalid attributes" do
    changeset = AssetImport.changeset(%AssetImport{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "update_changeset with valid attrs" do
    valid_attrs = Map.merge(@valid_attrs, %{action: :create_new, resolved_slug: "testslug"})
    changeset = AssetImport.update_changeset(%AssetImport{}, valid_attrs)
    refute Map.drop(changeset.changes, [:action, :resolved_slug])
           == Map.drop(valid_attrs, [:action, :resolved_slug])
    assert changeset.changes.action == :create_new
    assert changeset.changes.resolved_slug == valid_attrs.resolved_slug
  end

  test "update_changeset with invalid attributes" do
    changeset = AssetImport.update_changeset(%AssetImport{}, %{action: "bob"})
    refute changeset.valid?
  end

  test "keys for attributes, existing_attributes are atoms" do
    import = import_fixture()
    {:ok, record} = AssetImport.changeset(%AssetImport{}, Map.put(@valid_attrs, :dungeon_import_id, import.id))
                  |> DungeonCrawl.Repo.insert
    assert Enum.all?(record.attributes, fn {k, _} -> is_atom(k) end)
    assert Enum.all?(record.existing_attributes, fn {k, _} -> is_atom(k) end)
  end

  test "errors when non existing atom keys given in attributes" do
    assert_raise ArgumentError,
                 ~r|not an already existing atom|,
                 fn ->
                   AssetImport.changeset(
                     %AssetImport{},
                     %{attributes: %{"not_a_valid_existing_atom" => "derp"}}
                   )
                 end
  end
end
