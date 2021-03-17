defmodule DungeonCrawlWeb.TileShortlistViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawl.TileShortlists.TileShortlist
  alias DungeonCrawlWeb.TileShortlistView

  test "render/2" do
    errors = [
      other: "error",
      script: {"Unknown command: `DERP` - near line 1", []},
      state: {"Error parsing around: bad", []},
      name: {"should be at most %{count} character(s)",
       [count: 32, validation: :length, kind: :max, type: :string]}
    ]

    assert %{
              tile_shortlist: %{name: "stub"}
           } = TileShortlistView.render("tile_shortlist.json", %{tile_shortlist: %TileShortlist{name: "stub"}})

    assert %{
             errors: [
                %{detail: "error", field: :other},
                %{
                  detail: "Unknown command: `DERP` - near line 1",
                  field: :script
                },
                %{detail: "Error parsing around: bad", field: :state},
                %{detail: "should be at most 32 character(s)", field: :name}
             ]
           } = TileShortlistView.render("tile_shortlist.json", %{errors: errors})
  end
end
