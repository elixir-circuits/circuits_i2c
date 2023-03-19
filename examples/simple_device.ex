defprotocol SimpleDevice do
  @moduledoc """
  A SimpleDevice is a common style of register-based I2C devices
  """

  @doc """
  Write a value to a register
  """
  @spec write_register(t(), non_neg_integer(), non_neg_integer()) :: t()
  def write_register(dev, reg, value)

  @doc """
  Read a register
  """
  @spec read_register(t(), non_neg_integer()) :: {non_neg_integer, t()}
  def read_register(dev, reg)

  @doc """
  Return a pretty printable view the the state
  """
  @spec render(t()) :: IO.ANSI.ansidata()
  def render(dev)
end
