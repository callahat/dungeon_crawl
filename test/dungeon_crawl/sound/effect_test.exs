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

    # Junk zzfx_params
    {result, changeset} = Effect.changeset(e2, %{zzfx_params: "garbage"})
                          |> Repo.update()

    assert :error == result
    assert {"input should be 13 to 19 comma separated values, no whitespace, blanks ok." <>
            " Should match `-?\\d*\\.?\\d*(?:,-?\\d*\\.?\\d*){15,19}`", _} =
           changeset.errors[:zzfx_params]
  end

  test "extract_params/1" do
    good_params = "zzfx(...[,0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04]); // alarm"
    assert %{"params" => ",0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04"} =
      Effect.extract_params(%{zzfx_params: good_params})
    # Can accept as a map or just the straight up param string
    assert Effect.extract_params(%{zzfx_params: good_params}) == Effect.extract_params(good_params)

    # missing parameters/bad input
    refute Effect.extract_params(%{zzfx_params: "(...[0,130.8128,.1,.1,.34,3,1.88,,,.1,,.5,.04])"})
    refute Effect.extract_params(%{zzfx_params: "clearly wrong"})
    refute Effect.extract_params("also not valid")

    # using https://killedbyapixel.github.io/ZzFX/ with all zeros
    zeros = "0,0,0,,,0,,0,,,,,,,,,,0"
    assert %{"params" => ^zeros} = Effect.extract_params(%{zzfx_params: "zzfx(...[#{zeros}])"})

    everything = ".1,.2,.3,.5,.7,.8,1,.4,1,1.1,1.2,1.3,1.4,1.6,1.5,1.7,1.8,.9,.6,.99"
    assert %{"params" => ^everything} = Effect.extract_params(%{zzfx_params: "zzfx(...[#{everything}])"})
  end
end
