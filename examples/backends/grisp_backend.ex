defmodule Circuits.I2C.GRiSP do
  @moduledoc """
  Circuits.I2C backend for GRiSP
  """
  @behaviour Circuits.I2C.Backend

  alias Circuits.I2C.Backend
  alias Circuits.I2C.Bus

  defstruct [:ref]

  @doc """
  Return the I2C bus names on this system

  No supported options
  """
  @impl Backend
  def bus_names(_options) do
    :grisp_i2c.buses() |> Map.keys() |> Enum.map(&Atom.to_string/1)
  end

  @doc """
  Open an I2C bus
  """
  @impl Backend
  def open(bus_name, _options) do
    ref = :grisp_i2c.open(String.to_atom(bus_name))
    {:ok, %__MODULE__{ref: ref}}
  end

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info() do
    %{backend: __MODULE__}
  end

  defimpl Bus do
    @impl Bus
    def read(%Circuits.I2C.GRiSP{ref: ref}, address, count, _options) do
      with [result] <- :grisp_i2c.transfer(ref, [{:read, address, 0, count}]) do
        {:ok, result}
      end
    end

    @impl Bus
    def write(%Circuits.I2C.GRiSP{ref: ref}, address, data, _options) do
      with [:ok] <- :grisp_i2c.transfer(ref, [{:write, address, 0, data}]) do
        :ok
      end
    end

    @impl Bus
    def write_read(
          %Circuits.I2C.GRiSP{ref: ref},
          address,
          write_data,
          read_count,
          options
        ) do
      with [:ok, result] <-
             :grisp_i2c.transfer(ref, [
               {:write, address, 0, write_data},
               {:read, address, 0, count}
             ]) do
        {:ok, result}
      end
    end

    @impl Bus
    def close(%Circuits.I2C.GRiSP{ref: ref}) do
      :ok
    end
  end
end
