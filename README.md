<!--
  SPDX-License-Identifier: CC-BY-4.0
  SPDX-FileCopyrightText: 2014 Frank Hunleth
-->

# Circuits.I2C

[![Hex version](https://img.shields.io/hexpm/v/circuits_i2c.svg "Hex version")](https://hex.pm/packages/circuits_i2c)
[![API docs](https://img.shields.io/hexpm/v/circuits_i2c.svg?label=hexdocs "API docs")](https://hexdocs.pm/circuits_i2c/Circuits.I2C.html)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/elixir-circuits/circuits_i2c/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/elixir-circuits/circuits_i2c/tree/main)
[![REUSE status](https://api.reuse.software/badge/github.com/elixir-circuits/circuits_i2c)](https://api.reuse.software/info/github.com/elixir-circuits/circuits_i2c)

`Circuits.I2C` lets you communicate with hardware devices using the I2C protocol.

*This is the v2.0 branch. Circuits.I2C v1.x is still maintained in the [maint-v1.x branch](https://github.com/elixir-circuits/circuits_i2c/tree/maint-v1.x).*

`Circuits.I2C` v2.0  is an almost backwards compatible update to `Circuits.I2C`
v1.x. Here's what's new:

* Linux or Nerves are no longer required. In fact, the NIF supporting them won't
  be compiled if you don't want it.
* Develop using simulated I2C devices with
  [CircuitsSim](https://github.com/elixir-circuits/circuits_sim)
* Use USB->I2C adapters for development on your laptop (Coming soon)

If you've used `Circuits.I2C` v1.x, nearly all of your code will be the same. If
you're a library author, we'd appreciate if you could try this out and update
your `:circuits_i2c` dependency to allow v2.0. Details can be found in our
[porting guide](PORTING.md).

## Getting started on Nerves and Linux

By default, `Circuits.I2C` supports the Linux-based I2C driver interface so the
following instructions assume a Linux-based system like Nerves, Raspberry Pi OS,
embedded Linux or even desktop Linux if I2C lines are exposed. If you want to
use `Circuits.I2C` on a different platform and support is available, generally
the only difference is to change the "open" call. The rest is the same.

First off, add `circuits_i2c` to your `mix.exs`'s dependency list like any other
Elixir library:

```elixir
def deps do
  [{:circuits_i2c, "~> 2.0"}]
end
```

`Circuits.I2C` doesn't load device drivers, so you may need to load them
beforehand. If you are using Nerves on a supported platform, this is enabled for
you already. If using Raspberry Pi OS, the [Adafruit Raspberry Pi I2C
instructions](https://learn.adafruit.com/adafruits-raspberry-pi-lesson-4-gpio-setup/configuring-i2c)
may be helpful.

Internally, it uses the [Linux "i2c-dev"
interface](https://elixir.bootlin.com/linux/latest/source/Documentation/i2c/dev-interface)
so that it does not require board-dependent code.

## Getting started without hardware

If you don't have any real I2C devices, it's possible to work with simulated
devices. See the [CircuitsSim](https://github.com/elixir-circuits/circuits_sim)
project for details.

## I2C background

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
{:ok, #Reference<...>}

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
{:ok, <<15, 0, 0, 0, 0, 0, 0, 0, 0, 17, 16>>}

# The operation of writing one or more bytes to select a register and
# then reading is very common, so a shortcut is to just run the following:
iex> I2C.write_read(ref, 0x20, <<0>>, 11)
{:ok, <<15, 0, 0, 0, 0, 0, 0, 0, 0, 17, 16>>}

# The 17 in register 9 says that bits 0 and bit 4 are high
# We could have just read register 9.

iex> I2C.write_read(ref, 0x20, <<9>>, 1)
{:ok, <<17>>}
```

## Creating a new backend

`Circuits.I2C` supports alternative backends to support non-Linux hardware,
testing, and simulation. A backend can support communication on more than one
I2C bus.

To create a new backend, you need to implement the `Circuits.I2C.Backend`
behaviour. `Circuits.I2C` calls the `bus_names/1` callback to discover what I2C
buses are available and then it calls the `open/2` callback to use the I2C bus.

## FAQ

### How do I debug?

The most common issue is communicating with an I2C for the first time.  For I2C,
first check that an I2C bus is available:

```elixir
iex> Circuits.I2C.bus_names
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
iex> Circuits.I2C.detect_devices()
Circuits.I2C.detect_devices
Devices on I2C bus "i2c-1":
 * 64  (0x40)
 * 112 (0x70)

2 devices detected on 1 I2C buses
```

The return value here is a list of device addresses that were detected. It is
still possible that the device will work even if it does not detect, but you
probably want to check wires at this point. If you have a logic analyzer, use it
to verify that I2C transactions are being initiated on the bus.

### I2C seems slow. What could be wrong?

I2C buses are usually run at 100 kbit/s or 400 kbit/s. Many devices support
higher speeds. The tradeoff is that higher speeds are sometimes don't work as
well especially if you're using jumper cables to connect parts together. The
Raspberry Pi runs the I2C bus at a low speed - probably for this reason.

Other things to check:

* Can you reduce the reads and writes? I2C devices let you read or write many
  bytes at the same time. Each transaction has overhead so minimizing
  transaction helps.
* Can you reduce the total number of bytes in each transaction? For example, do
  you need to read a particular register? Is there a mode that the device can be
  put it so that it only returns useful data?
* Can a write and read be combined? The `Circuits.I2C.write_read` function is
  more efficient than a separate write followed by a read.
* Does the device support a queue mode? Some devices have internal queues that
  allow the host to copy out more than one sample each time.

### Where can I get help?

The hardest part is communicating with a device for the first time. The issue is
usually unrelated to `Circuits.I2C`. If you expand your searches to include
Python and C forums, you'll frequently find the answer.

If that fails, try posting a question to the [Elixir
Forum](https://elixirforum.com/). Tag the question with `Nerves` and it will
have a good chance of getting to the right people. Feel free to do this even if
you're not using Nerves.

### Can I develop code that uses Circuits.I2C on my laptop?

You have a few options:

1. Connect your I2C devices to a USB->I2C adapter like a [Adafruit FT232H
   Breakout](https://www.adafruit.com/product/2264)
2. Use the CircuitsSim backend
3. Create a custom backend and use it to mock interactions with the Circuits.I2C
   API

### Will it run on Arduino?

No. This only runs on Linux-based boards. If you're interested in controlling an
Arduino from a computer that can run Elixir, check out
[circuits_uart](https://hex.pm/packages/circuits_uart) for communicating via the
Arduino's serial connection or
[firmata](https://github.com/mobileoverlord/firmata) for communication using the
Arduino's Firmata protocol.

## License

All original source code in this project is licensed under Apache-2.0.

Additionally, this project follows the [REUSE recommendations](https://reuse.software)
and labels so that licensing and copyright are clear at the file level.

Exceptions to Apache-2.0 licensing are:

* Linux header files included for convenience under GPL-2.0-or-later WITH
  Linux-syscall-note
* Configuration and data files are licensed under CC0-1.0
* Documentation files are CC-BY-4.0
* Erlang Embedded board images are Solderpad Hardware License v0.51.
