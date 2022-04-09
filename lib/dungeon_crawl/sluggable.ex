defmodule DungeonCrawl.Sluggable do
  @moduledoc """
  Adds functions for adding a slug to a record after it is created.
  A record with a slug will not get a new one.
  """

  defmacro __using__(_params) do
    quote do
      use Ecto.Schema

      alias DungeonCrawl.Repo
      import Ecto.Query

      def add_slug(record, repo \\ Repo)
      def add_slug({:ok, %{slug: slug} = record}, repo) when is_nil(slug) do
        _gen_slug_changeset(record, repo)
        |> repo.update()
      end
      def add_slug(error_or_noop, _), do: error_or_noop

      def add_slug!(record, repo \\ Repo)
      def add_slug!(%{slug: slug} = record, repo) when is_nil(slug) do
        _gen_slug_changeset(record, repo)
        |> repo.update!()
      end
      def add_slug!(record, _), do: record

      defp _gen_slug_changeset(record, repo) do
        slug = String.downcase(record.name)
               |> String.replace(" ", "_")

        slug = if _bare_slug(slug, record, repo),
                  do: slug,
                  else: slug <> "_#{record.id}"

        record
        |> quote(do: unquote(__MODULE__)).changeset(%{})
        |> Ecto.Changeset.put_change(:slug, slug)
      end

      defp _bare_slug(slug, %{user: _} = record, repo) do
        user = repo.preload(record, :user).user

        (user && user.is_admin || is_nil(user)) &&
          _slug_not_taken?(slug, repo)
      end
      defp _bare_slug(slug, record, repo) do
        _slug_not_taken?(slug, repo)
      end

      defp _slug_not_taken?(slug, repo) do
        repo.one(from r in quote(do: unquote(__MODULE__)),
                 where: r.slug == ^slug, select: count()) == 0
      end

    end
  end
end
