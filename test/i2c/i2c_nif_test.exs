# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.I2CNifTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Circuits.I2C.Nif

  describe "info/0" do
    test "info identifies as a i2c_dev_test and not a real i2c driver" do
      info = Nif.info()

      assert is_map(info)
      assert info.test?
    end
  end

  describe "open/1" do
    test "i2c-test-0 and i2c-test-1 work" do
      {:ok, i2c, flags} = Nif.open("i2c-test-0", -1)
      Nif.close(i2c)
      assert flags == []

      {:ok, i2c, flags} = Nif.open("i2c-test-1", -1)
      Nif.close(i2c)
      assert flags == []

      assert {:error, _} = Nif.open("i2c-2", -1)
    end
  end

  test "unloading NIF" do
    # The theory here is that there shouldn't be a crash if this is reloaded a
    # few times.
    for _times <- 1..10 do
      assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)

      # Try running something to verify that it works.
      {:ok, i2c, _} = Nif.open("i2c-test-0", -1)
      assert is_reference(i2c)
      Nif.close(i2c)

      assert true == :code.delete(Circuits.I2C.Nif)

      # The purge will call the unload which can be verified by turning DEBUG on
      # in the C code.
      assert false == :code.purge(Circuits.I2C.Nif)
    end
  end

  test "setting backend to unknown value doesn't load the NIF" do
    original_backend = Application.get_env(:circuits_i2c, :default_backend)

    # Unload the current code if loaded
    _ = :code.delete(Circuits.I2C.Nif)
    _ = :code.purge(Circuits.I2C.Nif)

    # Attempt loading. NIF shouldn't be loaded this time.
    Application.put_env(:circuits_i2c, :default_backend, Some.Other.Backend)
    assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)
    assert_raise UndefinedFunctionError, fn -> Circuits.I2C.info() end

    # Cleanup
    assert true == :code.delete(Circuits.I2C.Nif)
    assert false == :code.purge(Circuits.I2C.Nif)
    Application.put_env(:circuits_i2c, :default_backend, original_backend)
  end

  describe "load tests" do
    test "hot reload preserves open bus handle" do
      assert {:module, Nif} == :code.ensure_loaded(Nif)
      {:ok, i2c, _flags} = Nif.open("i2c-test-0", -1)

      try do
        assert {:ok, <<0x10, 0x11, 0x12>>} == Nif.read(i2c, 0x10, 3, 0)

        {Nif, binary, filename} = :code.get_object_code(Nif)

        for _times <- 1..3 do
          # Simulate a hot code reload by manually loading the binary again
          assert {:module, Nif} == :code.load_binary(Nif, filename, binary)
          assert :code.soft_purge(Nif)

          # Reference still works
          assert {:ok, <<0x10, 0x11, 0x12>>} == Nif.read(i2c, 0x10, 3, 0)
          assert :ok == Nif.write(i2c, 0x10, <<1>>, 0)
        end
      after
        assert :ok == Nif.close(i2c)
      end
    end

    @tag :tmp_dir
    test "hot reload fails on ABI mismatch", %{tmp_dir: tmp_dir} do
      assert {:module, Nif} == :code.ensure_loaded(Nif)

      original_app_dir = Application.app_dir(:circuits_i2c)
      original_ebin = String.to_charlist(Path.join(original_app_dir, "ebin"))

      on_exit(fn ->
        assert true == :code.replace_path(:circuits_i2c, original_ebin)
      end)

      app_dir = create_incompatible_app(original_app_dir, tmp_dir)
      {:ok, i2c, _flags} = Nif.open("i2c-test-0", -1)

      try do
        true = :code.replace_path(:circuits_i2c, String.to_charlist(Path.join(app_dir, "ebin")))

        log =
          capture_log(fn ->
            assert {:error, :on_load_failure} = :code.load_file(Nif)
            # OTP emits the on_load failure warning asynchronously so wait a bit
            Process.sleep(10)
          end)

        assert log =~ "[warning] The on_load function for module Elixir.Circuits.I2C.Nif returned"
        assert {:ok, <<0x10, 0x11, 0x12>>} == Nif.read(i2c, 0x10, 3, 0)
      after
        assert :ok == Nif.close(i2c)
      end
    end

    defp create_incompatible_app(src_app_dir, tmp_dir) do
      new_app_dir = Path.join(tmp_dir, "circuits_i2c")
      File.cp_r!(src_app_dir, new_app_dir)

      # Binary patch the shared library to give it a new ABI
      nif_path = Path.join(new_app_dir, "priv/i2c_nif.so")
      original_nif = File.read!(nif_path)
      new_nif = :binary.replace(original_nif, "i2c_nif_res_v1", "i2c_nif_res_v2")
      assert original_nif != new_nif
      File.write!(nif_path, new_nif)
      code_sign(nif_path, :os.type())

      new_app_dir
    end

    defp code_sign(path, {:unix, :darwin}) do
      {_, 0} = System.cmd("codesign", ["--force", "--sign", "-", path], stderr_to_stdout: true)
      :ok
    end

    defp code_sign(_path, _other), do: :ok

    test "unloading NIF" do
      # The theory here is that there shouldn't be a crash if this is reloaded a
      # few times.
      for _times <- 1..10 do
        assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)

        # Try running something to verify that it works.
        {:ok, i2c, _} = Nif.open("i2c-test-0", -1)
        assert is_reference(i2c)
        Nif.close(i2c)

        assert true == :code.delete(Circuits.I2C.Nif)

        # The purge will call the unload which can be verified by turning DEBUG on
        # in the C code.
        assert false == :code.purge(Circuits.I2C.Nif)
      end

      # Load it again for any other subsequent tests
      assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)
    end
  end
end
