defmodule CircuitsSim.Device.PI4IOE5V6416LEX do
  @moduledoc """
  Low-Voltage Translating 16-bit I2C-bus I/O Expander

  Typically found at 0x20

    See the datasheet for more information:
  https://www.mouser.com/datasheet/2/115/DIOD_S_A0006645136_1-2542969.pdf
  """
  alias CircuitsSim.SimpleI2C
  alias CircuitsSim.SimpleI2CServer
  alias CircuitsSim.Tools

  def child_spec(args) do
    device = __MODULE__.new()
    SimpleI2CServer.child_spec_helper(device, args)
  end

  defstruct registers: %{}

  @type t() :: %__MODULE__{}

  @spec new() :: t()
  def new() do
    %__MODULE__{registers: %{}}
  end

  defimpl SimpleI2C do
    @impl SimpleI2C
    def write_register(state, reg, value), do: put_in(state.registers[reg], <<value>>)

    @impl SimpleI2C
    def read_register(state, reg), do: {state.registers[reg], state}

    @impl SimpleI2C
    def render(state) do
      for {reg, data} <- state.registers do
        [
          "  ",
          Tools.int_to_hex(reg),
          ": ",
          for(<<b::1 <- data>>, do: to_string(b)),
          " (",
          reg_name(reg),
          ")\n"
        ]
      end
    end

    @impl SimpleI2C
    def handle_message(state, _message) do
      state
    end

    defp reg_name(0x00), do: "Input port 0"
    defp reg_name(0x01), do: "Input port 1"
    defp reg_name(0x02), do: "Output port 0"
    defp reg_name(0x03), do: "Output port 1"
    defp reg_name(0x04), do: "Polarity Inversion port 0"
    defp reg_name(0x05), do: "Polarity Inversion port 1"
    defp reg_name(0x06), do: "Configuration port 0 "
    defp reg_name(0x07), do: "Configuration port 1"
    defp reg_name(0x40), do: "Output drive strength register 0"
    defp reg_name(0x41), do: "Output drive strength register 0"
    defp reg_name(0x42), do: "Output drive strength register 1"
    defp reg_name(0x43), do: "Output drive strength register 1"
    defp reg_name(0x44), do: "Input latch register 0"
    defp reg_name(0x45), do: "Input latch register 1"
    defp reg_name(0x46), do: "Pull-up/pull-down enable register 0"
    defp reg_name(0x47), do: "Pull-up/pull-down enable register 1"
    defp reg_name(0x48), do: "Pull-up/pull-down selection register 0"
    defp reg_name(0x49), do: "Pull-up/pull-down selection register 1"
    defp reg_name(0x4A), do: "Interrupt mask register 0"
    defp reg_name(0x4B), do: "Interrupt mask register 1"
    defp reg_name(0x4C), do: "Interrupt status register 0"
    defp reg_name(0x4D), do: "Interrupt status register 1"
    defp reg_name(0x4F), do: "Output port configuration register"
  end
end
