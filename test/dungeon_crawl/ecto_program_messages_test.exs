defmodule DungeonCrawl.EctoProgramMessagesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.EctoProgramMessages

  describe "cast/1" do
    test "returns error when its invalid" do
      assert EctoProgramMessages.cast("junk") == :error
      assert EctoProgramMessages.cast([{"123", "junk"}]) == :error
      assert EctoProgramMessages.cast([123, "junk"]) == :error
      assert EctoProgramMessages.cast(%{123 => "key"}) == :error
      assert EctoProgramMessages.cast([{:notbinary, %{}}]) == :error
      assert EctoProgramMessages.cast([{"Second isn't map", []}]) == :error
    end

    test "returns ok and a list when valid" do
      assert EctoProgramMessages.cast(nil) == {:ok, []}
      assert EctoProgramMessages.cast([]) == {:ok, []}
      assert EctoProgramMessages.cast([{"TOUCH", %{id: 123}}]) == {:ok, [["TOUCH", %{id: 123}]]}
      assert EctoProgramMessages.cast([["TOUCH", %{id: 123}]]) == {:ok, [["TOUCH", %{id: 123}]]}
    end
  end

  describe "load/1" do
    test "loads data that should be valid" do
      assert EctoProgramMessages.load([["TOUCH", %{id: 123}]]) == {:ok, [{"TOUCH", %{id: 123}}]}
      assert EctoProgramMessages.load([["thing", %{}]]) == {:ok, [{"thing", %{}}]}
    end

    test "doesnt load corrupt data" do
      assert EctoProgramMessages.load("someone edited this...") == :error
    end
  end

  describe "dump/1" do
    test "doesn't dump bad data to the database" do
      assert EctoProgramMessages.dump("someone edited this...") == :error
      assert EctoProgramMessages.dump([{"TOUCH", %{id: 123}}])

    end

    test "lets the good data in" do
      assert EctoProgramMessages.dump([["TOUCH", %{id: 123}]]) == {:ok, [["TOUCH", %{id: 123}]]}
      assert EctoProgramMessages.dump([["thing", %{}]]) == {:ok, [["thing", %{}]]}
    end
  end
end
