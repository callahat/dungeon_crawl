defmodule DungeonCrawl.Admin.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :autogen_solo_enabled, :boolean, default: true
    field :max_height, :integer, default: 80
    field :max_width, :integer, default: 120
    field :autogen_height, :integer, default: 40
    field :autogen_width, :integer, default: 80
    field :max_instances, :integer
    field :non_admin_dungeons_enabled, :boolean, default: true

    timestamps()
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:max_height, :max_width, :autogen_height, :autogen_width, :max_instances, :autogen_solo_enabled, :non_admin_dungeons_enabled])
    |> validate_required([:max_height, :max_width, :autogen_height, :autogen_width, :autogen_solo_enabled, :non_admin_dungeons_enabled])
    |> validate_inclusion(:max_height, 20..80, message: "must be between 20 and 80")
    |> validate_inclusion(:max_width, 20..120, message: "must be between 20 and 120")
    |> validate_inclusion(:autogen_height, 20..80, message: "must be between 20 and 80")
    |> validate_inclusion(:autogen_width, 20..120, message: "must be between 20 and 120")
    |> _validate_less_than_or_equal(:autogen_height, :max_height)
    |> _validate_less_than_or_equal(:autogen_width, :max_width)
  end

  defp _validate_less_than_or_equal(changeset, lower_field, higher_field) do
    if get_field(changeset, lower_field) > get_field(changeset, higher_field) do
      changeset
      |> add_error(lower_field, "Cannot be higher than %{limit}", [limit: get_field(changeset, higher_field)])
    else
      changeset
    end
  end
end
