# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.I2C.NilBackend do
  @moduledoc """
  Circuits.I2C backend when nothing else is available
  """
  @behaviour Circuits.I2C.Backend

  alias Circuits.I2C.Backend
  alias Circuits.I2C.Bus

  defstruct []

  @doc """
  Return the I2C bus names on this system

  No supported options
  """
  @impl Backend
  def bus_names(_options), do: []

  @doc """
  Open an I2C bus

  No supported options.
  """
  @impl Backend
  def open(_bus_name, _options) do
    {:error, :unimplemented}
  end

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info() do
    %{name: __MODULE__}
  end

  defimpl Bus do
    @impl Bus
    def flags(%Circuits.I2C.NilBackend{}), do: []

    @impl Bus
    def read(%Circuits.I2C.NilBackend{}, _address, _count, _options) do
      {:error, :unimplemented}
    end

    @impl Bus
    def write(%Circuits.I2C.NilBackend{}, _address, _data, _options) do
      {:error, :unimplemented}
    end

    @impl Bus
    def write_read(%Circuits.I2C.NilBackend{}, _address, _write_data, _read_count, _options) do
      {:error, :unimplemented}
    end

    @impl Bus
    def close(%Circuits.I2C.NilBackend{}), do: :ok
  end
end
