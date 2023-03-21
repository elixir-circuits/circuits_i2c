defmodule CircuitsSim.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias CircuitsSim.Device.AT24C02
  alias CircuitsSim.Device.MCP23008

  @impl Application
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: CircuitSim.DeviceRegistry},
      {DynamicSupervisor, name: CircuitSim.DeviceSupervisor, strategy: :one_for_one},
      {Task, &add_devices/0}
    ]

    opts = [strategy: :one_for_one, name: CircuitsSim.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp config() do
    %{
      "i2c-0" => %{0x20 => MCP23008, 0x50 => AT24C02},
      "i2c-1" => %{0x20 => MCP23008, 0x21 => MCP23008}
    }
  end

  defp add_devices() do
    for {bus_name, devices} <- config() do
      for {address, device} <- devices do
        {:ok, _} =
          DynamicSupervisor.start_child(
            CircuitSim.DeviceSupervisor,
            {device, bus_name: bus_name, address: address}
          )
      end
    end

    :ok
  end
end
