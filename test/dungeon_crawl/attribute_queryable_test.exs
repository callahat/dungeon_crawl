defmodule DungeonCrawl.AttributeQueryableTest do
  use DungeonCrawl.DataCase

  defmodule TestModel do
    use DungeonCrawl.AttributeQueryable

    use Ecto.Schema
    schema "testings" do
      field :one, :integer, default: 10
      field :slug, :string, default: nil
      field :name, :string, default: "Test Record"
    end
  end

  describe "attrs_query/1" do
    test "returns a query" do
      assert DungeonCrawl.Repo.to_sql(:all, TestModel.attrs_query(%{one: 123, slug: "blah", name: nil})) ==
               {"SELECT t0.\"id\", t0.\"one\", t0.\"slug\", t0.\"name\" " <>
                "FROM \"testings\" AS t0 " <>
                "WHERE (t0.\"name\" IS NULL) AND (t0.\"one\" = $1) AND (t0.\"slug\" = $2)",
                 [123, "blah"]}
    end
  end

end
