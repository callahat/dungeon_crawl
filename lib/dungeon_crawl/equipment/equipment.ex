defmodule DungeonCrawl.Equipment do
  @moduledoc """
  The Equipment context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Equipment.Item

  @doc """
  Returns the list of items.

  ## Examples

      iex> list_items()
      [%Item{}, ...]

  """
  def list_items(%DungeonCrawl.Account.User{} = user) do
    Repo.all(from i in Item,
             where: i.user_id == ^user.id,
             order_by: :slug)
  end
  def list_items(:nouser) do
    Repo.all(from i in Item,
             where: is_nil(i.user_id),
             order_by: :slug)
  end
  def list_items() do
    Repo.all(from i in Item,
             order_by: :slug)
  end

  @doc """
  Gets a single item.

  Returns nil if the Item does not exist.

  When given an author (%User{}), only returns the item if it may
  be used given the author of the level.

  ## Examples

      iex> get_item(123)
      %Item{}

      iex> get_item(456)
      nil

      iex> get_item("slug_thing")
      %Item{}

      iex> get_item("slug_thing", %Account.User{is_admin: true})
      %Item{}

      iex> get_item("slug_thing", %Account.User{username: "someone else})
      nil
  """
  def get_item(nil), do: nil
  def get_item(id) when is_integer(id), do: Repo.get(Item, id)
  def get_item(slug), do: Repo.get_by(Item, %{slug: slug})
  def get_item!(id) when is_integer(id), do: Repo.get!(Item, id)
  def get_item!(slug), do: Repo.get_by!(Item, %{slug: slug})

  def get_item(identifier, author) do
    item = get_item(identifier)

    if item && (is_nil(author) ||
         is_nil(item.user_id) ||
         item.public ||
         author.is_admin ||
         author.id == item.user_id) do
      item
    else
      nil
    end
  end

  @doc """
  Creates a item.

  ## Examples

      iex> create_item(%{field: value})
      {:ok, %Item{}}

      iex> create_item(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_item(attrs \\ %{}) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
    |> Item.add_slug()
  end

  def create_item!(attrs \\ %{}) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert!()
    |> Item.add_slug!()
  end

  @doc """
  Updates a item.

  ## Examples

      iex> update_item(item, %{field: new_value})
      {:ok, %Item{}}

      iex> update_item(item, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end


  @doc """
  Finds or creates an item; mainly useful for the initial seeds.

  Does not accept attributes of `nil`

  ## Examples

      iex> find_or_create_item(%{field: value})
      {:ok, %Item{}}

      iex> find_or_create_item(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def find_or_create_item(attrs \\ %{}) do
    case Repo.one(from _attrs_query(attrs), limit: 1, order_by: :id) do
      nil  -> create_item(attrs)
      item -> {:ok, item}
    end
  end

  def find_or_create_item!(attrs \\ %{}) do
    case Repo.one(from _attrs_query(attrs), limit: 1, order_by: :id) do
      nil  -> create_item!(attrs)
      item -> item
    end
  end

  defp _attrs_query(attrs) do
    Map.delete(attrs, :slug)
    |> Enum.reduce(Item,
         fn {x,y}, query ->
           field_query = [{x, y}] #dynamic keyword list
           query|>where(^field_query)
         end)
  end

  @doc """
  Finds and updates or creates an item; mainly useful for the initial seeds.
  Looks up the item first by slug (if given). If one is found, and the latest
  When one is found, the newest item will be returned (ie, last created, even
  if not active) to ensure get the latest version of the seeded item. If nothing with that slug
  is found, falls back to the "find_or_create_item" function.

  Does not accept attributes of `nil`

  ## Examples

      iex> update_or_create_item(%{field: value})
      {:ok, %Item{}}

      iex> update_or_create_item(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_or_create_item(slug, attrs) do
    existing_item = Repo.one(from i in Item, where: i.slug == ^slug, limit: 1, order_by: [desc: :id])

    if existing_item do
      update_item(existing_item, attrs)
    else
      find_or_create_item(attrs)
    end
  end

  def update_or_create_item!(slug, attrs) do
    existing_item = Repo.one(from i in Item, where: i.slug == ^slug, limit: 1, order_by: [desc: :id])

    if existing_item do
      {:ok, updated_item} = update_item(existing_item, attrs)
      updated_item
    else
      find_or_create_item!(attrs)
    end
  end

  @doc """
  Deletes a item.

  ## Examples

      iex> delete_item(item)
      {:ok, %Item{}}

      iex> delete_item(item)
      {:error, %Ecto.Changeset{}}

  """
  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking item changes.

  ## Examples

      iex> change_item(item)
      %Ecto.Changeset{data: %Item{}}

  """
  def change_item(%Item{} = item, attrs \\ %{}) do
    Item.changeset(item, attrs)
  end
end
