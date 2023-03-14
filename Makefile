# Makefile for building the NIF
#
# Makefile targets:
#
# all/install   build and install the NIF
# clean         clean build products and intermediates
#
# Variables to override:
#
# MIX_APP_PATH  path to the build directory
# CIRCUITS_BACKEND Backend to build - `"i2c_dev"` or `"i2c_dev_test"` will build a NIF
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# ERL_CFLAGS	additional compiler flags for files using Erlang header files
# ERL_EI_INCLUDE_DIR include path to ei.h (Required for crosscompile)
# ERL_EI_LIBDIR path to libei.a (Required for crosscompile)
# LDFLAGS	linker flags for linking all binaries
# ERL_LDFLAGS	additional linker flags for projects referencing Erlang libraries

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

NIF = $(PREFIX)/i2c_nif.so

SRC = c_src/i2c_nif.c
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -pedantic

# Check that we're on a supported build platform
ifeq ($(CROSSCOMPILE),)
	# Not crosscompiling, so check that we're on Linux for whether to compile the NIF.
	ifeq ($(shell uname -s),Linux)
		CFLAGS += -fPIC
		LDFLAGS += -fPIC -shared
	else
		CFLAGS += -Ic_src/compat
		LDFLAGS += -undefined dynamic_lookup -dynamiclib
		ifeq ($(CIRCUITS_BACKEND),i2c_dev)
			$(error Circuits.I2C Linux i2c_dev backend not supported on non-Linux platforms. Review circuits_i2c backend configuration or report an issue if improperly detected.)
		endif
	endif
else
	# Crosscompiled build
	LDFLAGS += -fPIC -shared
	CFLAGS += -fPIC
endif

ifeq ($(CIRCUITS_BACKEND),i2c_dev)
# Build the Linux backend. This is default and works with Nerves
else
ifeq ($(CIRCUITS_BACKEND),i2c_dev_test)
# Build the Linux backend, but stub out the real I2C calls
CFLAGS += -DTEST_BACKEND
else
# Don't build NIF at all
NIF =
endif
endif

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei

HEADERS =$(wildcard c_src/*.h)
OBJ = $(SRC:c_src/%.c=$(BUILD)/%.o)

calling_from_make:
	mix compile

all: install

install: $(PREFIX) $(BUILD) $(NIF)

$(OBJ): $(HEADERS) Makefile

$(BUILD)/%.o: c_src/%.c
	@echo " CC $(notdir $@)"
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(NIF): $(OBJ)
	@echo " LD $(notdir $@)"
	$(CC) -o $@ $(ERL_LDFLAGS) $(LDFLAGS) $^

$(PREFIX) $(BUILD):
	mkdir -p $@

clean:
	$(RM) $(NIF) $(OBJ)

.PHONY: all clean calling_from_make install

# Don't echo commands unless the caller exports "V=1"
${V}.SILENT:
