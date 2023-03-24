defmodule CircuitsSim.Tools do
  @moduledoc false

  @spec int_to_hex(Integer.t()) :: String.t()
  def int_to_hex(int) do
    Integer.to_string(div(int, 16), 16) <> Integer.to_string(rem(int, 16), 16)
  end
end
