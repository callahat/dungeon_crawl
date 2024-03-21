defmodule DungeonCrawl.EctoAtomMap do
  @moduledoc """
  Ecto type for a map that should have atom keys. Should only be used with fields
  that have known atoms for keys, such as attributes for a database record.
  """

  use Ecto.Type
  def type, do: :jsonb

  def cast(data) do
    cond do
      is_nil(data) || data == %{} || data == "" ->
        {:ok, %{}}

      is_map(data) ->
        {:ok, _atomize_keys(data)}

      true ->
        :error
    end
  end

  # change from the DB representation
  def load(data) do
    if is_map(data) do
      {:ok, _atomize_keys(data)}
    else
      :error
    end
  end

  # ensure its ready to be written to the DB
  def dump(data) do
    cond do
      is_nil(data) ->
        {:ok, %{}}

      is_map(data) ->
        { :ok, data }

      true ->
        :error
    end
  end

  defp _atomize_keys(data) do
    data
    |> Enum.map(fn {k,v} when is_binary(k) -> {String.to_existing_atom(k), v}
                   key_value -> key_value
                end)
    |> Enum.into(%{})
  end
end
