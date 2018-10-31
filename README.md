# Elixir Circuits - I2C

[![CircleCI](https://circleci.com/gh/elixir-circuits/circuits_i2c.svg?style=svg)](https://circleci.com/gh/elixir-circuits/circuits_i2c)
[![Hex version](https://img.shields.io/hexpm/v/circuits_i2c.svg "Hex version")](https://hex.pm/packages/circuits_i2c)

`Circuits.I2C` lets you communicate with hardware devices using the I2C
protocol.

If you're coming from Elixir/ALE, check out our [porting guide](PORTING.md).

## Getting started

If you're using Nerves or compiling on a Raspberry Pi or other device with I2C
support, then add `circuits_i2c` like any other Elixir library:

```elixir
def deps do
  [{:circuits_i2c, "~> 0.1"}]
end
```

`Circuits.I2C` doesn't load device drivers, so you'll need to load any necessary
ones beforehand.  On the Raspberry Pi, the [Adafruit Raspberry Pi I2C
instructions](https://learn.adafruit.com/adafruits-raspberry-pi-lesson-4-gpio-setup/configuring-i2c)
may be helpful.

Internally, it uses the [Linux "i2cdev"
interface](https://elixir.bootlin.com/linux/latest/source/Documentation/i2c/dev-interface)
so that it does not require board-dependent code.

## Examples

The following examples were tested on a Raspberry Pi that was connected to an
[Erlang Embedded Demo Board](http://solderpad.com/omerk/erlhwdemo/). There's
nothing special about either the demo board or the Raspberry Pi, so these should
work similarly on other embedded Linux platforms.

## I2C

An [Inter-Integrated Circuit](https://en.wikipedia.org/wiki/I%C2%B2C) (I2C) bus
supports addressing hardware components and bidirectional use of the data line.

The following shows a bus IO expander connected via I2C to the processor.

![I2C schematic](assets/images/schematic-i2c.png)

The protocol for talking to the IO expander is described in the [MCP23008
Datasheet](http://www.microchip.com/wwwproducts/Devices.aspx?product=MCP23008).
Here's a simple example of using it.

```elixir
# On the Raspberry Pi, the IO expander is connected to I2C bus 1 (i2c-1).
# Its 7-bit address is 0x20. (see datasheet)
iex> alias Circuits.I2C
Circuits.I2C
iex> {:ok, ref} = I2C.open("i2c-1")
{:ok, #Reference<0.1994877202.537788433.199599>}

# By default, all 8 GPIOs are set to inputs. Set the 4 high bits to outputs
# so that we can toggle the LEDs. (Write 0x0f to register 0x00)
iex> I2C.write(ref, 0x20, <<0x00, 0x0f>>)
:ok

# Turn on the LED attached to bit 4 on the expander. (Write 0x10 to register
# 0x09)
iex> I2C.write(ref, 0x20, <<0x09, 0x10>>)
:ok

# Read all 11 of the expander's registers to see that the bit 0 switch is
# the only one on and that the bit 4 LED is on.
iex> I2C.write(ref, 0x20, <<0>>)  # Set the next register to be read to 0
:ok

iex> I2C.read(ref, 0x20, 11)
<<15, 0, 0, 0, 0, 0, 0, 0, 0, 17, 16>>

# The operation of writing one or more bytes to select a register and
# then reading is very common, so a shortcut is to just run the following:
iex> I2C.write_read(ref, 0x20, <<0>>, 11)
<<15, 0, 0, 0, 0, 0, 0, 0, 0, 17, 16>>

# The 17 in register 9 says that bits 0 and bit 4 are high
# We could have just read register 9.

iex> I2C.write_read(ref, 0x20, <<9>>, 1)
{:ok, <<17>>}
```

## FAQ

### How do I debug?

The most common issue is communicating with an I2C for the first time.  For I2C,
first check that an I2C bus is available:

```elixir
iex> Circuits.I2C.device_names
["i2c-1"]
```

If the list is empty, then I2C is either not available, not enabled, or not
configured in the kernel. If you're using Raspbian, run `raspi-config` and check
that I2C is enabled in the advanced options. If you're on a BeagleBone, try
running `config-pin` and see the [Universal I/O
project](https://github.com/cdsteinkuehler/beaglebone-universal-io) to enable
the I2C pins. On other ARM boards, double check that I2C is enabled in the
kernel and that the device tree configures it.

Once an I2C bus is available, try detecting devices on it:

```elixir
iex> Circuits.I2C.detect_devices("i2c-1")
[4]
```

The return value here is a list of device addresses that were detected. It is
still possible that the device will work even if it does not detect, but you
probably want to check wires at this point. If you have a logic analyzer, use it
to verify that I2C transactions are being initiated on the bus.

### Where can I get help?

The hardest part is communicating with a device for the first time. The issue is
usually unrelated to `Circuits.I2C`. If you expand your searches to include
Python and C forums, you'll frequently find the answer.

If that fails, try posting a question to the [Elixir
Forum](https://elixirforum.com/). Tag the question with `Nerves` and it will
have a good chance of getting to the right people. Feel free to do this even if
you're not using Nerves.

### Can I develop code that uses Circuits.I2C on my laptop?

You'll need to fake out the hardware. Code to do this depends on what your
hardware actually does, but here's one example:

* http://www.cultivatehq.com/posts/compiling-and-testing-elixir-nerves-on-your-host-machine/

Please share other examples if you have them.

### Will it run on Arduino?

No. This only runs on Linux-based boards. If you're interested in controlling an
Arduino from a computer that can run Elixir, check out
[nerves_uart](https://hex.pm/packages/nerves_uart) for communicating via the
Arduino's serial connection or
[firmata](https://github.com/mobileoverlord/firmata) for communication using the
Arduino's Firmata protocol.

## License

Code from the library is licensed under the Apache License, Version 2.0.
