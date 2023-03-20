defmodule CircuitsSim.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias CircuitsSim.Device.AT24C02
  alias CircuitsSim.Device.GPIOExpander
  alias CircuitsSim.SimpleI2CServer

  @impl Application
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: CircuitSim.DeviceRegistry},
      {DynamicSupervisor, name: CircuitSim.DeviceSupervisor, strategy: :one_for_one},
      {Task, &add_devices/0}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CircuitsSim.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp add_devices() do
    _ =
      DynamicSupervisor.start_child(
        CircuitSim.DeviceSupervisor,
        {SimpleI2CServer, bus_name: "i2c-0", address: 0x20, device: GPIOExpander.new()}
      )

    _ =
      DynamicSupervisor.start_child(
        CircuitSim.DeviceSupervisor,
        {SimpleI2CServer, bus_name: "i2c-0", address: 0x50, device: AT24C02.new()}
      )

    :ok
  end
end
