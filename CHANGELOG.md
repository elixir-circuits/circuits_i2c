# Changelog

## v0.3.4

This release should work on Erlang/OTP 20 - 22 and Elixir 1.4 and
newer. The CI process has been updated to verify more versions now.

* Bug fixes
  * Improve error message when bus doesn't exist

## v0.3.3

* Bug fixes
  * Fix binary handling in NIF. This fixes segfaults and other errors when run
    on Raspbian.

## v0.3.2

* Bug fixes
  * Fix file handle leak when I2C bus references were garbage collected.

## v0.3.1

* Bug fixes
  * Build C source under the `_build` directory so that changing targets
    properly rebuilds the C code as well as the Elixir code.

## v0.3.0

Print detected devices instead of an error.

## v0.2.0

Minor text updates.

Remove i2c_ from i2c_address and i2c_bus.

## v0.1.0

Initial release to hex.
