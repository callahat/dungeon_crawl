defmodule DungeonCrawl.Repo.Migrations.AddUserIdHashToUser do
  use Ecto.Migration
  import Ecto.Query
  alias DungeonCrawl.{Repo,User}

  def up do
    alter table(:users) do
      add :user_id_hash, :string
    end

    flush()

    Repo.all(User)
    |> Enum.each(fn(u) -> 
         User.changeset(u)
         |> Ecto.Changeset.put_change(:user_id_hash, :base64.encode(:crypto.strong_rand_bytes(24)))
         |> Repo.update!
       end)

    create index(:users, [:user_id_hash])
  end

  def down do
    alter table(:users) do
      remove :user_id_hash
    end
  end
end
