defmodule DungeonCrawl.Sound.Seeder.Effect do
  alias DungeonCrawl.Sound

  def alarm do
    Sound.update_or_create_effect!(
      "alarm",
      %{name: "Alarm",
        public: true,
        zzfx_params: "[,0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04]"
      })
  end

  def bomb do
    Sound.update_or_create_effect!(
      "bomb",
      %{name: "Bomb",
        public: true,
        zzfx_params: "[3,,485,.02,.2,.2,4,.11,-3,.1,,,.05,1.1,,.4,,.57,.5]"
      })
  end

  def click do
    Sound.update_or_create_effect!(
      "click",
      %{name: "Click",
        public: true,
        zzfx_params: "[,0,521.25,,.02,.03,2,0,,.1,700,.01,,,1,.1]"
      })
  end

  def computing do
    Sound.update_or_create_effect!(
      "computing",
      %{name: "Computing",
        public: true,
        zzfx_params: "[1.94,-0.4,257,.01,,.13,,.42,,,,.07,,,,,.05,.96,.02,.05]"
      })
  end

  def rumble do
    Sound.update_or_create_effect!(
      "rumble",
      %{name: "Rumble",
        public: true,
        zzfx_params: "[5,,591,.03,.13,.51,4,3.02,.6,.1,,,.04,1.6,,1,,.46,.13]"
      })
  end

  def shoot do
    Sound.update_or_create_effect!(
      "shoot",
      %{name: "Shoot",
        public: true,
        zzfx_params: "[1.5,,100,,.05,.04,4,1.44,3,,,,,,,.1,,.3,.05]"
      })
  end


  defmacro __using__(_params) do
    quote do
      def alarm(), do: unquote(__MODULE__).alarm()
      def bomb(), do: unquote(__MODULE__).bomb()
      def click(), do: unquote(__MODULE__).click()
      def computing(), do: unquote(__MODULE__).computing()
      def rumble(), do: unquote(__MODULE__).rumble()
      def shoot(), do: unquote(__MODULE__).shoot()
    end
  end
end
