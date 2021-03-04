defmodule DungeonCrawl.TileTemplates.TileTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @color_match ~r/\A(?:[a-z]+|#(?:[\da-f]{3}){1,2})\z/i

  @groups ["terrain","doors", "monsters", "items", "misc", "custom"]

  alias DungeonCrawl.Scripting
  alias DungeonCrawl.StateValue

  schema "tile_templates" do
    field :active, :boolean, default: false
    field :background_color, :string
    field :character, :string
    field :color, :string
    field :description, :string
    field :deleted_at, :naive_datetime
    field :name, :string
    field :slug, :string
    field :public, :boolean, default: false
    field :script, :string, default: ""
    field :state, :string
    field :version, :integer, default: 1
    field :animate_random, :boolean
    field :animate_colors, :string
    field :animate_background_colors, :string
    field :animate_characters, :string
    field :animate_period, :integer
    field :group_name, :string
    has_one :next_version, DungeonCrawl.TileTemplates.TileTemplate, foreign_key: :previous_version_id, on_delete: :nilify_all
    has_many :map_tiles, DungeonCrawl.Dungeon.MapTile, on_delete: :nilify_all
    belongs_to :previous_version, DungeonCrawl.TileTemplates.TileTemplate, foreign_key: :previous_version_id
    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc """
  Returns the available groups
  """
  def groups() do
    @groups
  end

  @doc false
  def changeset(tile_template, attrs) do
    tile_template
    |> cast(attrs, [:name,
                    :character,
                    :description,
                    :color,
                    :background_color,
                    :script,
                    :version,
                    :active,
                    :public,
                    :previous_version_id,
                    :deleted_at,
                    :user_id,
                    :state,
                    :animate_random,
                    :animate_colors,
                    :animate_background_colors,
                    :animate_characters,
                    :animate_period,
                    :group_name])
    |> validate_required([:name, :description])
    |> validate_inclusion(:group_name, @groups)
    |> validate_animation_fields
    |> validate_renderables
    |> validate_script(tile_template.user_id) # seems like an clumsy way to get a user just to validate a TTID in a script
    |> validate_state_values
  end

  @doc false
  def validate_colors(changeset) do
    changeset
    |> validate_format(:color, @color_match)
    |> validate_format(:background_color, @color_match)
  end

  @doc false
  def validate_renderables(changeset) do
    changeset
    |> validate_colors()
    |> validate_length(:character, min: 1, max: 1)
  end

  @doc false
  def validate_script(changeset, user_id) do
    script = get_field(changeset, :script)
    _validate_script(changeset, script, user_id)
  end

  @doc false
  def validate_animation_fields(changeset) do
    changeset
    |> validate_length(:animate_colors, max: 255)
    |> validate_length(:animate_background_colors, max: 255)
    |> validate_length(:animate_characters, max: 255)
    |> validate_number(:animate_period, greater_than: 0)
  end

  defp _validate_script(changeset, nil, _), do: changeset
  defp _validate_script(changeset, script, user_id) do
    case Scripting.Parser.parse(script) do
      {:error, message, program} -> add_error(changeset, :script, "#{message} - near line #{Enum.count(program.instructions) + 1}")
      {:ok, program}             -> _validate_program(changeset, changeset.changes[:user_id] || user_id, program)
    end
  end
  defp _validate_program(changeset, user_id, program) do
    case Scripting.ProgramValidator.validate(program, user_id && DungeonCrawl.Account.get_user(user_id)) do
      {:error, messages, _program} -> add_error(changeset, :script, Enum.join(messages, "\n"))
      {:ok, _}                     -> changeset
    end
  end

  @doc false
  def validate_state_values(changeset) do
    state = get_field(changeset, :state)
    _validate_state_values(changeset, state)
  end

  defp _validate_state_values(changeset, nil), do: changeset
  defp _validate_state_values(changeset, state) do
    case StateValue.Parser.parse(state) do
      {:error, message} -> add_error(changeset, :state, message)
      {:ok, _}          -> changeset
    end
  end
end
