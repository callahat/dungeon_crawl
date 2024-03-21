defmodule DungeonCrawl.SluggableTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Sluggable

  defmodule RepoMockWithRecords do
    def one(_), do: 1
    def preload(record, _), do: record
    def changeset(_record, _attrs), do: %Ecto.Changeset{}
    def update(changeset), do: {:ok, Map.merge(changeset.data, changeset.changes)}
    def update!(changeset), do: Map.merge(changeset.data, changeset.changes)
  end
  defmodule RepoMockWithoutRecords do
    def one(_), do: 0
    def preload(record, _), do: record
    def changeset(_record, _attrs), do: %Ecto.Changeset{}
    def update(changeset), do: {:ok, Map.merge(changeset.data, changeset.changes)}
    def update!(changeset), do: Map.merge(changeset.data, changeset.changes)
  end

  defmodule TestModelWithoutUser do
    use Sluggable

    use Ecto.Schema
    import Ecto.Changeset
    embedded_schema do
      field :one, :integer, default: 10
      field :slug, :string, default: nil
      field :name, :string, default: "Test Record"
    end
    @doc false
    def changeset(model, attrs), do: cast(model, attrs, [:one, :name])
  end

  defmodule TestModelWithUser do
    use Sluggable

    use Ecto.Schema
    import Ecto.Changeset
    embedded_schema do
      field :one, :integer, default: 10
      field :user, :map, default: %{is_admin: false}
      field :slug, :string, default: nil
      field :name, :string, default: "Test Record"
    end
    @doc false
    def changeset(model, attrs), do: cast(model, attrs, [:one, :user, :name])
  end

  setup do
    {:ok, %{with_user: %TestModelWithUser{id: 10},
            with_admin: %TestModelWithUser{id: 20, user: %{is_admin: true}},
            no_user: %TestModelWithoutUser{id: 30}}}
  end

  describe "add_slug/1" do
    test "it returns a tuple", model do
      # when there are no records with the same name
      assert {:ok, %{slug: "test_record_10"}} =
               TestModelWithUser.add_slug({:ok, model.with_user}, RepoMockWithoutRecords)

      assert {:ok, %{slug: "test_record"}} =
               TestModelWithUser.add_slug({:ok, model.with_admin}, RepoMockWithoutRecords)

      assert {:ok, %{slug: "test_record"}} =
               TestModelWithoutUser.add_slug({:ok, model.no_user}, RepoMockWithoutRecords)
    end

    test "it uses the record id in the slug when the slug might already be taken", model do
      assert {:ok, %{slug: "test_record_10"}} =
               TestModelWithUser.add_slug({:ok, model.with_user}, RepoMockWithRecords)

      assert {:ok, %{slug: "test_record_20"}} =
               TestModelWithUser.add_slug({:ok, model.with_admin}, RepoMockWithRecords)

      assert {:ok, %{slug: "test_record_30"}} =
               TestModelWithoutUser.add_slug({:ok, model.no_user}, RepoMockWithRecords)
    end

    test "it does not overwrite an already set slug", model do
      assert {:ok, %{slug: "one"}} =
               TestModelWithUser.add_slug({:ok, %{model.with_user | slug: "one"}}, RepoMockWithRecords)

      assert {:ok, %{slug: "two"}} =
               TestModelWithUser.add_slug({:ok, %{model.with_admin | slug: "two"}}, RepoMockWithRecords)

      assert {:ok, %{slug: "three"}} =
               TestModelWithoutUser.add_slug({:ok, %{model.no_user |slug: "three"}}, RepoMockWithRecords)
    end
  end

  describe "add_slug!/1 is similar to add_slug" do
    test "it returns the updated record", model do
      assert %{slug: "test_record_10"} =
               TestModelWithUser.add_slug!(model.with_user, RepoMockWithoutRecords)
    end

    test "it does not allow the slug to be updated", model do
      assert %{slug: "sameslug"} =
               TestModelWithUser.add_slug!(%{model.with_user | slug: "sameslug"}, RepoMockWithoutRecords)
    end
  end

  describe "parse_identifer/1" do
    import DungeonCrawl.Sluggable, only: [parse_identifier: 1]

    test "an integer in string form becomes an integer" do
      assert 1234 == parse_identifier("1234")
    end

    test "an integer stays an integer" do
      assert 1234 == parse_identifier(1234)
    end

    test "a slug stays a string" do
      assert "slug_123" == parse_identifier("slug_123")
      assert "slug" == parse_identifier("slug")
    end
  end
end
