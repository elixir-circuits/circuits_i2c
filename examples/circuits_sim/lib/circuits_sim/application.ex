defmodule CircuitsSim.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias CircuitsSim.SimpleI2CServer
  alias CircuitsSim.Device.GPIOExpander
  alias CircuitsSim.Device.AT24C02

  @impl Application
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: CircuitSim.DeviceRegistry},
      {DynamicSupervisor, name: CircuitSim.DeviceSupervisor},
      {Task, &add_devices/0}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CircuitsSim.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp add_devices() do
    DynamicSupervisor.start_child(
      CircuitSim.DeviceSupervisor,
      {SimpleI2CServer, bus_name: "i2c-0", address: 0x20, device: GPIOExpander.new()}
    )

    DynamicSupervisor.start_child(
      CircuitSim.DeviceSupervisor,
      {SimpleI2CServer, bus_name: "i2c-0", address: 0x50, device: AT24C02.new()}
    )
  end
end
