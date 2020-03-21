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

  test "send_message/2" do
    program = Program.send_message(%Program{}, "touch", 1234)
    assert {"touch", 1234} == program.message

    program = Program.send_message(program, "panic")
    assert {"touch", 1234} == program.message
  end
end
