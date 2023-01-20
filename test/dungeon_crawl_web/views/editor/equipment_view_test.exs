defmodule DungeonCrawlWeb.Editor.EquipmentViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawlWeb.Editor.EquipmentView

  test "error_pre_tag/2 is like the error_tag, but uses a pre tag instead of default span" do
    {:error, changeset} = DungeonCrawl.Equipment.create_item(%{script: "#IF @bob, NOLABLE"})
    assert Phoenix.HTML.safe_to_string(EquipmentView.error_pre_tag(changeset, :script)) ==
           "<pre class=\"help-block\">Line 1: IF command references nonexistant label `NOLABLE`</pre>"
  end
end
