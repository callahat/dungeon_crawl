defmodule DungeonCrawl.UserView do
  use DungeonCrawl.Web, :view
  alias DungeonCrawl.User

  def first_name(%User{name: name}) do
    name
    |> String.split(" ")
    |> Enum.at(0)
  end
end
