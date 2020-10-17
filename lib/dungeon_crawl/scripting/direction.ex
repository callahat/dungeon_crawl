defmodule DungeonCrawl.Scripting.Direction do
  @moduledoc """
  The various functions relating to direction regarding tiles.
  """

  @orthogonal ["north", "up", "south", "down", "east", "right", "west", "left"]

  @normalized_orthogonal %{
    "left"  => "west",
    "west"  => "west",
    "up"    => "north",
    "north" => "north",
    "right" => "east",
    "east"  => "east",
    "down"  => "south",
    "south" => "south"
  }

  @clockwise "clockwise"
  @counterclockwise "counterclockwise"
  @reverse "reverse"

  @orthogonal_change %{
    @clockwise => %{ "west"  => "north",
                      "north" => "east",
                      "east"  => "south",
                      "south" => "west" },
    @counterclockwise => %{ "west"  => "south",
                             "north" => "west",
                             "east"  => "north",
                             "south" => "east" },
    @reverse => %{ "west"  => "east",
                    "north" => "south",
                    "east"  => "west",
                    "south" => "north" }
  }

  @directions %{
    "north" => {-1,  0},
    "south" => { 1,  0},
    "west"  => { 0, -1},
    "east"  => { 0,  1}
  }

  @no_direction { 0,  0}

  @doc """
  Returns true if the given direction is valid and adjacent (but not diagonal)

  ## Examples

    iex> Direction.valid_orthogonal?("up")
    true
    iex> Direction.valid_orthogonal?("south")
    true
    iex> Direction.valid_orthogonal?("baddir")
    false
  """
  def valid_orthogonal?(direction) do
    direction in @orthogonal
  end

  defmacro is_valid_orthogonal(direction) do
    quote do
      unquote(direction) in unquote(@orthogonal)
    end
  end

  @doc """
  Normalizes the given direction to cardinal orthogonal direction. If its not a valid direction,
  `idle` is returned.

  ## Examples

    iex> Direction.normalize_orthogonal("up")
    "north"
    iex> Direction.normalize_orthogonal("south")
    "south"
    iex> Direction.normalize_orthogonal("baddir")
    "idle"
  """
  def normalize_orthogonal(direction) do
    @normalized_orthogonal[direction] || "idle"
  end

  @doc """
  Returns true if the given orthogonal change is valid.

  ## Examples

    iex> Direction.valid_orthogonal_change?("up")
    false
    iex> Direction.valid_orthogonal_change?("clockwise")
    true
  """
  def valid_orthogonal_change?(change) do
    Map.has_key? @orthogonal_change, change
  end

  defmacro is_valid_orthogonal_change(change) do
    quote do
      unquote(change) in unquote([@clockwise, @counterclockwise, @reverse])
    end
  end

  @doc """
  Returns a direction based on the current direction and provided change.
  If the rotation is not valid (either the given direction is not orthogonal, or the change by
  not valid), the given direction is returned instead.

  Valid directional changes:
  reverse - reverses the current facing direction (ie, north becomes south)
  clockwise - turns the current facing clockwise (ie, north becomes west)
  counterclockwise - turns the current facing counter clockwise (ie, north becomes east)

  ## Examples

    iex> Direction.change_direction("north", "clockwise")
    "east"
    iex> Direction.change_direction("down", "reverse")
    "north"
    iex> Direction.change_direction("idle", "counterclockwise")
    "idle"
    iex> Direction.change_direction("north", "notavalidrotation")
    "north"
  """
  def change_direction(direction, change_by) do
    @orthogonal_change[change_by][normalize_orthogonal(direction)] || direction || "idle"
  end

  @doc """
  Returns a tuple represeting the unit vector for a given direction.

  ## Examples

    iex> Direction.delta("down")
    { 1,  0}
    iex> Direction.delta("west")
    { 0, -1}
    iex> Direction.delta("gibberish")
    { 0,  0}
  """
  def delta(direction) do
    @directions[normalize_orthogonal(direction)] || @no_direction
  end

  @doc """
  Returns the orthogonal direction that the target is in from the origin. The coordinate map
  can be a map tile struct, but can also be a simple map containing just `row` and `col` keys.
  If the coordinates are entirely orthogonal (that is, on the same row or same column) to each other,
  a list containing a single binary is returned. Otherwise, the list is returned with the row direction
  and the column direction. If the coordinates are the same, `idle` is the direction.

  ## Examples

    iex> Direction.orthogonal_direction(%{row: 0, col: 0}, %{row: 1, col: 0})
    ["south"]
    iex> Direction.orthogonal_direction(%{row: 1, col: 4}, %{row: 1, col: 7})
    ["east"]
    iex> Direction.orthogonal_direction(%{row: 5, col: 5}, %{row: 1, col: 0})
    ["north", "west"]

  """
  def orthogonal_direction(%{row: origin_row, col: origin_col}, %{row: target_row, col: target_col}) do
    {delta_row, delta_col} = {target_row - origin_row, target_col - origin_col}

    cond do
      delta_row == 0 && delta_col == 0 ->
        ["idle"]

      delta_col == 0 ->
        [if(delta_row > 0, do: "south", else: "north")]

      delta_row == 0 ->
        [if(delta_col > 0, do: "east", else: "west")]

      true ->
        [if(delta_row > 0, do: "south", else: "north"),
         if(delta_col > 0, do: "east", else: "west")]
    end
  end

  @doc """
  Returns the distance between two map tiles, in terms of map tiles.

  ## Examples

    iex> Direction.distance(%{row: 0, col: 0}, %{row: 1, col: 0})
    1.0
    iex> Direction.distance(%{row: 2, col: 4}, %{row: 2, col: 7})
    3.0
    iex> Direction.distance(%{row: 5, col: 5}, %{row: 1, col: 0})
    6.4031242374328485
  """
  def distance(%{row: origin_row, col: origin_col}, %{row: target_row, col: target_col}) do
    :math.sqrt( :math.pow( target_row - origin_row, 2) + :math.pow( target_col - origin_col, 2) )
  end
end
