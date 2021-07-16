defmodule DungeonCrawl.Scripting.Maths do

  @doc """
  Returns various math operations on two operands given an operator.
  The second operand is a placeholder for some operators (such as ++ or --)

  When there is a binary operation and one of the operands is not an integer or float,
  then that operand will be assumed as zero.

  When dividing by zero, the first operand is returned instead.

  ## Examples

    iex> Maths.calc(1, "++", 9)
    2
    iex> Maths.calc(4, "--", 9)
    3
    iex> Maths.calc(4, "=", 9)
    9
    iex> Maths.calc(4, "+=", 9)
    13
    iex> Maths.calc(4, "-=", 9)
    -5
    iex> Maths.calc(15, "/=", 3)
    5.0
    iex> Maths.calc(4, "*=", 4)
    16
  """
  def calc(_a, "=", b),    do: b
  def calc(a, op, b) when not is_integer(a) and not is_float(a), do: calc(0, op, b)
  def calc(a, "++", _),    do: a + 1
  def calc(a, "--", _),    do: a - 1
  def calc(a, op, b) when not is_integer(b) and not is_float(b), do: calc(a, op, 0)
  def calc(a, "+=", b),    do: a + b
  def calc(a, "-=", b),    do: a - b
  def calc(a, "/=", 0),    do: a # no dividing by zero
  def calc(a, "/=", b),    do: a / b
  def calc(a, "*=", b),    do: a * b

  @doc """
  Returns true or false for the equality check given by the second parameter (operator).
  For an unknown operator, the truthiness of the first operand will be returned.
  When four parameters are used, if the first parameter is a "!" then the negation of
  the check is returned.

  ## Examples

    iex> Maths.check("!", false, "==", :truthy)
    true
    iex> Maths.check("", false, "==", :truthy)
    false
    iex> Maths.check("", nil, "!=", :truthy)
    true
    iex> Maths.check("", "something", "!=", :truthy)
    false
    iex> Maths.check("!", 1, "==", 9)
    true
    iex> Maths.check("", 1, "==", 9)
    false
    iex> Maths.check(4, "!=", 9)
    true
    iex> Maths.check("4", "==", 4)
    false
    iex> Maths.check(4, "<=", 9)
    true
    iex> Maths.check(4, ">=", 9)
    false
    iex> Maths.check(4, "<", 9)
    true
    iex> Maths.check(4, ">", 9)
    false
    iex> Maths.check(4, "", 9)
    true
    iex> Maths.check(4, "quijibo", 9)
    true
  """
  def check("!", a, op, :truthy), do: !check(a, op, :truthy)
  def check(_, a, op, :truthy), do: check(a, op, :truthy)
  def check("!", a, op, b), do: !check(a, op, b)
  def check(_, a, op, b),   do: check(a, op, b)
  def check(a, "==", :truthy), do: !!a
  def check(a, "!=", :truthy), do: !check(a, "==", :truthy)
  def check(a, "!=", b),    do: a != b
  def check(a, "==", b),    do: a == b
  def check(a, "<=", b) when is_number(a) and is_number(b), do: a <= b
  def check(a, ">=", b) when is_number(a) and is_number(b), do: a >= b
  def check(a, "<",  b) when is_number(a) and is_number(b), do: a <  b
  def check(a, ">",  b) when is_number(a) and is_number(b), do: a > b
  def check(a, _,    _),    do: !!a

end
