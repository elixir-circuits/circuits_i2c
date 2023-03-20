defmodule CircuitsSim.DeviceRegistry do
  @moduledoc false

  alias Circuits.I2C

  @spec via_name(I2C.bus_name(), I2C.address()) :: {:via, Registry, tuple()}
  def via_name(bus, address) do
    {:via, Registry, {CircuitSim.DeviceRegistry, {bus, address}}}
  end

  @spec bus_names() :: [Circuits.I2C.bus_name()]
  def bus_names() do
    # The select returns [{{"i2c-0", 32}}]
    Registry.select(CircuitSim.DeviceRegistry, [{{:"$1", :_, :_}, [], [{{:"$1"}}]}])
    |> Enum.map(&extract_bus_name/1)
    |> Enum.uniq()
  end

  defp extract_bus_name({{bus_name, _address}}), do: bus_name
end
