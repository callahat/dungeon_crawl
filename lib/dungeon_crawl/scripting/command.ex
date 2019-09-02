defmodule DungeonCrawl.Scripting.Command do
# TODO: implement more of this when actually using it
  @doc """
  Replace a tiles information.
  """
  def become(%{tile: tile, new_attrs: new_attrs}) do
    {
      :tile_update,
      Dungeon.update_map_tile!(tile, Map.take(new_attrs, [:character, :color, :background_color, :state, :script]))
    }
  end

  @doc """
  Evaluates a conditional against the state element.
  """
  def jump_if(%{state_element: state_element, neg: neg, operator: operator, check_value: check_value, label: label} = params) do
    if if(neg, do: ! _jump_if(params), else: _jump_if(params)) do
      {
        :jump_to_label,
        label
      }
    else
      { :noop }
    end
  end

  def _jump_if(%{state_element: state_element, operator: operator, value: value}) do
    case operator do
      "!=" -> state_element != value
      "==" -> state_element == value
      "<=" -> state_element <= value
      ">=" -> state_element >= value
      "<"  -> state_element <  value
      ">"  -> state_element >  value
    end
  end

  # TODO: might not need to actually call this here
#  def end_script do
#
#  end
end
