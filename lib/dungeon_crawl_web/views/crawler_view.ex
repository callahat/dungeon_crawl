defmodule DungeonCrawlWeb.CrawlerView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeon

  def can_start_new_instance(dungeon_id) do
    is_nil(Admin.get_setting.max_instances) or Dungeon.instance_count(dungeon_id) < Admin.get_setting.max_instances
  end
end
