defmodule DungeonCrawl.Dungeons.AssetImportTest do
  use DungeonCrawl.DataCase

  require DungeonCrawl.SharedTests

  alias DungeonCrawl.Shipping.AssetImport

  @valid_attrs %{
    dungeon_import_id: 1,
    type: :sounds,
    importing_slug: "tmp_sound_1",
    action: :waiting,
    attributes: %{zzfx_params: "1,2,3,..."},
    existing_slug: "existing",
    existing_attributes: %{zzfx_params: "1,2,5,..."}}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = AssetImport.changeset(%AssetImport{}, @valid_attrs)
    assert changeset.valid?
    # since the action is the default, its not counted as a change so not among
    # the changes
    assert changeset.changes == Map.delete(@valid_attrs, :action)
  end

  test "changeset with invalid attributes" do
    changeset = AssetImport.changeset(%AssetImport{}, @invalid_attrs)
    refute changeset.valid?
  end
end
