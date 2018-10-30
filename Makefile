# Variables to override
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# ERL_CFLAGS	additional compiler flags for files using Erlang header files
# ERL_EI_INCLUDE_DIR include path to ei.h (Required for crosscompile)
# ERL_EI_LIBDIR path to libei.a (Required for crosscompile)
# LDFLAGS	linker flags for linking all binaries
# ERL_LDFLAGS	additional linker flags for projects referencing Erlang libraries

NIF=priv/i2c_nif.so

# Check that we're on a supported build platform
ifeq ($(CROSSCOMPILE),)
    # Not crosscompiling, so check that we're on Linux.
    ifneq ($(shell uname -s),Linux)
        $(warning Elixir Circuits only works on Nerves and Linux platforms.)
        $(warning A stub NIF will be compiled for test purposes.)
	HAL = src/hal_stub.c
        LDFLAGS += -undefined dynamic_lookup -dynamiclib
    else
        LDFLAGS += -fPIC -shared
    endif
else
# Crosscompiled build
LDFLAGS += -fPIC -shared
endif
HAL ?= src/hal_i2cdev.c

CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -pedantic

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR)

SRC =src/i2c_nif.c $(HAL)
HEADERS =$(wildcard src/*.h)

calling_from_make:
	mix compile

all: priv $(NIF)

priv:
	mkdir -p priv

$(NIF): $(HEADERS)

$(NIF): $(SRC)
	$(CC) -o $@ $(SRC) $(ERL_CFLAGS) $(CFLAGS) $(ERL_LDFLAGS) $(LDFLAGS)

clean:
	$(RM) $(NIF)

.PHONY: all clean calling_from_make
