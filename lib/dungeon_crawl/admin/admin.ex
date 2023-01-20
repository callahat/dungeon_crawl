defmodule DungeonCrawl.Admin do
  @moduledoc """
  The Admin context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Admin.Setting


  @doc """
  Get the setting record. If it has not yet been created, it will be created with the defaults.

  ## Examples

      iex> get_setting(123)
      %Setting{}
  """
  def get_setting() do
    case Repo.one(from s in Setting, order_by: [asc: :id], limit: 1) do
      nil ->
        Repo.insert(%Setting{})
        get_setting()

      setting ->
        setting
    end
  end

  @doc """
  Updates the setting record.

  ## Examples

      iex> update_setting(%{field: new_value})
      {:ok, %Setting{}}

      iex> update_setting(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_setting(attrs) do
    get_setting()
    |> Setting.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking setting changes.

  ## Examples

      iex> change_setting(setting)
      %Ecto.Changeset{source: %Setting{}}

  """
  def change_setting(%Setting{} = setting) do
    Setting.changeset(setting, %{})
  end
end
