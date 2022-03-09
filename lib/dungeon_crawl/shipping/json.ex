defmodule DungeonCrawl.Shipping.Json do
  @moduledoc """
  Serializes and deserializes dungeon exports and imports to or from a JSON format
  for writing or reading from a file.
  """

  alias DungeonCrawl.Shipping.DungeonExports

  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawl.Dungeons.Dungeon
  alias DungeonCrawl.Dungeons.Level
  alias DungeonCrawl.Dungeons.Tile
  alias DungeonCrawl.Equipment.Item
  alias DungeonCrawl.Sound.Effect

  @atoms Map.keys(%TileTemplate{})
         ++ Map.keys(%Dungeon{})
         ++ Map.keys(%Level{})
         ++ Map.keys(%Tile{})
         ++ Map.keys(%Item{})
         ++ Map.keys(%Effect{})
         ++ Map.keys(%DungeonExports{})
         ++ [:temp_tt_id, :temp_item_id, :temp_sound_id, :tile_data, :user_name]
         |> Enum.map(&to_string/1)
         |> Enum.uniq()

  def encode!(export) do
    Jason.encode!(export)
  end

  def decode!(json) do
    Map.merge(%DungeonExports{}, Jason.decode!(json, keys: &_keys/1))
  end

  defp _keys(key) do
    cond do
      Enum.member?(@atoms, key) -> String.to_atom(key)
      key =~ ~r/^\d+$/ -> String.to_integer(key)
      true -> key
    end
  end
end