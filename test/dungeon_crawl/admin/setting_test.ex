defmodule DungeonCrawl.Admin.SettingTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Admin.Setting

  @valid_attrs %{max_height: 40, max_width: 80, max_instances: 1, autogen_solo_enabled: false}
  @invalid_attrs %{max_height: 500}

  test "changeset with valid attributes" do
    changeset = Setting.changeset(%Setting{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Setting.changeset(%Setting{}, @invalid_attrs)
    refute changeset.valid?
  end
end
