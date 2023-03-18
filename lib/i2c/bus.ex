defprotocol Circuits.I2C.Bus do
  @moduledoc """
  A bus is the connection to a real or virtual I2C controller
  """

  @doc """
  Read data over I2C

  The controller should try to read the specified number of bytes over I2C.
  If the retry option is passed and non-zero, the transaction only needs to
  be retried if there's an error. This means that fewer that the requested
  number of bytes may be returned.

  See the implementation for options
  """
  @spec read(t(), Circuits.I2C.address(), non_neg_integer(), keyword()) ::
          {:ok, binary()} | {:error, term()}
  def read(backend, address, count, options)

  @doc """
  Write data over I2C

  The controller should write the passed in data to the specified I2C address.
  """
  @spec write(t(), Circuits.I2C.address(), iodata(), keyword()) :: :ok | {:error, term()}
  def write(backend, address, data, options)

  @doc """
  Write data and read a result in one I2C transaction

  This function handles the common task of writing a register number
  to a device and then reading its contents. The controller should perform it
  as one transaction without a stop condition between the write and read.
  """
  @spec write_read(t(), Circuits.I2C.address(), iodata(), non_neg_integer(), keyword()) ::
          {:ok, binary()} | {:error, term()}
  def write_read(backend, address, write_data, read_count, options)

  @doc """
  Free up resources associated with the bus

  Well behaved backends free up their resources with the help of the Erlang garbage collector. However, it is good
  practice for users to call `Circuits.I2C.close/1` (and hence this function) so that
  limited resources are freed before they're needed again.
  """
  @spec close(t()) :: :ok
  def close(backend)
end
