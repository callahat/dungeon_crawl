defmodule DungeonCrawl.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :max_height, :integer
      add :max_width, :integer
      add :autogen_height, :integer
      add :autogen_width, :integer
      add :max_instances, :integer
      add :autogen_solo_enabled, :boolean, default: false, null: false
      add :non_admin_dungeons_enabled, :boolean, default: false, null: false

      timestamps()
    end

  end
end
