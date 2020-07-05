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

  @orthogonal_change %{
    "clockwise" => %{ "west"  => "north",
                      "north" => "east",
                      "east"  => "south",
                      "south" => "west" },
    "counterclockwise" => %{ "west"  => "south",
                             "north" => "west",
                             "east"  => "north",
                             "south" => "east" },
    "reverse" => %{ "west"  => "east",
                    "north" => "south",
                    "east"  => "west",
                    "south" => "north" }
  }

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
  """
  def change_direction(direction, change_by) do
    @orthogonal_change[change_by][normalize_orthogonal(direction)] || direction
  end
end
