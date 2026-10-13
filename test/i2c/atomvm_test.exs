# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule :i2c do
  def open(parameters), do: call(:open, [parameters], self())
  def close(ref), do: call(:close, [ref], :ok)

  def read_bytes(ref, address, count),
    do: call(:read_bytes, [ref, address, count], {:ok, :binary.copy(<<0>>, count)})

  def read_bytes(ref, address, register, count),
    do: call(:read_bytes, [ref, address, register, count], {:ok, :binary.copy(<<0>>, count)})

  def write_bytes(ref, address, data), do: call(:write_bytes, [ref, address, data], :ok)

  defp call(function, arguments, default) do
    send(self(), {:i2c, function, arguments})

    case Process.get({:i2c, function}, []) do
      [] ->
        default

      [result | rest] ->
        Process.put({:i2c, function}, rest)
        result
    end
  end
end

defmodule Circuits.I2C.AtomVMTest do
  use ExUnit.Case

  alias Circuits.I2C
  alias Circuits.I2C.AtomVM
  alias Circuits.I2C.Bus

  @parameters [peripheral: "i2c0", scl: 22, sda: 21, clock_speed_hz: 100_000]
  @buses [{"main", @parameters}, {"other", [peripheral: "i2c1", scl: 26, sda: 25]}]

  test "bus enumeration only reports configured buses" do
    assert AtomVM.bus_names([]) == []
    assert AtomVM.bus_names(buses: @buses) == ["main", "other"]
  end

  test "opening passes platform-specific driver parameters unchanged" do
    assert {:ok, %AtomVM{ref: ref, retries: 0}} = AtomVM.open("main", buses: @buses)
    assert ref == self()
    assert_received {:i2c, :open, [@parameters]}

    parameters = [peripheral: "I2C1", scl: 5, sda: 4, clock_speed_hz: 400_000]
    assert {:ok, _bus} = AtomVM.open("sensor", buses: [{"sensor", parameters}])
    assert_received {:i2c, :open, [^parameters]}
  end

  test "unknown buses do not open a driver" do
    assert {:error, :bus_not_found} = AtomVM.open("missing", buses: @buses)
    assert {:error, :bus_not_found} = AtomVM.open("main", [])
    refute_received {:i2c, :open, _}
  end

  test "invalid default retries are rejected before opening" do
    for retries <- [-1, nil, 1.5] do
      assert_raise ArgumentError, "retries must be a non-negative integer", fn ->
        AtomVM.open("main", buses: @buses, retries: retries)
      end
    end

    refute_received {:i2c, :open, _}
  end

  test "info identifies the backend and flags avoid empty-write probing" do
    assert AtomVM.info() == %{backend: AtomVM}
    assert Bus.flags(open_bus()) == []
  end

  test "public transfer functions dispatch to the AtomVM bus" do
    bus = open_bus()
    ref = bus.ref

    assert {:ok, <<0, 0>>} = I2C.read(bus, 0x48, 2)
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 2]}

    assert :ok = I2C.write(bus, 0x48, [<<1>>, [2, <<3>>]])
    assert_received {:i2c, :write_bytes, [^ref, 0x48, <<1, 2, 3>>]}

    assert :ok = I2C.close(bus)
    assert_received {:i2c, :close, [^ref]}
  end

  test "the backend can also be selected through application config on OTP" do
    original_backend = Application.fetch_env!(:circuits_i2c, :default_backend)
    on_exit(fn -> Application.put_env(:circuits_i2c, :default_backend, original_backend) end)

    Application.put_env(:circuits_i2c, :default_backend, {AtomVM, buses: @buses, retries: 2})

    assert I2C.bus_names() == ["main", "other"]
    assert {:ok, %AtomVM{retries: 1} = bus} = I2C.open("main", retries: 1)
    assert I2C.info() == %{backend: AtomVM}
    assert :ok = I2C.close(bus)
  end

  test "single-byte write_read uses the driver's combined register read" do
    bus = open_bus()
    ref = bus.ref

    assert {:ok, <<0, 0>>} = I2C.write_read(bus, 0x48, [[<<7>>]], 2)
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 7, 2]}
    refute_received {:i2c, :write_bytes, _}
  end

  test "empty write_read performs just a read" do
    bus = open_bus()
    ref = bus.ref

    assert {:ok, <<0>>} = I2C.write_read(bus, 0x48, [<<>>], 1)
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 1]}
    refute_received {:i2c, :write_bytes, _}
  end

  test "longer combined writes are unsupported without any driver transfers" do
    bus = open_bus()

    assert {:error, :not_supported} = I2C.write_read(bus, 0x48, [1, <<2>>], 2)
    refute_received {:i2c, :read_bytes, _}
    refute_received {:i2c, :write_bytes, _}
  end

  test "default retries repeat failed reads but stop after success" do
    bus = open_bus(retries: 2)
    ref = bus.ref
    Process.put({:i2c, :read_bytes}, [{:error, :timeout}, {:ok, <<42>>}])

    assert {:ok, <<42>>} = I2C.read(bus, 0x48, 1)
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 1]}
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 1]}
    refute_received {:i2c, :read_bytes, _}
  end

  test "per-transfer retries override the default in either direction" do
    bus = open_bus(retries: 2)
    ref = bus.ref
    Process.put({:i2c, :read_bytes}, [{:error, :timeout}])

    assert {:error, :timeout} = I2C.read(bus, 0x48, 1, retries: 0)
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 1]}
    refute_received {:i2c, :read_bytes, _}

    bus = open_bus()
    Process.put({:i2c, :write_bytes}, [{:error, :timeout}, :ok])

    assert :ok = I2C.write(bus, 0x48, <<1>>, retries: 1)
    assert_received {:i2c, :write_bytes, [^ref, 0x48, <<1>>]}
    assert_received {:i2c, :write_bytes, [^ref, 0x48, <<1>>]}
    refute_received {:i2c, :write_bytes, _}
  end

  test "combined reads retry the entire register transaction" do
    bus = open_bus(retries: 1)
    ref = bus.ref
    Process.put({:i2c, :read_bytes}, [{:error, :timeout}, {:ok, <<42>>}])

    assert {:ok, <<42>>} = I2C.write_read(bus, 0x48, <<7>>, 1)
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 7, 1]}
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 7, 1]}
    refute_received {:i2c, :read_bytes, _}
    refute_received {:i2c, :write_bytes, _}
  end

  test "retry exhaustion returns the last driver error" do
    bus = open_bus(retries: 1)
    ref = bus.ref
    Process.put({:i2c, :read_bytes}, [{:error, :timeout}, {:error, :nak}, {:ok, <<42>>}])

    assert {:error, :nak} = I2C.read(bus, 0x48, 1)
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 1]}
    assert_received {:i2c, :read_bytes, [^ref, 0x48, 1]}
    refute_received {:i2c, :read_bytes, _}
  end

  test "invalid per-transfer retries do not call the driver" do
    bus = open_bus()

    for retries <- [-1, nil, 1.5],
        transfer <- [
          fn -> I2C.read(bus, 0x48, 1, retries: retries) end,
          fn -> I2C.write(bus, 0x48, <<1>>, retries: retries) end,
          fn -> I2C.write_read(bus, 0x48, <<7>>, 1, retries: retries) end
        ] do
      assert_raise ArgumentError, "retries must be a non-negative integer", transfer
    end

    refute_received {:i2c, :read_bytes, _}
    refute_received {:i2c, :write_bytes, _}
  end

  test "public bang transfers raise on driver errors" do
    bus = open_bus()
    Process.put({:i2c, :read_bytes}, [{:error, :timeout}, {:error, :timeout}])
    Process.put({:i2c, :write_bytes}, [{:error, :timeout}])

    assert_raise RuntimeError, "I2C failure: :timeout", fn -> I2C.read!(bus, 0x48, 1) end
    assert_raise RuntimeError, "I2C failure: :timeout", fn -> I2C.write!(bus, 0x48, <<1>>) end

    assert_raise RuntimeError, "I2C failure: :timeout", fn ->
      I2C.write_read!(bus, 0x48, <<7>>, 1)
    end
  end

  test "close errors are surfaced" do
    bus = open_bus()
    Process.put({:i2c, :close}, [{:error, :timeout}])

    assert_raise RuntimeError, "I2C close failed: :timeout", fn -> I2C.close(bus) end
  end

  defp open_bus(options \\ []) do
    {:ok, bus} = AtomVM.open("main", [{:buses, @buses} | options])
    bus
  end
end
