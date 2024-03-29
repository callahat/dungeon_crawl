defmodule DungeonCrawl.Shipping.SlugMatching do
  defmacro __using__(_params) do
    quote do
      @script_tt_slug ~r/slug: [\w\d_]+/i
      @script_item_slug ~r/#(?:un)?equip [\w\d_]+/i
      @script_sound_slug ~r/#sound [\w\d_]+/i
    end
  end
end
