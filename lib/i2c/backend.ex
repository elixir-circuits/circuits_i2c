defmodule Circuits.I2C.Backend do
  @moduledoc """
  Backends provide the connection to the real or virtual I2C controller
  """

  @typedoc """
  I2C transfer options

  Support for options is backend-specific. Backends are encouraged to
  implement the following:

  * `:retries` - a number of times to attempt to retry the transaction
    before failing
  """
  @type options() :: keyword()

  alias Circuits.I2C.Bus

  @doc """
  Return the I2C bus names on this system

  No supported options
  """
  @callback bus_names(options :: keyword()) :: [binary()]

  @doc """
  Open an I2C bus

  Bus names are typically of the form `"i2c-n"` and available buses may be
  found by calling `Circuits.I2C.I2CDev.bus_names/0`.

  Options:

  * `:retries` - Specify a nonnegative integer for how many times to retry
    a failed I2C operation.
  """
  @callback open(bus_name :: String.t(), options :: keyword()) ::
              {:ok, Bus.t()} | {:error, term()}

  @doc """
  Return information about this backend
  """
  @callback info() :: map()
end
