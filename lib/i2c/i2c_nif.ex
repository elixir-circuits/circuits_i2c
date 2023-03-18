defmodule Circuits.I2C.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  @moduledoc false

  def load_nif() do
    # Only load the NIF if using supported backends
    load? =
      case Application.get_env(:circuits_i2c, :default_backend) do
        Circuits.I2C.I2CDev -> true
        {Circuits.I2C.I2CDev, _} -> true
        _ -> false
      end

    if load? do
      nif_binary = Application.app_dir(:circuits_i2c, "priv/i2c_nif")
      :erlang.load_nif(to_charlist(nif_binary), 0)
    else
      :ok
    end
  end

  def open(_device), do: :erlang.nif_error(:nif_not_loaded)
  def flags(_ref), do: :erlang.nif_error(:nif_not_loaded)
  def read(_ref, _address, _count, _retries), do: :erlang.nif_error(:nif_not_loaded)
  def write(_ref, _address, _data, _retries), do: :erlang.nif_error(:nif_not_loaded)

  def write_read(_ref, _address, _write_data, _read_count, _retries),
    do: :erlang.nif_error(:nif_not_loaded)

  def close(_ref), do: :erlang.nif_error(:nif_not_loaded)
  def info(), do: :erlang.nif_error(:nif_not_loaded)
end
