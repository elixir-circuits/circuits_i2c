defmodule CircuitsSim.Device.ADS7138 do
  @moduledoc """
  MCP23008 8-bit I/O Expander

  Small, 8-Channel, 12-Bit ADC with I2C interface, GPIOs, and CRC. Supports
  addresses 0x10 to 0x17

  See the [datasheet](https://www.ti.com/lit/ds/symlink/ads7138.pdf) for details.
  Many features aren't implemented.
  """
  use GenServer

  alias CircuitsSim.DeviceRegistry

  defstruct name: nil, address: nil, registers: %{}, current: 0

  def start_link(args) do
    bus_name = Keyword.fetch!(args, :bus_name)
    address = Keyword.fetch!(args, :address)
    GenServer.start_link(__MODULE__, args, name: DeviceRegistry.via_name(bus_name, address))
  end

  @impl GenServer
  def init(args) do
    {:ok, %__MODULE__{name: args[:bus_name], address: args[:address]}}
  end

  @single_register_read 0b00010000
  @single_register_write 0b00001000
  @continuous_register_read 0b00110000
  @continuous_register_write 0b00101000

  ##
  # All of these are piggy-backing off the fact that SimpleI2CServer is just
  # using GenServer.call/2 under the hood. So we just start our own I2C server,
  # use the same CircuitsSim.Bus, and then get the messages here so we can handle
  # the special ADS7138 commmand+register way.
  #
  # This is a bit hacky so maybe need to consider changing?
  @impl GenServer
  def handle_call({:read, count}, _from, state) do
    # This isn't really supported since ADS7138 always requires a command to set a register
    # for reading, but we'll include it here just in case.
    last = state.current + count
    result = for reg <- state.current..last, into: <<>>, do: read_register(state, reg)
    {:reply, {:ok, result}, %{state | current: last}}
  end

  def handle_call({:write, <<@single_register_write, register, value::binary>>}, _from, state) do
    {:reply, :ok, put_in(state.registers[register], value)}
  end

  def handle_call(
        {:write, <<@continuous_register_write, register, values::binary>>},
        _from,
        state
      ) do
    current =
      for <<val <- values>>, reduce: register do
        reg ->
          write_register(state, reg, val)
          reg + 1
      end

    {:reply, :ok, %{state | current: current - 1}}
  end

  def handle_call({:write_read, <<@single_register_read, register>>, 1}, _from, state) do
    {:reply, {:ok, read_register(state, register)}, %{state | current: register}}
  end

  def handle_call({:write_read, <<@continuous_register_read, register>>, count}, _from, state) do
    last = state.current + count
    result = for reg <- state.current..last, into: <<>>, do: read_register(state, reg)
    {:reply, {:ok, result}, %{state | current: register}}
  end

  def handle_call(:render, _from, state) do
    data =
      for {reg, data} <- state.registers do
        [
          "  ",
          hex(reg),
          ": ",
          for(<<b::1 <- data>>, do: to_string(b)),
          " (",
          reg_name(reg),
          ")\n"
        ]
      end

    {:reply, data, state}
  end

  defp hex(x) do
    [
      Integer.to_string(div(x, 16), 16),
      Integer.to_string(rem(x, 16), 16)
    ]
  end

  defp read_register(state, register) do
    state.registers[register] || <<0>>
  end

  # Section 8.5.2.4 - "Writing data to addresses that do not exist
  # in the register map of the device have no effect."
  defp write_register(state, register, val) when register < 0xEB do
    put_in(state.registers[register], val)
  end

  defp write_register(state, _reg, _val), do: state

  defp reg_name(0x0), do: "SYSTEM_STATUS"
  defp reg_name(0x1), do: "GENERAL_CFG"
  defp reg_name(0x2), do: "DATA_CFG"
  defp reg_name(0x3), do: "OSR_CFG"
  defp reg_name(0x4), do: "OPMODE_CFG"
  defp reg_name(0x5), do: "PIN_CFG"
  defp reg_name(0x7), do: "GPIO_CFG"
  defp reg_name(0x9), do: "GPO_DRIVE_CFG"
  defp reg_name(0xB), do: "GPO_VALUE"
  defp reg_name(0xD), do: "GPI_VALUE"
  defp reg_name(0x10), do: "SEQUENCE_CFG"
  defp reg_name(0x11), do: "CHANNEL_SEL"
  defp reg_name(0x12), do: "AUTO_SEQ_CH_SEL"
  defp reg_name(0x14), do: "ALERT_CH_SEL"
  defp reg_name(0x16), do: "ALERT_MAP"
  defp reg_name(0x17), do: "ALERT_PIN_CFG"
  defp reg_name(0x18), do: "EVENT_FLAG"
  defp reg_name(0x1A), do: "EVENT_HIGH_FLAG"
  defp reg_name(0x1C), do: "EVENT_LOW_FLAG"
  defp reg_name(0x1E), do: "EVENT_RGN"
  defp reg_name(0x20), do: "HYSTERESIS_CH0"
  defp reg_name(0x21), do: "HIGH_TH_CH0"
  defp reg_name(0x22), do: "EVENT_COUNT_CH0"
  defp reg_name(0x23), do: "LOW_TH_CH0"
  defp reg_name(0x24), do: "HYSTERESIS_CH1"
  defp reg_name(0x25), do: "HIGH_TH_CH1"
  defp reg_name(0x26), do: "EVENT_COUNT_CH1"
  defp reg_name(0x27), do: "LOW_TH_CH1"
  defp reg_name(0x28), do: "HYSTERESIS_CH2"
  defp reg_name(0x29), do: "HIGH_TH_CH2"
  defp reg_name(0x2A), do: "EVENT_COUNT_CH2"
  defp reg_name(0x2B), do: "LOW_TH_CH2"
  defp reg_name(0x2C), do: "HYSTERESIS_CH3"
  defp reg_name(0x2D), do: "HIGH_TH_CH3"
  defp reg_name(0x2E), do: "EVENT_COUNT_CH3"
  defp reg_name(0x2F), do: "LOW_TH_CH3"
  defp reg_name(0x30), do: "HYSTERESIS_CH4"
  defp reg_name(0x31), do: "HIGH_TH_CH4"
  defp reg_name(0x32), do: "EVENT_COUNT_CH4"
  defp reg_name(0x33), do: "LOW_TH_CH4"
  defp reg_name(0x34), do: "HYSTERESIS_CH5"
  defp reg_name(0x35), do: "HIGH_TH_CH5"
  defp reg_name(0x36), do: "EVENT_COUNT_CH5"
  defp reg_name(0x37), do: "LOW_TH_CH5"
  defp reg_name(0x38), do: "HYSTERESIS_CH6"
  defp reg_name(0x39), do: "HIGH_TH_CH6"
  defp reg_name(0x3A), do: "EVENT_COUNT_CH6"
  defp reg_name(0x3B), do: "LOW_TH_CH6"
  defp reg_name(0x3C), do: "HYSTERESIS_CH7"
  defp reg_name(0x3D), do: "HIGH_TH_CH7"
  defp reg_name(0x3E), do: "EVENT_COUNT_CH7"
  defp reg_name(0x3F), do: "LOW_TH_CH7"
  defp reg_name(0x60), do: "MAX_CH0_LSB"
  defp reg_name(0x61), do: "MAX_CH0_MSB"
  defp reg_name(0x62), do: "MAX_CH1_LSB"
  defp reg_name(0x63), do: "MAX_CH1_MSB"
  defp reg_name(0x64), do: "MAX_CH2_LSB"
  defp reg_name(0x65), do: "MAX_CH2_MSB"
  defp reg_name(0x66), do: "MAX_CH3_LSB"
  defp reg_name(0x67), do: "MAX_CH3_MSB"
  defp reg_name(0x68), do: "MAX_CH4_LSB"
  defp reg_name(0x69), do: "MAX_CH4_MSB"
  defp reg_name(0x6A), do: "MAX_CH5_LSB"
  defp reg_name(0x6B), do: "MAX_CH5_MSB"
  defp reg_name(0x6C), do: "MAX_CH6_LSB"
  defp reg_name(0x6D), do: "MAX_CH6_MSB"
  defp reg_name(0x6E), do: "MAX_CH7_LSB"
  defp reg_name(0x6F), do: "MAX_CH7_MSB"
  defp reg_name(0x80), do: "MIN_CH0_LSB"
  defp reg_name(0x81), do: "MIN_CH0_MSB"
  defp reg_name(0x82), do: "MIN_CH1_LSB"
  defp reg_name(0x83), do: "MIN_CH1_MSB"
  defp reg_name(0x84), do: "MIN_CH2_LSB"
  defp reg_name(0x85), do: "MIN_CH2_MSB"
  defp reg_name(0x86), do: "MIN_CH3_LSB"
  defp reg_name(0x87), do: "MIN_CH3_MSB"
  defp reg_name(0x88), do: "MIN_CH4_LSB"
  defp reg_name(0x89), do: "MIN_CH4_MSB"
  defp reg_name(0x8A), do: "MIN_CH5_LSB"
  defp reg_name(0x8B), do: "MIN_CH5_MSB"
  defp reg_name(0x8C), do: "MIN_CH6_LSB"
  defp reg_name(0x8D), do: "MIN_CH6_MSB"
  defp reg_name(0x8E), do: "MIN_CH7_LSB"
  defp reg_name(0x8F), do: "MIN_CH7_MSB"
  defp reg_name(0xA0), do: "RECENT_CH0_LSB"
  defp reg_name(0xA1), do: "RECENT_CH0_MSB"
  defp reg_name(0xA2), do: "RECENT_CH1_LSB"
  defp reg_name(0xA3), do: "RECENT_CH1_MSB"
  defp reg_name(0xA4), do: "RECENT_CH2_LSB"
  defp reg_name(0xA5), do: "RECENT_CH2_MSB"
  defp reg_name(0xA6), do: "RECENT_CH3_LSB"
  defp reg_name(0xA7), do: "RECENT_CH3_MSB"
  defp reg_name(0xA8), do: "RECENT_CH4_LSB"
  defp reg_name(0xA9), do: "RECENT_CH4_MSB"
  defp reg_name(0xAA), do: "RECENT_CH5_LSB"
  defp reg_name(0xAB), do: "RECENT_CH5_MSB"
  defp reg_name(0xAC), do: "RECENT_CH6_LSB"
  defp reg_name(0xAD), do: "RECENT_CH6_MSB"
  defp reg_name(0xAE), do: "RECENT_CH7_LSB"
  defp reg_name(0xAF), do: "RECENT_CH7_MSB"
  defp reg_name(0xC3), do: "GPO0_TRIG_EVENT_SEL"
  defp reg_name(0xC5), do: "GPO1_TRIG_EVENT_SEL"
  defp reg_name(0xC7), do: "GPO2_TRIG_EVENT_SEL"
  defp reg_name(0xC9), do: "GPO3_TRIG_EVENT_SEL"
  defp reg_name(0xCB), do: "GPO4_TRIG_EVENT_SEL"
  defp reg_name(0xCD), do: "GPO5_TRIG_EVENT_SEL"
  defp reg_name(0xCF), do: "GPO6_TRIG_EVENT_SEL"
  defp reg_name(0xD1), do: "GPO7_TRIG_EVENT_SEL"
  defp reg_name(0xE9), do: "GPO_TRIGGER_CFG"
  defp reg_name(0xEB), do: "GPO_VALUE_TRIG"
end
