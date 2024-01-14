defmodule Circuits.I2C.Nif do
  @moduledoc false

  defp load_nif_and_apply(fun, args) do
    nif_binary = Application.app_dir(:circuits_i2c, "priv/i2c_nif")

    # Optimistically load the NIF. Handle the possible race.
    case :erlang.load_nif(to_charlist(nif_binary), 0) do
      :ok -> apply(__MODULE__, fun, args)
      {:error, {:reload, _}} -> apply(__MODULE__, fun, args)
      error -> error
    end
  end

  def open(device) do
    load_nif_and_apply(:open, [device])
  end

  def read(_ref, _address, _count, _retries), do: :erlang.nif_error(:nif_not_loaded)
  def write(_ref, _address, _data, _retries), do: :erlang.nif_error(:nif_not_loaded)

  def write_read(_ref, _address, _write_data, _read_count, _retries),
    do: :erlang.nif_error(:nif_not_loaded)

  def close(_ref), do: :erlang.nif_error(:nif_not_loaded)

  def info() do
    load_nif_and_apply(:info, [])
  end
end
