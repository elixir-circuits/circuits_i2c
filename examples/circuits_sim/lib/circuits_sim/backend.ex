defmodule CircuitsSim.Backend do
  @moduledoc """
  Circuits.I2C backend that has a virtual GPIO Expander on it
  """
  @behaviour Circuits.I2C.Backend

  alias Circuits.I2C.Backend
  alias CircuitsSim.Bus
  alias CircuitsSim.DeviceRegistry

  @doc """
  Return the I2C bus names on this system

  No supported options
  """
  @impl Backend
  def bus_names(_options) do
    DeviceRegistry.bus_names()
  end

  @doc """
  Open an I2C bus
  """
  @impl Backend
  def open(bus_name, options) do
    if bus_name in bus_names(options) do
      {:ok, %Bus{bus_name: bus_name}}
    else
      {:error, "Unknown controller #{bus_name}"}
    end
  end

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info() do
    %{backend: __MODULE__}
  end
end
