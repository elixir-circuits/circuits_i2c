#include "erl_nif.h"


static ERL_NIF_TERM hello_i2c(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    return enif_make_string(env, "Hello from i2c nif", ERL_NIF_LATIN1);
}


static ErlNifFunc nif_funcs[] =
{
    {"hello", 0, hello_i2c, 0},
};


ERL_NIF_INIT(Elixir.I2C.Nif, nif_funcs, NULL, NULL, NULL, NULL)



