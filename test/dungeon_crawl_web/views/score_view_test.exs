defmodule DungeonCrawlWeb.ScoreViewTest do
  use DungeonCrawlWeb.ConnCase, async: true
  import DungeonCrawlWeb.ScoreView

  test "format_duration/1" do
    assert "00' 00\"" == format_duration(0)
    assert "00' 57\"" == format_duration(57)

    assert "01' 59\"" == format_duration(119)
    assert "23' 01\"" == format_duration(22 * 60 + 61)
    assert "01:00:00" == format_duration(3600)

    assert "1 day, 00:01:02" == format_duration(3600 * 24 + 62)
    assert "2 days, 01:59:05" == format_duration(3600 * 48 + 60 * 60 + 60 * 59 + 5)
  end
end
