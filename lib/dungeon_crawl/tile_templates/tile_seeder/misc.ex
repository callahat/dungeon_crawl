defmodule DungeonCrawl.TileTemplates.TileSeeder.Misc do
  alias DungeonCrawl.TileTemplates

  def pushers do
    [ {"▲", "North"}, {"▶", "East"}, {"▼", "South"}, {"◀", "West"} ]
    |> Enum.each(fn({char, dir}) ->
         TileTemplates.update_or_create_tile_template!(
           "pusher_#{ String.downcase(dir) }",
           %{character: char,
             name: "Pusher #{ dir }",
             description: "Pushes to the #{ dir }",
             state: "blocking: true, wait_cycles: 10",
             color: "black",
             public: true,
             active: true,
             script: """
                     :thud
                     /i
                     #walk #{ String.downcase(dir) }
                     """
         })
      end)
  end

  def spinning_gun do
    TileTemplates.update_or_create_tile_template!(
      "spinning_gun",
      %{character: "↑",
        name: "Spinning Gun",
        description: "Spins and shoots bullets",
        state: "blocking: true, facing: north",
        color: "black",
        public: true,
        active: true,
        script: """
                :main
                /i
                #facing clockwise
                #sequence char, →, ↓, ←, ↑
                #become character: @char
                #if ?random@2 == 1, main
                #shoot @facing
                #send main
                """
    })
  end


  defmacro __using__(_params) do
    quote do
      def pushers(), do: unquote(__MODULE__).pushers()
      def spinning_gun(), do: unquote(__MODULE__).spinning_gun()
    end
  end
end
