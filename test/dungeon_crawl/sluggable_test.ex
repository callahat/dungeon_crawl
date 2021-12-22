defmodule DungeonCrawl.SluggableTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Sluggable

  defmodule RepoMockWithRecords do
    def one(_), do: 1
    def preload(record, _), do: record
    def changeset(record, attrs), do: %Ecto.Changeset{}
    def update(changeset), do: {:ok, }
  end
  defmodule RepoMockWithoutRecords do
    def one(_), do: 0
    def preload(record, _), do: record
    def changeset(record, attrs), do: %Ecto.Changeset{}
  end

  defmodule TestModelWithoutUser do
    use Sluggable

    import Ecto.Changeset
    use Ecto.Schema
    embedded_schema do
      field :one, :integer, default: 10
      field :slug, :string, default: nil
      field :name, :string, default: "Test Record"
    end
  end

  defmodule TestModelWithUser do
    use Sluggable

    embedded_schema do
      field :one, :integer, default: 10
      field :user, :map, default: %{is_admin: false}
      field :slug, :string, default: nil
      field :name, :string, default: "Test Record"
    end
  end

  describe "add_slug/1" do
    test "it returns a tuple" do
      # when there are no records with the same name
      assert {:ok, %{slug: "test_record_10"}} =
               TestModelWithUser.add_slug({:ok, %TestModelWithUser{}}, RepoMockWithoutRecords)

      assert {:ok, %{slug: "test_record"}} =
               TestModelWithUser.add_slug({:ok, %TestModelWithUser{user: %{is_admin: true}}}, RepoMockWithoutRecords)

      assert {:ok, %{slug: "test_record_30"}} =
               TestModelWithUser.add_slug({:ok, %TestModelWithoutUser{id: 30}}, RepoMockWithoutRecords)
    end

    test "it uses the record id in the slug when the slug might already be taken" do
      assert {:ok, %{slug: "test_record_11"}} =
               TestModelWithUser.add_slug({:ok, %TestModelWithUser{id: 10}}, RepoMockWithRecords)

      assert {:ok, %{slug: "test_record_21"}} =
               TestModelWithUser.add_slug({:ok, %TestModelWithoutUser{id: 20}}, RepoMockWithRecords)
    end

    test "it does not overwrite an already set slug" do
      assert {:ok, %{slug: "one"}} =
               TestModelWithUser.add_slug({:ok, %TestModelWithUser{slug: "one"}}, RepoMockWithRecords)

      assert {:ok, %{slug: "three"}} =
               TestModelWithUser.add_slug({:ok, %TestModelWithoutUser{slug: "three"}}, RepoMockWithRecords)
    end
  end

  describe "add_slug!/1 is similar to add_slug" do
    test "it returns the updated record" do
      assert %{slug: "test_record_10"} =
               TestModelWithUser.add_slug!(%TestModelWithUser{}, RepoMockWithoutRecords)
    end

    test "it does not allow the slug to be updated" do
      assert %{slug: "sameslug"} =
               TestModelWithUser.add_slug!(%TestModelWithUser{slug: "sameslug"}, RepoMockWithoutRecords)
    end
  end

end
