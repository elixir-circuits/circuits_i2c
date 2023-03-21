defmodule CircuitsSim.Device.MCP23008 do
  @moduledoc """
  MCP23008 8-bit I/O Expander

  This is a simple I2C GPIO Expander that's normally found at I2C addresses between 0x20 and 0x27.

  See the [datasheet](https://www.microchip.com/en-us/product/MCP23008) for details.
  Many features aren't implemented.
  """
  alias CircuitsSim.SimpleI2C
  alias CircuitsSim.SimpleI2CServer

  def child_spec(args) do
    device = __MODULE__.new()
    SimpleI2CServer.child_spec_helper(device, args)
  end

  defstruct [
    :iodir,
    :ipol,
    :gpinten,
    :defval,
    :intcon,
    :iocon,
    :gppu,
    :intf,
    :intcap,
    :gpio,
    :olat
  ]

  @type t() :: %__MODULE__{
          iodir: byte(),
          ipol: byte(),
          gpinten: byte(),
          defval: byte(),
          intcon: byte(),
          iocon: byte(),
          gppu: byte(),
          intf: byte(),
          intcap: byte(),
          gpio: byte(),
          olat: byte()
        }

  @spec new() :: %CircuitsSim.Device.MCP23008{
          :defval => 0,
          :gpinten => 0,
          :gpio => 0,
          :gppu => 0,
          :intcap => 0,
          :intcon => 0,
          :intf => 0,
          :iocon => 0,
          :iodir => 255,
          :ipol => 0,
          :olat => 0
        }
  def new() do
    %__MODULE__{
      iodir: 0xFF,
      ipol: 0,
      gpinten: 0,
      defval: 0,
      intcon: 0,
      iocon: 0,
      gppu: 0,
      intf: 0,
      intcap: 0,
      gpio: 0,
      olat: 0
    }
  end

  defimpl SimpleI2C do
    @impl SimpleI2C
    def write_register(state, 0, value), do: %{state | iodir: value}
    def write_register(state, 1, value), do: %{state | ipol: value}
    def write_register(state, 2, value), do: %{state | gpinten: value}
    def write_register(state, 3, value), do: %{state | defval: value}
    def write_register(state, 4, value), do: %{state | intcon: value}
    def write_register(state, 5, value), do: %{state | iocon: Bitwise.band(value, 0x3E)}
    def write_register(state, 6, value), do: %{state | gppu: value}
    def write_register(state, 7, _value), do: state
    def write_register(state, 8, _value), do: state

    def write_register(state, 9, value) do
      result = Bitwise.band(Bitwise.bnot(state.iodir), value)
      %{state | gpio: result, olat: result}
    end

    def write_register(state, 10, value), do: write_register(state, 9, value)
    def write_register(state, _other, _value), do: state

    @impl SimpleI2C
    def read_register(state, 0), do: {state.iodir, state}
    def read_register(state, 1), do: {state.ipol, state}
    def read_register(state, 2), do: {state.gpinten, state}
    def read_register(state, 3), do: {state.defval, state}
    def read_register(state, 4), do: {state.intcon, state}
    def read_register(state, 5), do: {state.iocon, state}
    def read_register(state, 6), do: {state.gppu, state}
    def read_register(state, 7), do: {state.intf, state}
    def read_register(state, 8), do: {state.intcap, state}
    def read_register(state, 9), do: {state.gpio, state}
    def read_register(state, 10), do: {state.olat, state}
    def read_register(state, _other), do: {0, state}

    @impl SimpleI2C
    def render(state) do
      {pin, io, values} =
        for i <- 7..0 do
          mask = Bitwise.bsl(1, i)

          iodir = if Bitwise.band(state.iodir, mask) == 0, do: "O", else: "I"
          gpio = if Bitwise.band(state.gpio, mask) == 0, do: "0", else: "1"
          {to_string(i), iodir, gpio}
        end
        |> unzip3()

      ["     Pin: ", pin, "\n   IODIR: ", io, "\n    GPIO: ", values, "\n"]
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
