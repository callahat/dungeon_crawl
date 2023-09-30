defmodule DungeonCrawl.TileTemplates.TileSeeder.Npcs do
  alias DungeonCrawl.TileTemplates

  def glad_trader() do
    TileTemplates.update_or_create_tile_template!(
      "glad_trader",
      %{character: "☺",
        name: "Glad Trader",
        description: "Happy to sell you ammo and gems",
        state: %{"blocking" => true, "pullable" => true, "light_source" => true, "light_range" => 3},
        public: true,
        active: true,
        group_name: "misc",
        script: """
                #end
                :touch
                Greetings, care to buy anything?

                     What    Qty  Cost
                !10_ammo;Ammo     10    $5
                !100ammo;Ammo    100   $45
                !1_gem;Gem       1  6 hp
                !done;Nothing      free
                #end
                :10_ammo
                #take cash, 5, ?sender, toopoor
                #give ammo, 10, ?sender
                Careful with this
                #end
                :100ammo
                #take cash, 45, ?sender, toopoor
                #give ammo, 100, ?sender
                Always good to buy in bulk
                #end
                :1_gem
                #if ?sender@health < 6, lowhealth
                #take health, 6, ?sender
                #give gems, 1, ?sender
                You know I'm doing you a favor at this rate.
                #end
                :lowhealth
                You're a bit short, but you can still have the gem.
                #give gems, 1, ?sender
                #take health, 6, ?sender
                #end
                :toopoor
                I'm not running a charity!
                Come back when you've got the cash!
                :done
                """
      })
  end

  def sad_trader() do
    TileTemplates.update_or_create_tile_template!(
     "sad_trader",
      %{character: "☹",
        name: "Sad Trader",
        description: "Will sell things *sigh*",
        state: %{"blocking" => true, "pullable" => true, "light_source" => true, "light_range" => 1},
        public: true,
        active: true,
        group_name: "misc",
        script: """
                #end
                :touch
                I have some things you can buy, if you really want
                to i guess *sigh*

                     What    Qty     Cost
                !10_health;Health   10       $5
                !25_health;Health   25      $10
                !1_life;Life      1   5 gems
                !done;Leave           free
                #end
                :10_health
                #take cash, 5, ?sender, toopoor
                #give health, 10, ?sender, 100
                Heal
                #end
                :25_health
                #take cash, 10, ?sender, toopoor
                #give health, 25, ?sender, 100
                Heal some more
                #end
                :1_life
                #take gems, 5, ?sender, toopoor
                #give lives, 1, ?sender
                Try not to waste it
                #end
                :toopoor
                You don't have enough to buy that,
                how sad.
                :done
                """
      })
  end

  defmacro __using__(_params) do
    quote do
      def glad_trader(), do: unquote(__MODULE__).glad_trader()
      def sad_trader(), do: unquote(__MODULE__).sad_trader()
    end
  end
end

