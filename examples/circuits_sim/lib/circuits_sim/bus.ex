defmodule CircuitsSim.Bus do
  @moduledoc """
  Circuits.I2C bus that has a virtual GPIO Expander on it
  """

  alias Circuits.I2C.Bus
  alias CircuitsSim.SimpleI2CServer

  defstruct [:bus_name]
  @type t() :: %__MODULE__{bus_name: String.t()}

  @spec render(t()) :: String.t()
  def render(%__MODULE__{} = bus) do
    for address <- 0..127 do
      info = SimpleI2CServer.render(bus.bus_name, address)
      if info != [], do: ["Device 0x#{address}: \n", info, "\n"], else: []
    end
    |> IO.ANSI.format()
    |> IO.iodata_to_binary()
  end

  defimpl Bus do
    @impl Bus
    def read(%CircuitsSim.Bus{} = bus, address, count, _options) do
      SimpleI2CServer.read(bus.bus_name, address, count)
    end

    @impl Bus
    def write(%CircuitsSim.Bus{} = bus, address, data, _options) do
      SimpleI2CServer.write(bus.bus_name, address, data)
    end

    @impl Bus
    def write_read(
          %CircuitsSim.Bus{} = bus,
          address,
          write_data,
          read_count,
          _options
        ) do
      SimpleI2CServer.write_read(bus.bus_name, address, write_data, read_count)
    end

    @impl Bus
    def close(%CircuitsSim.Bus{}), do: :ok
  end
end
