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
  @spec read_register(t(), non_neg_integer()) :: {non_neg_integer(), t()}
  def read_register(dev, reg)

  @doc """
  Return a pretty printable view the the state
  """
  @spec render(t()) :: IO.ANSI.ansidata()
  def render(dev)

  @doc """
  Handle an user message

  User messages are used to modify the state of the simulated device outside of
  I2C. This can be used to simulate real world changes like temperature changes
  affecting a simulated temperature sensor. Another use is as a hook for getting
  internal state.
  """
  @spec handle_message(t(), any()) :: {any(), t()}
  def handle_message(dev, message)
end
