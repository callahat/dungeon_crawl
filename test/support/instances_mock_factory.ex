defmodule DungeonCrawl.InstancesMockFactory do
  alias DungeonCrawl.DungeonProcesses.Instances

  def generate(test_pid, module_name \\ DungeonCrawl.InstancesMock) do
    ast = quote do
            def gameover(%Instances{} = state, victory, result) do
              send(unquote(test_pid), {:gameover_test, state.instance_id, victory, result})

              state
            end
            def gameover(%Instances{} = state, player_tile_id, victory, result) do
              send(unquote(test_pid), {:gameover_test, state.instance_id, player_tile_id, victory, result})

              state
            end
          end
    Module.create(module_name, ast, Macro.Env.location(__ENV__))
  end
end
