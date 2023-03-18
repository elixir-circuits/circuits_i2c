defmodule Circuits.I2CNifTest do
  use ExUnit.Case

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
      {:ok, i2c} = Nif.open("i2c-test-0")
      Nif.close(i2c)

      {:ok, i2c} = Nif.open("i2c-test-1")
      Nif.close(i2c)

      assert {:error, _} = Nif.open("i2c-2")
    end
  end

  test "flags/1" do
    {:ok, i2c} = Nif.open("i2c-test-0")
    assert Nif.flags(i2c) == []
    Nif.close(i2c)
  end

  test "unloading NIF" do
    # The theory here is that there shouldn't be a crash if this is reloaded a
    # few times.
    for _times <- 1..10 do
      assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)

      # Try running something to verify that it works.
      {:ok, i2c} = Nif.open("i2c-test-0")
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
    test "unloading NIF" do
      # The theory here is that there shouldn't be a crash if this is reloaded a
      # few times.
      for _times <- 1..10 do
        assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)

        # Try running something to verify that it works.
        {:ok, i2c} = Nif.open("i2c-test-0")
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
