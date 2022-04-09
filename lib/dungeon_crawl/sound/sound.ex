defmodule DungeonCrawl.Sound do
  @moduledoc """
  The Sound context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Sound.Effect

  @copiable_fields [
    :name,
    :public,
    :slug,
    :user_id,
    :zzfx_params,
  ]

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
    |> Effect.add_slug()
  end
  def create_effect!(attrs \\ %{}) do
    %Effect{}
    |> Effect.changeset(attrs)
    |> Repo.insert!()
    |> Effect.add_slug!()
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

  # TODO: consolidate the find or create/update or create, seems like a lot of repeated functionality, using either Sluggable to another module
  @doc """
  Finds an effect that matches all the given fields.

  ## Examples

      iex> find_effect(%{field: value})
      %Effect{}

  """
  def find_effect(attrs \\ %{}) do
    Repo.one(from Effect.attrs_query(Map.delete(attrs, :slug)), limit: 1, order_by: :id)
  end

  @doc """
  Finds or creates an effect; mainly useful for the initial seeds.

  ## Examples

      iex> find_or_create_effect(%{field: value})
      {:ok, %Effect{}}

      iex> find_or_create_effect(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def find_or_create_effect(attrs \\ %{}) do
    case find_effect(attrs) do
      nil    -> create_effect(attrs)
      effect -> {:ok, effect}
    end
  end

  def find_or_create_effect!(attrs \\ %{}) do
    case find_effect(attrs) do
      nil  -> create_effect!(attrs)
      effect -> effect
    end
  end

  @doc """
  Finds and updates or creates an effect; mainly useful for the initial seeds.
  Looks up the effect first by slug (if given). If nothing with that slug
  is found, falls back to the "find_or_create_effect" function.

  ## Examples

      iex> update_or_create_effect(%{field: value})
      {:ok, %Effect{}}

      iex> update_or_create_effect(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_or_create_effect(slug, attrs) do
    existing_effect = Repo.one(from i in Effect, where: i.slug == ^slug, limit: 1, order_by: [desc: :id])

    if existing_effect do
      update_effect(existing_effect, attrs)
    else
      find_or_create_effect(attrs)
    end
  end

  def update_or_create_effect!(slug, attrs) do
    existing_effect = Repo.one(from i in Effect, where: i.slug == ^slug, limit: 1, order_by: [desc: :id])

    if existing_effect do
      {:ok, updated_effect} = update_effect(existing_effect, attrs)
      updated_effect
    else
      find_or_create_effect!(attrs)
    end
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

  @doc """
  Returns a copy of the fields from the given sound effect as a map.
  """
  def copy_fields(nil), do: %{}
  def copy_fields(effect) do
    Map.take(effect, @copiable_fields)
  end
end
