defmodule Circuits.I2CTest do
  use ExUnit.Case

  alias Circuits.I2C

  # These tests assume that the Circuits.I2C NIF has been compiled in unit test
  # mode (MIX_ENV=test). When in this mode, it's possible to open "i2c-test-0" and
  # "i2c-test-1". Address 0x10 returns fake data on "i2c-test-0" and address 0x20 returns
  # fake data on "i2c-test-1". All other devices and addresses return errors.

  test "bus_names returns a list" do
    names = I2C.bus_names()

    assert is_list(names)
    assert "i2c-test-0" in names
    assert "i2c-test-1" in names
    assert "i2c-flaky" in names
  end

  test "can open all buses" do
    for bus_name <- I2C.bus_names() do
      {:ok, i2c} = I2C.open(bus_name)
      assert %Circuits.I2C.I2CDev{} = i2c
      I2C.close(i2c)
    end
  end

  test "error when opening unknown bus" do
    assert {:error, :bus_not_found} == I2C.open("bad-i2c-bus")
  end

  test "detects i2c_dev_test I2C devices" do
    # See hal_stub.c for fake devices
    assert [0x10] == I2C.detect_devices("i2c-test-0")
    assert [0x20] == I2C.detect_devices("i2c-test-1")
    assert {:error, :bus_not_found} == I2C.detect_devices("bad-i2c-bus")
  end

  test "device_present?" do
    {:ok, i2c} = I2C.open("i2c-test-0")
    assert I2C.device_present?(i2c, 0x10)
    refute I2C.device_present?(i2c, 0x11)
    I2C.close(i2c)
  end

  test "discover/1" do
    assert [{"i2c-test-0", 0x10}, {"i2c-test-1", 0x20}] == I2C.discover([0x10, 0x20])
    assert [{"i2c-test-0", 0x10}] == I2C.discover([0x10])
    assert [] == I2C.discover([0x15])
  end

  test "discover/2" do
    ids = [0x10, 0x20]

    # Device 0x10 returns 0 and device 0x20 returns 0xff from the i2c_dev_test backend
    assert [{"i2c-test-0", 0x10}] == I2C.discover(ids, &i2c_returns(&1, &2, <<0x10>>))
    assert [{"i2c-test-1", 0x20}] == I2C.discover(ids, &i2c_returns(&1, &2, <<0x20>>))
  end

  test "discover_one/2" do
    ids = [0x10, 0x20]

    assert {:ok, {"i2c-test-0", 0x10}} == I2C.discover_one(ids, &i2c_returns(&1, &2, <<0x10>>))
    assert {:error, :not_found} == I2C.discover_one(ids, &i2c_returns(&1, &2, <<1>>))
    assert {:error, :multiple_possible_matches} == I2C.discover_one(ids)
  end

  test "discover_one!/2" do
    ids = [0x10, 0x20]

    assert {"i2c-test-0", 0x10} == I2C.discover_one!(ids, &i2c_returns(&1, &2, <<0x10>>))
    assert_raise RuntimeError, fn -> I2C.discover_one!(ids, &i2c_returns(&1, &2, <<1>>)) end
    assert_raise RuntimeError, fn -> I2C.discover_one!(ids) end
  end

  defp i2c_returns(bus, address, what) do
    I2C.read(bus, address, 1) == {:ok, what}
  end
end
