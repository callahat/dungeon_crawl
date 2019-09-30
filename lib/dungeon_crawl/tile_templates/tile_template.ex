defmodule DungeonCrawl.TileTemplates.TileTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @color_match ~r/\A(?:[a-z]+|#(?:[\da-f]{3}){1,2})\z/i

  alias DungeonCrawl.Scripting
  alias DungeonCrawl.TileState

  schema "tile_templates" do
    field :active, :boolean, default: false
    field :background_color, :string
    field :character, :string
    field :color, :string
    field :description, :string
    field :deleted_at, :naive_datetime
    field :name, :string
    field :public, :boolean, default: false
    field :script, :string, default: ""
    field :state, :string
    field :version, :integer, default: 1
    has_many :map_tiles, DungeonCrawl.Dungeon.MapTile
    belongs_to :previous_version, DungeonCrawl.TileTemplates.TileTemplate, foreign_key: :previous_version_id
    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(tile_template, attrs) do
    tile_template
    |> cast(attrs, [:name, :character, :description, :color, :background_color, :script,:version,:active,:public,:previous_version_id,:deleted_at,:user_id,:state])
    |> validate_required([:name, :description])
    |> validate_renderables
    |> validate_script
    |> validate_state
  end

  @doc false
  def validate_renderables(changeset) do
    changeset
    |> validate_format(:color, @color_match)
    |> validate_format(:background_color, @color_match)
    |> validate_length(:character, min: 1, max: 1)
  end

  @doc false
  def validate_script(changeset) do
    script = get_field(changeset, :script)
    _validate_script(changeset, script)
  end

  defp _validate_script(changeset, nil), do: changeset
  defp _validate_script(changeset, script) do
    case Scripting.Parser.parse(script) do
      {:error, message, program} -> add_error(changeset, :script, "#{message} - near line #{Enum.count(program.instructions) + 1}")
      {:ok, program}             -> _validate_program(changeset, program)
    end
  end

  defp _validate_program(changeset, program) do
    case Scripting.ProgramValidator.validate(program) do
      {error, messages, program} -> add_error(changeset, :script, Enum.join(messages, "\n"))
      {:ok, _}                   -> changeset
    end
  end

  @doc false
  def validate_state(changeset) do
    state = get_field(changeset, :state)
    _validate_state(changeset, state)
  end

  defp _validate_state(changeset, nil), do: changeset
  defp _validate_state(changeset, state) do
    case TileState.Parser.parse(state) do
      {:error, message} -> add_error(changeset, :state, message)
      {:ok, _}          -> changeset
    end
  end
end
