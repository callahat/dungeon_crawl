defmodule DungeonCrawl.Equipment.ItemTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Equipment.Item

  test "validation error when two items attempt to have same slug" do
    i1 = insert_item()
    i2 = insert_item()

    # slug cannot be duplicated
    {result, changeset} = Item.changeset(i2, %{})
                          |> Ecto.Changeset.put_change(:slug, i1.slug)
                          |> Repo.update()

    assert :error == result
    assert {"Slug already exists", _} = changeset.errors[:slug]
  end
end
