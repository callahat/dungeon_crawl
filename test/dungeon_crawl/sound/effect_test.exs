defmodule DungeonCrawl.Sound.EffectTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Sound.Effect

  test "validation error when two effects attempt to have same slug" do
    e1 = insert_effect()
    e2 = insert_effect()

    # slug cannot be duplicated
    {result, changeset} = Effect.changeset(e2, %{})
                          |> Ecto.Changeset.put_change(:slug, e1.slug)
                          |> Repo.update()

    assert :error == result
    assert {"Slug already exists", _} = changeset.errors[:slug]
  end
end
