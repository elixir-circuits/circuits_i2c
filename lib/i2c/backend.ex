# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.I2C.Backend do
  @moduledoc """
  Backends provide the connection to the real or virtual I2C controller
  """
  alias Circuits.I2C.Bus

  @typedoc """
  I2C transfer options

  Support for options is backend-specific. Backends are encouraged to
  implement the following:

  * `:retries` - the number of retries for this transaction
  """
  @type transfer_options() :: keyword()

  @doc """
  Return the I2C bus names on this system

  See backend documentation for options.
  """
  @callback bus_names(options :: keyword()) :: [binary()]

  @doc """
  Open an I2C bus

  Bus names are typically of the form `"i2c-n"` and available buses may be
  found by calling `bus_names/1`.

  See `t:Circuits.I2C.open_options/0` for guidance on options.
  """
  @callback open(bus_name :: String.t(), options :: keyword()) ::
              {:ok, Bus.t()} | {:error, term()}

  @doc """
  Return information about this backend
  """
  @callback info() :: map()
end
