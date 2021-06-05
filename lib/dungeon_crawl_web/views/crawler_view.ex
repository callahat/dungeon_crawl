defmodule DungeonCrawlWeb.CrawlerView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawlWeb.SharedView
  alias DungeonCrawl.Repo

  def can_start_new_instance(map_set_id) do
    is_nil(Admin.get_setting.max_instances) or Dungeons.instance_count(map_set_id) < Admin.get_setting.max_instances
  end
end
