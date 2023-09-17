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
    |> _atomize_state_keys()
  end

  defp _keys(key) do
    cond do
      Enum.member?(@atoms, key) -> String.to_atom(key)
      key =~ ~r/^\d+$/ -> String.to_integer(key)
      true -> key
    end
  end

  # Turns the keys in the state maps into atoms, instead of strings.
  # Longer term probably want to just use strings instead of atoms for
  # state related stuff
  defp _atomize_state_keys(json) when is_map(json) do
    json
    |> Map.to_list()
    |> _atomize_state_keys()
    |> Enum.into(%{})
  end
  defp _atomize_state_keys([]), do: []
  defp _atomize_state_keys([{:state, values} | json]) do
    atomized = Enum.map(values, fn {key, value} -> {String.to_atom(key), value} end)
               |> Enum.into(%{})
    [
      {:state, atomized} | _atomize_state_keys(json)
    ]
  end
  defp _atomize_state_keys([{key, value} | json]) do
    recursed = _atomize_state_keys(value)
    [
      {key, recursed} | _atomize_state_keys(json)
    ]
  end
  defp _atomize_state_keys(terminal_value), do: terminal_value
end
