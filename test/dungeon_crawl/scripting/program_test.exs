defmodule DungeonCrawl.Scripting.ProgramTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Program

  test "line_for/2" do
    script = """
             #END
             :TOUCH
             You touched it
             """

      {:ok, program} = Parser.parse(script)
      assert 2 == Program.line_for(program, "touch")
      assert 2 == Program.line_for(program, "TOUCH")
      assert 2 == Program.line_for(program, "Touch")
      refute Program.line_for(program, "test")

      {:ok, program} = Parser.parse("")
      refute Program.line_for(program, "touch")
  end
end
