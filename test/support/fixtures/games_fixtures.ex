defmodule DungeonCrawl.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DungeonCrawl.Games` context.
  """

  import DungeonCrawlWeb.TestHelpers

  alias DungeonCrawl.Games

  @doc """
  Generate a save.
  """
  def save_fixture(attrs \\ %{}) do
    user_id_hash = attrs[:user_id_hash] || insert_user().user_id_hash
    level_instance_id = attrs[:level_instance_id] || insert_autogenerated_level_instance().id

    {:ok, save} =
      attrs
      |> Enum.into(%{
        col: 42,
        row: 42,
        state: "player: true",
        user_id_hash: user_id_hash,
        level_instance_id: level_instance_id,
      })
      |> Games.create_save()

    save
  end
end
