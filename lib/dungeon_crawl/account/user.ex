defmodule DungeonCrawl.Account.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "users" do
    field :name, :string
    field :username, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :user_id_hash, :string
    field :is_admin, :boolean, default: false

    field :background_color, :string, default: "whitesmoke"
    field :color, :string, default: "black"

    has_many :map_sets, DungeonCrawl.Dungeons.MapSet
    has_many :tile_shortlist, DungeonCrawl.TileShortlists.TileShortlist

    timestamps()
  end

  @doc false
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :username, :password, :background_color, :color])
    |> validate_required([:name, :username], message: "should be at least 1 character")
    |> validate_length(:username, min: 1, max: 20)
    |> validate_length(:password, min: 6, max: 100)
    |> unique_constraint(:username)
    |> TileTemplate.validate_colors()
    |> validate_colors_are_different()
    |> put_pass_hash()
  end

  defp put_pass_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Comeonin.Bcrypt.hashpwsalt(pass))
      _ ->
        changeset
    end
  end

  @doc false
  def registration_changeset(struct, params \\ %{}) do
    struct
    |> changeset(params)
    |> cast(params, [:user_id_hash])
    |> validate_required([:password,:user_id_hash])
  end

  @doc false
  def admin_registration_changeset(struct, params \\ %{}) do
    struct
    |> registration_changeset(params)
    |> cast(params, [:is_admin])
  end

  @doc false
  def admin_changeset(struct, params \\ %{}) do
    struct
    |> changeset(params)
    |> cast(params, [:is_admin])
  end

  @doc false
  def put_user_id_hash(changeset, user_id_hash \\ nil) do
    case changeset do
      %Ecto.Changeset{valid?: true} ->
        put_change(changeset, :user_id_hash, user_id_hash || :base64.encode(:crypto.strong_rand_bytes(24)))
      _ ->
        changeset
    end
  end

  @doc false
  def validate_colors_are_different(changeset) do
    if colors_match?(changeset.data, changeset.changes) do
      changeset
      |> add_error(:color, "Color and Background Color must be different")
      |> add_error(:background_color, "Color and Background Color must be different")
    else
      changeset
    end
  end

  def colors_match?(map_1, map_2 \\ %{}) do
    %{color: color, background_color: background_color} = \
      Map.take(map_1, [:color, :background_color])
      |> Map.merge(Map.take(map_2, [:color, :background_color]))
    color == background_color
  end
end
