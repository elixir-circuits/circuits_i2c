defmodule CircuitsSim.Device.GPIOExpander do
  @moduledoc """
  Implementation of a simple GPIO expander
  """
  alias CircuitsSim.SimpleI2C

  defstruct [:gpios]
  @type t() :: %__MODULE__{gpios: non_neg_integer()}

  @spec new() :: %__MODULE__{gpios: 0}
  def new() do
    %__MODULE__{gpios: 0}
  end

  defimpl SimpleI2C do
    @impl SimpleI2C
    def write_register(state, 1, value), do: %{state | gpios: value}
    def write_register(state, _other, _value), do: state

    @impl SimpleI2C
    def read_register(state, 1), do: {state.gpios, state}
    def read_register(state, _other), do: {0, state}

    @impl SimpleI2C
    def render(state) do
      {pin, io, values} =
        for i <- 0..7 do
          mask = Bitwise.bsl(1, i)

          v = if Bitwise.band(state.gpios, mask) == 0, do: "0", else: "1"
          {to_string(i), "O", v}
        end
        |> unzip3()

      ["     Pin: ", pin, "\n     I/O: ", io, "\n   Value: ", values, "\n"]
    end

    @impl SimpleI2C
    def handle_message(state, _message) do
      state
    end

    defp unzip3(list, acc \\ {[], [], []})

    defp unzip3([], {a, b, c}) do
      {Enum.reverse(a), Enum.reverse(b), Enum.reverse(c)}
    end

    defp unzip3([{x, y, z} | rest], {a, b, c}) do
      unzip3(rest, {[x | a], [y | b], [z | c]})
    end
  end
end
