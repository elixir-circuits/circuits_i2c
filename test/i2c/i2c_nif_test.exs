defmodule Circuits.I2CNifTest do
  use ExUnit.Case

  alias Circuits.I2C

  test "info says it's the stub" do
    info = I2C.info()

    assert is_map(info)
    assert info.name == :stub

    # These should be 0, but sometimes there's a straggler that doesn't get
    # garbage collected fast enough from another test. They definitely shouldn't
    # be negative, though.
    assert info.i2c_test_0_open >= 0
    assert info.i2c_test_1_open >= 0
  end

  test "unloading NIF" do
    # The theory here is that there shouldn't be a crash if this is reloaded a
    # few times.
    for _times <- 1..10 do
      assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)

      # Try running something to verify that it works.
      {:ok, i2c} = I2C.open("i2c-test-0")
      assert is_reference(i2c)
      I2C.close(i2c)

      assert true == :code.delete(Circuits.I2C.Nif)

      # The purge will call the unload which can be verified by turning DEBUG on
      # in the C code.
      assert false == :code.purge(Circuits.I2C.Nif)
    end

    # Load it again for any other subsequent tests
    assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)
  end
end
