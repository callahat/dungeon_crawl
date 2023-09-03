defmodule DungeonCrawlWeb.DungeonView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Account
  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawlWeb.SharedView
  alias DungeonCrawl.Repo

  import DungeonCrawlWeb.ScoreView, only: [format_duration: 1]

  def can_start_new_instance(dungeon_id) do
    is_nil(Admin.get_setting.max_instances) or Dungeons.instance_count(dungeon_id) < Admin.get_setting.max_instances
  end

  def saved_game(dungeon) do
    if dungeon.saved do
      "<i class=\"fa fa-floppy-o\"></i>"
    else
      ""
    end
  end

  def favorite_star(dungeon, true) do
    if dungeon.favorited do
      """
      <i class="fa fa-star" aria-hidden="true" phx-click="unfavorite_#{dungeon.line_identifier}"></i>
      """
    else
      """
      <i class="fa fa-star-o" aria-hidden="true" phx-click="favorite_#{dungeon.line_identifier}"></i>
      """
    end
  end

  def favorite_star(_, _) do
    ""
  end

  def favorite_star(dungeon) do
    if dungeon.favorited do
      """
      <i class="fa fa-star" aria-hidden="true"></i>
      """
    else
      ""
    end
  end

  def dungeon_pin(dungeon, true) do
    if dungeon.pinned do
      """
      <i class="fa fa-thumb-tack" aria-hidden="true" phx-click="unpin_#{dungeon.line_identifier}"></i>
      """
    else
      """
      <i class="fa fa-circle-o" aria-hidden="true" phx-click="pin_#{dungeon.line_identifier}"></i>
      """
    end
  end

  def dungeon_pin(dungeon, _) do
    if dungeon.pinned do
      """
      <i class="fa fa-thumb-tack" aria-hidden="true" ></i>
      """
    else
      ""
    end
  end

  def dungeon_pin(dungeon) do
    if dungeon.pinned do
      """
      <i class="fa fa-thumb-tack" aria-hidden="true"></i>
      """
    else
      ""
    end
  end

  def formatted_saved_duration(save) do
    save.state[:duration]
    |> format_duration()
  end
end
