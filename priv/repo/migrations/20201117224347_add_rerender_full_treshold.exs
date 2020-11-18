defmodule DungeonCrawl.Repo.Migrations.AddRerenderFullTreshold do
  use Ecto.Migration

  def up() do
    alter table(:settings) do
      add :full_rerender_threshold, :integer
    end

    flush()

    execute """
      UPDATE settings
      SET full_rerender_threshold = 50
    """
  end

  def down do
    alter table(:settings) do
      remove :full_rerender_threshold
    end
  end
end
