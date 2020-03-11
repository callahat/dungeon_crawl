defmodule DungeonCrawl.Admin.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :autogen_solo_enabled, :boolean, default: true
    field :max_height, :integer, default: 80
    field :max_instances, :integer
    field :max_width, :integer, default: 120
    field :non_admin_dungeons_enabled, :boolean, default: true

    timestamps()
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:max_height, :max_width, :max_instances, :autogen_solo_enabled, :non_admin_dungeons_enabled])
    |> validate_required([:max_height, :max_width, :autogen_solo_enabled, :non_admin_dungeons_enabled])
    |> validate_inclusion(:max_height, 20..80, message: "must be between 20 and 80")
    |> validate_inclusion(:max_width, 20..120, message: "must be between 20 and 120")
  end
end
