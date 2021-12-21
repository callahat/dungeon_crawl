defmodule DungeonCrawl.Sound do
  @moduledoc """
  The Sound context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Sound.Effect

  @doc """
  Returns the list of effects.

  ## Examples

      iex> list_effects()
      [%Effect{}, ...]

  """
  def list_effects(%DungeonCrawl.Account.User{} = user) do
    Repo.all(from e in Effect,
             where: e.user_id == ^user.id,
             order_by: :slug)
  end
  def list_effects(:nouser) do
    Repo.all(from e in Effect,
             where: is_nil(e.user_id),
             order_by: :slug)
  end
  def list_effects do
    Repo.all(Effect)
  end

  @doc """
  Returns the list of effects that are either public or owned by the user.

  ## Examples

      iex> list_useable_effects(%User{})
      [%Effect{}, ...]
  """
  def list_useable_effects(%DungeonCrawl.Account.User{} = user) do
    Repo.all(from e in Effect,
             where: e.public or e.user_id == ^user.id,
             order_by: :slug)
  end

  @doc """
  Gets a single effect.

  Raises `Ecto.NoResultsError` if the Effect does not exist when using the ! form.

  ## Examples

      iex> get_effect!(123)
      %Effect{}

      iex> get_effect!(456)
      ** (Ecto.NoResultsError)

  """
  def get_effect(id), do: Repo.get(Effect, id)
  def get_effect!(id), do: Repo.get!(Effect, id)

  @doc """
  Gets a single effect given the slug.

  Raises `Ecto.NoResultsError` if the Effect does not exist when using the ! form.

  ## Examples

      iex> get_effect_by_slug!("thing")
      %Effect{}

      iex> get_effect_by_slug!("other_thing_12")
      ** (Ecto.NoResultsError)

  """
  def get_effect_by_slug(slug), do: Repo.get_by(Effect, %{slug: slug})
  def get_effect_by_slug!(slug), do: Repo.get_by!(Effect, %{slug: slug})

  @doc """
  Creates a effect.

  ## Examples

      iex> create_effect(%{field: value})
      {:ok, %Effect{}}

      iex> create_effect(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_effect(attrs \\ %{}) do
    %Effect{}
    |> Effect.changeset(attrs)
    |> Repo.insert()
    |> _add_slug()
  end

  defp _add_slug({:ok, effect}) do
    _gen_slug_changeset(effect)
    |> Repo.update()
  end
  defp _add_slug(error), do: error

  defp _add_slug!(effect) do
    _gen_slug_changeset(effect)
    |> Repo.update!()
  end

  defp _gen_slug_changeset(effect) do
    e = Repo.preload(effect, :user)
    slug = String.downcase(effect.name)
           |> String.replace(" ", "_")

    slug = if (e.user && e.user.is_admin || is_nil(e.user)) &&
                Repo.one(from e in Effect, where: e.slug == ^slug, select: count()) == 0 do
      slug
    else
      slug <> "_#{effect.id}"
    end

    effect
    |> Effect.changeset(%{})
    |> Ecto.Changeset.put_change(:slug, slug)
  end

  @doc """
  Updates a effect.

  ## Examples

      iex> update_effect(effect, %{field: new_value})
      {:ok, %Effect{}}

      iex> update_effect(effect, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_effect(%Effect{} = effect, attrs) do
    effect
    |> Effect.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a effect.

  ## Examples

      iex> delete_effect(effect)
      {:ok, %Effect{}}

      iex> delete_effect(effect)
      {:error, %Ecto.Changeset{}}

  """
  def delete_effect(%Effect{} = effect) do
    Repo.delete(effect)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking effect changes.

  ## Examples

      iex> change_effect(effect)
      %Ecto.Changeset{data: %Effect{}}

  """
  def change_effect(%Effect{} = effect, attrs \\ %{}) do
    Effect.changeset(effect, attrs)
  end
end
