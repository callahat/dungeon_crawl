defmodule DungeonCrawl.Repo.Migrations.CreateTileShortlists do
  use Ecto.Migration

  def change do
    create table(:tile_shortlists) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :tile_template_id, references(:tile_templates, on_delete: :delete_all)

      add :name, :string
      add :character, :string
      add :description, :string
      add :color, :string
      add :background_color, :string

      add :script, :string, size: 2048
      add :state, :string
      add :slug, :string

      add :animate_random, :boolean
      add :animate_colors, :string, size: 255
      add :animate_background_colors, :string, size: 255
      add :animate_characters, :string, size: 32
      add :animate_period, :integer

      timestamps()
    end

    create index(:tile_shortlists, [:user_id])
    create index(:tile_shortlists, [:tile_template_id])
  end
end
