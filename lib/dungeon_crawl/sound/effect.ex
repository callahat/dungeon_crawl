defmodule DungeonCrawl.Sound.Effect do
  use DungeonCrawl.Sluggable
  use DungeonCrawl.AttributeQueryable
  use Ecto.Schema
  import Ecto.Changeset

  schema "effects" do
    field :name, :string
    field :slug, :string
    field :public, :boolean, default: false
    field :zzfx_params, :string

    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(effect, attrs) do
    effect
    |> cast(attrs, [:name, :zzfx_params, :public, :user_id])
    |> validate_required([:name, :zzfx_params])
    |> _validate_zzfx_params()
    |> unique_constraint(:slug, name: :effects_slug_index, message: "Slug already exists")
  end

  @zzfx_param_regex ~r/(?<params>-?\d*\.?\d*(?:,-?\d*\.?\d*){13,19})/

  def extract_params(%{zzfx_params: zzfx_params}), do: extract_params(zzfx_params)
  def extract_params(zzfx_params), do: Regex.named_captures(@zzfx_param_regex, zzfx_params)

  defp _validate_zzfx_params(%{changes: %{zzfx_params: zzfx_params}} = changeset) do
    with %{"params" => _} <- extract_params(zzfx_params) do
      changeset
    else
      _ -> add_error(changeset,
                     :zzfx_params,
                     "input should be 13 to 19 comma separated values, no whitespace, blanks ok." <>
                       " Should match `-?\\d*\\.?\\d*(?:,-?\\d*\\.?\\d*){13,19}`")
    end
  end
  defp _validate_zzfx_params(changeset), do: changeset
end
