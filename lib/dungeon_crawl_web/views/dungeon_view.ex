defmodule DungeonCrawlWeb.DungeonView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawlWeb.SharedView
  alias DungeonCrawl.Repo

  def can_start_new_instance(dungeon_id) do
    is_nil(Admin.get_setting.max_instances) or Dungeons.instance_count(dungeon_id) < Admin.get_setting.max_instances
  end

  def favorite_star(dungeon, true) do
    if dungeon.favorited do
      """
      <i class="fa fa-star float-right" aria-hidden="true" phx-click="unfavorite_#{dungeon.line_identifier}"></i>
      """
    else
      """
      <i class="fa fa-star-o float-right" aria-hidden="true" phx-click="favorite_#{dungeon.line_identifier}"></i>
      """
    end
  end

  def favorite_star(_, _) do
    ""
  end
end
