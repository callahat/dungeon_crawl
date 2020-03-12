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

  test "autogen height and width must be less than or equal the max h&w" do
    changeset = Setting.changeset(%Setting{}, %{autogen_height: 40, autogen_width: 80, max_height: 40, max_width: 80})
    assert changeset.valid?

    changeset = Setting.changeset(%Setting{}, %{autogen_height: 41, autogen_width: 81, max_height: 40, max_width: 80})
    refute changeset.valid?
  end
end
