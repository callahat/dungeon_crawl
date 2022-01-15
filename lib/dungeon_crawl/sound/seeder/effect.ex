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

  def door do
    Sound.update_or_create_effect!(
      "door",
      %{name: "Door",
        public: true,
        zzfx_params: "[2.13,0,423,.01,.01,.05,4,2.51,,,,,,1.5,,.3,.12,.71,.01]"
      })
  end

  def fuzz_pop do
    Sound.update_or_create_effect!(
      "fuzz_pop",
      %{name: "Fuzz Pop",
        public: true,
        zzfx_params: "[1.05,,61,.03,.01,.09,,.21,,,646,.04,,.5,,,,.14,.07]"
      })
  end

  def harp_down do
    Sound.update_or_create_effect!(
      "harp_down",
      %{name: "Harp Down",
        public: true,
        zzfx_params: "[1.18,,305,.08,.2,.43,1,1.7,.5,-5,-17,.03,.04,,,,,.51,.03,.44]"
      })
  end

  def harp_up do
    Sound.update_or_create_effect!(
      "harp_up",
      %{name: "Harp Up",
        public: true,
        zzfx_params: "[1.18,,305,.08,.2,.43,1,1.7,.5,-5,17,.03,.04,,,,,.51,.03,.44]"
      })
  end

  def heal do
    Sound.update_or_create_effect!(
      "heal",
      %{name: "Heal",
      public: true,
      zzfx_params: "[1.18,,143,.05,.08,.06,,.09,25,4.1,,,,,,,.01,.52,.09]"
    })
  end

  def ouch do
    Sound.update_or_create_effect!(
      "ouch",
      %{name: "Ouch",
        public: true,
        zzfx_params: "[,,239,,.04,.19,2,.62,-3.7,2.7,100,,1.99,.1,,,,.75,.05]"
      })
  end

  def open_locked_door do
    Sound.update_or_create_effect!(
      "open_locked_door",
      %{name: "Open Locked Door",
        public: true,
        zzfx_params: "[1.13,,463,.01,.16,.24,1,1.82,,,40,.18,.17,,,.2,,.63,.03]"
      })
  end

  def pickup_blip do
    Sound.update_or_create_effect!(
      "pickup_blip",
      %{name: "Pickup Blip",
        public: true,
        zzfx_params: "[3.9,,83,,.01,.02,2,.46,-1.5,34.8,5,.18,,-0.1,-364,-0.1,.09,1.1,.01,.03]"
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

  def slide_down do
    Sound.update_or_create_effect!(
      "slide_down",
      %{name: "Slide Down",
        public: true,
        zzfx_params: "[,,108,,.16,.04,1,.06,-0.1,,,,,.2,,,,.43,.18,.04]"
      })
  end

  def slide_up do
    Sound.update_or_create_effect!(
      "slide_up",
      %{name: "Slide Up",
        public: true,
        zzfx_params: "[,,108,,.16,.04,1,.06,.1,,,,,.2,,,,.43,.18,.04]"
      })
  end

  def star_fire do
    Sound.update_or_create_effect!(
      "star_fire",
      %{name: "Star Fire",
        public: true,
        zzfx_params: "[1.16,,878,.17,,.19,4,.01,,,,,,,-24,,.07,,.09]"
      })
  end

  def trudge do
    Sound.update_or_create_effect!(
      "trudge",
      %{name: "Trudge",
        public: true,
        zzfx_params: "[,,1200,.01,.07,.01,4,.95,-78,,429,,,,,.1,,1.1]"
    })
  end

  defmacro __using__(_params) do
    quote do

      def alarm(), do: unquote(__MODULE__).alarm()
      def bomb(), do: unquote(__MODULE__).bomb()
      def click(), do: unquote(__MODULE__).click()
      def computing(), do: unquote(__MODULE__).computing()
      def door(), do: unquote(__MODULE__).door()
      def fuzz_pop(), do: unquote(__MODULE__).fuzz_pop()
      def harp_down(), do: unquote(__MODULE__).harp_down()
      def harp_up(), do: unquote(__MODULE__).harp_up()
      def heal(), do: unquote(__MODULE__).heal()
      def ouch(), do: unquote(__MODULE__).ouch()
      def open_locked_door(), do: unquote(__MODULE__).open_locked_door()
      def pickup_blip(), do: unquote(__MODULE__).pickup_blip()
      def rumble(), do: unquote(__MODULE__).rumble()
      def shoot(), do: unquote(__MODULE__).shoot()
      def slide_down(), do: unquote(__MODULE__).slide_down()
      def slide_up(), do: unquote(__MODULE__).slide_up()
      def star_fire(), do: unquote(__MODULE__).star_fire()
      def trudge(), do: unquote(__MODULE__).trudge()
    end
  end
end
