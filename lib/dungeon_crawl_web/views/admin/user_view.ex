defmodule DungeonCrawlWeb.Admin.UserView do
  use DungeonCrawl.Web, :view
  alias DungeonCrawl.Account.User

  def first_name(%User{name: name}) do
    name
    |> String.split(" ")
    |> Enum.at(0)
  end
end
