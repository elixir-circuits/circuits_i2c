# CircuitsSim

Interact with simulated I2C devices

```shell
$ iex -S mix

Interactive Elixir (1.14.3) - press Ctrl+C to exit (type h() ENTER for help)
iex> Circuits.I2C.detect_devices
Devices on I2C bus "i2c-0":
 * 32  (0x20)
 * 80  (0x50)

Devices on I2C bus "i2c-1":
 * 32  (0x20)
 * 33  (0x21)

4 devices detected on 2 I2C buses
iex>
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `circuits_sim` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:circuits_sim, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/circuits_sim>.
