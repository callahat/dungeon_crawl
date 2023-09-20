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

      # returns nil for a non binary "label" or parsed value
      refute Program.line_for(program, 4)
  end

  test "send_message/4 no delay" do
    program = Program.send_message(%Program{}, "touch", 1234, 0)
    assert [{"touch", 1234}] == program.messages

    # adds messages to the end of the list, FIFO
    program = Program.send_message(program, "panic", nil, 0)
    assert [{"touch", 1234}, {"panic", nil}] == program.messages
  end

  test "send_message/4 with delay" do
    program = Program.send_message(%Program{}, "touch", 1234, 120)
    assert [{trigger_time, "touch", 1234}] = program.timed_messages
    assert_in_delta DateTime.diff(trigger_time, DateTime.utc_now), 120, 1

    program = Program.send_message(program, "panic", nil, 15)
    assert [{t2, "panic", nil}, {t1, "touch", 1234}] = program.timed_messages
    assert_in_delta DateTime.diff(t1, DateTime.utc_now), 120, 1
    assert_in_delta DateTime.diff(t2, DateTime.utc_now), 15, 1
  end
end
