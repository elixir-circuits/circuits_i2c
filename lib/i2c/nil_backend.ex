# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.I2C.NilBackend do
  @moduledoc """
  Circuits.I2C backend when nothing else is available
  """
  @behaviour Circuits.I2C.Backend

  alias Circuits.I2C.Backend

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
end
