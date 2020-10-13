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
                     #walk  #{ String.downcase(dir) }
                     """
         })
      end)
  end


  defmacro __using__(_params) do
    quote do
      def pushers(), do: unquote(__MODULE__).pushers()
    end
  end
end
