import Config

# Simulate a couple I2C buses with devices on each
config :circuits_sim,
  config: %{
    "i2c-0" => %{0x20 => CircuitsSim.Device.MCP23008, 0x50 => CircuitsSim.Device.AT24C02},
    "i2c-1" => %{
      0x10 => CircuitsSim.Device.ADS7138,
      0x20 => CircuitsSim.Device.MCP23008,
      0x21 => CircuitsSim.Device.MCP23008
    }
  }

# Tell Circuits.I2C to default to simulated I2C buses
config :circuits_i2c, default_backend: CircuitsSim.Backend
