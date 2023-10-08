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
    Map.merge(%DungeonExports{}, Jason.decode!(json))
    |> _convert_keys()
  end

  # double check that none of the state keys were atomized.
  # this would happen if a state key matched one of the @atoms,
  # and the Jason's keys function has no concept of parent contexts
  defp _convert_keys(json) when is_map(json) do
    json
    |> Map.to_list()
    |> _convert_keys()
    |> Enum.into(%{})
  end
  defp _convert_keys([]), do: []
  defp _convert_keys([{:state, values} | json]) do
    # State goes no deeper, and none of the keys in its associated map should be atoms
    [
      {:state, values} | _convert_keys(json)
    ]
  end
  defp _convert_keys([{key, value} | json]) do
    [
      {_convert_key(key), _convert_keys(value)} | _convert_keys(json)
    ]
  end
  defp _convert_keys(terminal_value), do: terminal_value

  defp _convert_key(key) do
    cond do
      Enum.member?(@atoms, key) -> String.to_atom(key)
      is_binary(key) && key =~ ~r/^\d+$/ -> String.to_integer(key)
      true -> key
    end
  end
end
