defmodule CircuitsSim.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

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

  defp add_devices() do
    config = Application.get_env(:circuits_sim, :config, %{})

    Enum.each(config, fn {bus_name, devices} ->
      Enum.each(devices, fn {address, device} ->
        {:ok, _} =
          DynamicSupervisor.start_child(
            CircuitSim.DeviceSupervisor,
            {device, bus_name: bus_name, address: address}
          )
      end)
    end)
  end
end
