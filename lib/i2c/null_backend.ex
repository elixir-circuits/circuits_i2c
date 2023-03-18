defmodule Circuits.I2C.NilBackend do
  @moduledoc """
  Circuits.I2C backend when nothing else is available
  """

  @doc """
  Return the I2C bus names on this system

  No supported options
  """
  @spec bus_names(keyword()) :: [<<_::80>>, ...]
  def bus_names(_options \\ []), do: []

  @doc """
  Open an I2C bus

  No supported options.
  """
  @spec open(String.t(), keyword()) :: {:error, term()}
  def open(_bus_name, _options \\ []) do
    {:error, :unimplemented}
  end

  @doc """
  Return information about this backend
  """
  @spec info() :: map()
  def info() do
    %{name: __MODULE__}
  end
end
