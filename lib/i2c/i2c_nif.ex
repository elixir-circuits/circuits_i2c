defmodule ElixirCircuits.I2C.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  @doc """
  Elixir interface to I2C Natively Implemented Funtions (NIFs)
  """

  def load_nif() do
    nif_exec = '#{:code.priv_dir(:i2c)}/i2c_nif'
    :erlang.load_nif(nif_exec, 0)
  end

  def open(_device) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def read(_fd, _address, _count) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def write(_fd, _address, _data) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def write_read(_fd, _address, _write_data, _read_count) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
