# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.I2CNifUpgradeTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Circuits.I2C.Nif

  # Hot code upgrades load the NIF from a second copy of the app while the
  # current one is still loaded.
  @moduletag :tmp_dir

  setup do
    app_dir = Application.app_dir(:circuits_i2c)

    on_exit(fn ->
      load_from(app_dir)
      :code.purge(Nif)
    end)

    %{app_dir: app_dir}
  end

  test "open buses keep working after an upgrade", %{app_dir: app_dir, tmp_dir: tmp_dir} do
    {:ok, i2c, _} = Nif.open("i2c-test-0", -1)

    assert {:module, Nif} == load_from(copy_app(app_dir, tmp_dir))
    :code.purge(Nif)

    assert {:ok, <<16, 17>>} == Nif.read(i2c, 0x10, 2, 0)
    Nif.close(i2c)
  end

  test "upgrade is refused when the ABI differs", %{app_dir: app_dir, tmp_dir: tmp_dir} do
    {:ok, i2c, _} = Nif.open("i2c-test-0", -1)

    new_app_dir = copy_app(app_dir, tmp_dir)
    nif_path = Path.join(new_app_dir, "priv/i2c_nif.so")
    nif = File.read!(nif_path) |> String.replace("i2c_nif_abi_", "i2c_nif_xyz_")
    File.write!(nif_path, nif)

    capture_log(fn -> assert {:error, :on_load_failure} == load_from(new_app_dir) end)

    assert {:ok, <<16, 17>>} == Nif.read(i2c, 0x10, 2, 0)
    Nif.close(i2c)
  end

  defp copy_app(app_dir, tmp_dir) do
    new_app_dir = Path.join(tmp_dir, "circuits_i2c")
    File.cp_r!(app_dir, new_app_dir)
    new_app_dir
  end

  defp load_from(app_dir) do
    true = :code.replace_path(:circuits_i2c, String.to_charlist(Path.join(app_dir, "ebin")))
    :code.purge(Nif)
    :code.load_file(Nif)
  end
end
