defmodule DungeonCrawlWeb.ManageUserView do
  use DungeonCrawl.Web, :view
  alias DungeonCrawlWeb.User

  def first_name(%User{name: name}) do
    name
    |> String.split(" ")
    |> Enum.at(0)
  end
end
