defmodule DungeonCrawl.AdminTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Admin

  describe "settings" do
    alias DungeonCrawl.Admin.Setting

    @update_attrs %{autogen_solo_enabled: false, max_height: 77, max_instances: 43, max_width: 111, non_admin_dungeons_enabled: false}
    @invalid_attrs %{autogen_solo_enabled: nil, max_height: nil, max_instances: nil, max_width: nil, non_admin_dungeons_enabled: nil}

    test "get_setting/1 returns the setting record, there will be only one, it will be created with defaults if not exists" do
      assert setting = Admin.get_setting()
      assert setting.autogen_solo_enabled == true
      assert setting.max_height == 80
      assert setting.max_width == 120
      assert setting.autogen_height == 40
      assert setting.autogen_width == 80
      assert setting.max_instances == nil
      assert setting.non_admin_dungeons_enabled == true
    end

    test "update_setting/2 with valid data updates the setting" do
      assert {:ok, %Setting{} = setting} = Admin.update_setting(@update_attrs)
      assert setting.autogen_solo_enabled == false
      assert setting.max_height == 77
      assert setting.max_width == 111
      assert setting.autogen_height == 40
      assert setting.autogen_width == 80
      assert setting.max_instances == 43
      assert setting.non_admin_dungeons_enabled == false
    end

    test "update_setting/2 with invalid data returns error changeset" do
      setting = Admin.get_setting()
      assert {:error, %Ecto.Changeset{}} = Admin.update_setting(@invalid_attrs)
      assert setting == Admin.get_setting()
    end

    test "change_setting/1 returns a changeset" do
      assert %Ecto.Changeset{} = Admin.change_setting(%Setting{})
    end
  end
end
