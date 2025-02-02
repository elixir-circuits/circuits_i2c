// SPDX-FileCopyrightText: 2018 Frank Hunleth, Mark Sebald
//
// SPDX-License-Identifier: Apache-2.0

#include <erl_nif.h>

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "linux/i2c-dev.h"

#ifdef TEST_BACKEND
#define do_open test_open
#define do_ioctl test_ioctl
#define do_close test_close

int test_open(const char *path, int flags)
{
    if (strcmp(path, "/dev/i2c-test-0") == 0)
        return 0x10;
    else if (strcmp(path, "/dev/i2c-test-1") == 0)
        return 0x20;
    else if (strcmp(path, "/dev/i2c-flaky") == 0)
        return 0x30;
    else
        return -1;
}
int test_close(int fd)
{
    if (fd == 0x10 || fd == 0x20 || fd == 0x30)
        return 0;
    else
        return -1;
}
int test_ioctl(int fd, unsigned long request, ...)
{
    static int flaky = 0;
    va_list ap;

    // The flaky I2C bus (0x30) works only on a retry. Reading anything besides 0x30 resets the counter.
    if (fd != 0x30)
        flaky = 0;

    if (fd != 0x10 && fd != 0x20 && fd != 0x30)
        return -1;

    if (request == I2C_FUNCS) {
        va_start(ap, request);
        unsigned long *funcs = va_arg(ap, unsigned long *);
        va_end(ap);
        *funcs = 0;
        return 0;
    } else if (request == I2C_RDWR) {
        va_start(ap, request);
        struct i2c_rdwr_ioctl_data *data = va_arg(ap, struct i2c_rdwr_ioctl_data *);
        va_end(ap);
        if (fd == 0x30) {
            // Flake out if first read or write
            if (flaky == 0) {
                flaky++;
                return -1;
            }
            flaky = 0;
        }

        for (unsigned int i = 0; i < data->nmsgs; i++) {
            struct i2c_msg *msg = &data->msgs[i];
            if (msg->addr != fd)
                return -1;

            if (msg->flags & I2C_M_RD) {
                for (int j = 0; j < msg->len; j++) {
                    msg->buf[j] = msg->addr + j;
                }
            }
        }
        return data->nmsgs;
    } else if (request == I2C_TIMEOUT) {
        // Ignore calls to set the timeout.
        return 0;
    } else {
        // Unknown ioctl
        return -1;
    }
}
#else
#define do_open open
#define do_ioctl ioctl
#define do_close close
#endif

//#define DEBUG

#ifdef DEBUG
#define log_location stderr
//#define LOG_PATH "/tmp/circuits_i2c.log"
#define debug(...) do { enif_fprintf(log_location, __VA_ARGS__); enif_fprintf(log_location, "\r\n"); fflush(log_location); } while(0)
#define error(...) do { debug(__VA_ARGS__); } while (0)
#define start_timing() ErlNifTime __start = enif_monotonic_time(ERL_NIF_USEC)
#define elapsed_microseconds() (enif_monotonic_time(ERL_NIF_USEC) - __start)
#else
#define debug(...)
#define error(...) do { enif_fprintf(stderr, __VA_ARGS__); enif_fprintf(stderr, "\n"); } while(0)
#define start_timing()
#define elapsed_microseconds() 0
#endif

// I2C NIF Resource.
struct I2cNifRes {
    int fd;
};

// I2C NIF Private data
struct I2cNifPriv {
    ErlNifResourceType *i2c_nif_res_type;
};

static ERL_NIF_TERM atom_ok;
static ERL_NIF_TERM atom_error;
static ERL_NIF_TERM atom_nak;
static ERL_NIF_TERM atom_timeout;
static ERL_NIF_TERM atom_retry;

static void i2c_dtor(ErlNifEnv *env, void *obj)
{
    struct I2cNifRes *res = (struct I2cNifRes *) obj;

    debug("i2c_dtor");
    if (res->fd >= 0) {
        do_close(res->fd);
        res->fd = -1;
    }
}

static int i2c_load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info)
{
#ifdef DEBUG
#ifdef LOG_PATH
    log_location = fopen(LOG_PATH, "w");
#endif
#endif
    debug("i2c_load");

    struct I2cNifPriv *priv = enif_alloc(sizeof(struct I2cNifPriv));
    if (!priv) {
        error("Can't allocate i2c priv");
        return 1;
    }

    priv->i2c_nif_res_type = enif_open_resource_type(env, NULL, "i2c_nif_res_type", i2c_dtor, ERL_NIF_RT_CREATE, NULL);
    if (priv->i2c_nif_res_type == NULL) {
        error("open I2C NIF resource type failed");
        return 1;
    }

    atom_ok = enif_make_atom(env, "ok");
    atom_error = enif_make_atom(env, "error");
    atom_nak = enif_make_atom(env, "i2c_nak");
    atom_timeout = enif_make_atom(env, "timeout");
    atom_retry = enif_make_atom(env, "retry");

    *priv_data = priv;
    return 0;
}

static void i2c_unload(ErlNifEnv *env, void *priv_data)
{
    debug("i2c_unload");
    enif_free(priv_data);
}

static ERL_NIF_TERM enif_make_errno_error(ErlNifEnv *env)
{
    ERL_NIF_TERM reason;
    switch (errno) {
#ifdef EREMOTEIO
    case EREMOTEIO:
        // Remote I/O errors are I2C naks
        reason = atom_nak;
        break;
#endif
    case ETIMEDOUT:
        reason = atom_timeout;
        break;

    case EAGAIN:
        reason = atom_retry;
        break;

    case ENOENT:
        reason = enif_make_atom(env, "bus_not_found");
        break;

    case EOPNOTSUPP:
        reason = enif_make_atom(env, "not_supported");
        break;

    case ENXIO:
        // Most likely that the device didn't answer, but check dmesg
        reason = enif_make_atom(env, "enxio");
        break;

    default:
        // These errors aren't that helpful, so if they happen, please report
        // or update this code to provide a better reason.
        reason = enif_make_tuple2(env, enif_make_atom(env, "errno"), enif_make_int(env, errno));
        break;
    }

    return enif_make_tuple2(env, atom_error, reason);
}

static ERL_NIF_TERM funcs_to_flags(ErlNifEnv *env, unsigned long funcs)
{
    // Documentation for the funcs is at https://docs.kernel.org/i2c/functionality.html.
    // We convert them to Circuits.I2C flags since the Circuits.I2C API
    // doesn't use SMBus terminology.

    // Only one flag supported now
    if (funcs & I2C_FUNC_SMBUS_QUICK) {
        return enif_make_list1(env, enif_make_atom(env, "supports_empty_write"));
    } else {
        return enif_make_list(env, 0);
    }
}

static ERL_NIF_TERM i2c_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    ErlNifBinary path;
    int timeout_ms;

    if (!enif_inspect_binary(env, argv[0], &path) ||
            !enif_get_int(env, argv[1], &timeout_ms))
        return enif_make_badarg(env);

    char devpath[32];
    snprintf(devpath, sizeof(devpath), "/dev/%.*s", (int) path.size, path.data);
    int fd = do_open(devpath, O_RDWR);
    if (fd < 0)
        return enif_make_errno_error(env);

    // This next ioctl is also a check that the path passed in is
    // actually an I2C device. If not, it will fail.
    unsigned long funcs;
    if (do_ioctl(fd, I2C_FUNCS, &funcs) < 0) {
        close(fd);
        return enif_make_errno_error(env);
    }

    // Change the I2C timeout
    if (timeout_ms >= 0) {
        int timeout_cs = (timeout_ms + 5) / 10;
        if (timeout_cs == 0)
            timeout_cs = 1;
        if (do_ioctl(fd, I2C_TIMEOUT, timeout_cs) < 0) {
            close(fd);
            return enif_make_errno_error(env);
        }
    }

    struct I2cNifRes *i2c_nif_res = enif_alloc_resource(priv->i2c_nif_res_type, sizeof(struct I2cNifRes));
    i2c_nif_res->fd = fd;
    ERL_NIF_TERM res_term = enif_make_resource(env, i2c_nif_res);

    // Elixir side owns the resource. Safe for NIF side to release it.
    enif_release_resource(i2c_nif_res);

    return enif_make_tuple3(env, atom_ok, res_term, funcs_to_flags(env, funcs));
}

static int retry_rdwr_ioctl(int fd, struct i2c_rdwr_ioctl_data *data, int retries)
{
    int rc;

    // Partial failures aren't supported. For example, if the RDWR has a write
    // message and then a read and the read fails, the whole thing is retried.
    //
    // See https://elixir.bootlin.com/linux/v6.2/source/drivers/i2c/i2c-core-base.c#L2150
    // for some commentary on the limitations of the Linux I2C API.

    do {
        rc = do_ioctl(fd, I2C_RDWR, data);
    } while (rc < 0 && retries-- > 0);

    return rc;
}

static ERL_NIF_TERM i2c_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    struct I2cNifRes *res;
    unsigned int addr;
    unsigned long read_len;
    ERL_NIF_TERM bin_read;
    unsigned char *raw_bin_read;
    int retries;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res) ||
            !enif_get_uint(env, argv[1], &addr) ||
            !enif_get_ulong(env, argv[2], &read_len) ||
            !enif_get_int(env, argv[3], &retries))
        return enif_make_badarg(env);

    raw_bin_read = enif_make_new_binary(env, read_len, &bin_read);

    if (!raw_bin_read)
        return enif_make_tuple2(env, atom_error, enif_make_atom(env, "alloc_failed"));

    struct i2c_rdwr_ioctl_data data;
    struct i2c_msg msgs[1];

    msgs[0].addr = addr;
    msgs[0].flags = I2C_M_RD;
    msgs[0].len = read_len;
    msgs[0].buf = (uint8_t *) raw_bin_read;

    data.msgs = &msgs[0];
    data.nmsgs = 1;

    if (retry_rdwr_ioctl(res->fd, &data, retries) >= 0)
        return enif_make_tuple2(env, atom_ok, bin_read);
    else
        return enif_make_errno_error(env);
}

static ERL_NIF_TERM i2c_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    struct I2cNifRes *res;
    unsigned int addr;
    ErlNifBinary bin_write;
    int retries;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res) ||
            !enif_get_uint(env, argv[1], &addr) ||
            !enif_inspect_iolist_as_binary(env, argv[2], &bin_write) ||
            !enif_get_int(env, argv[3], &retries))
        return enif_make_badarg(env);

    struct i2c_rdwr_ioctl_data data;
    struct i2c_msg msgs[1];

    msgs[0].addr = addr;
    msgs[0].flags = 0;
    msgs[0].len = bin_write.size;
    msgs[0].buf = (uint8_t *) bin_write.data;

    data.msgs = &msgs[0];
    data.nmsgs = 1;

    if (retry_rdwr_ioctl(res->fd, &data, retries) >= 0)
        return atom_ok;
    else
        return enif_make_errno_error(env);
}

static ERL_NIF_TERM i2c_write_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    struct I2cNifRes *res;
    unsigned int addr;
    ErlNifBinary bin_write;
    unsigned long read_len;
    ERL_NIF_TERM bin_read;
    unsigned char *raw_bin_read;
    int retries;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res) ||
            !enif_get_uint(env, argv[1], &addr) ||
            !enif_inspect_iolist_as_binary(env, argv[2], &bin_write) ||
            !enif_get_ulong(env, argv[3], &read_len) ||
            !enif_get_int(env, argv[4], &retries))
        return enif_make_badarg(env);

    raw_bin_read = enif_make_new_binary(env, read_len, &bin_read);

    if (!raw_bin_read)
        return enif_make_tuple2(env, atom_error, enif_make_atom(env, "alloc_failed"));

    struct i2c_rdwr_ioctl_data data;
    struct i2c_msg msgs[2];

    msgs[0].addr = addr;
    msgs[0].flags = 0;
    msgs[0].len = bin_write.size;
    msgs[0].buf = (uint8_t *) bin_write.data;
    msgs[1].addr = addr;
    msgs[1].flags = I2C_M_RD;
    msgs[1].len = read_len;
    msgs[1].buf = (uint8_t *) raw_bin_read;

    data.msgs = &msgs[0];
    data.nmsgs = 2;

    if (retry_rdwr_ioctl(res->fd, &data, retries) >= 0)
        return enif_make_tuple2(env, atom_ok, bin_read);
    else
        return enif_make_errno_error(env);
}

static ERL_NIF_TERM i2c_close(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    struct I2cNifRes *res;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (res->fd >= 0) {
        do_close(res->fd);
        res->fd = -1;
    }

    return atom_ok;
}

static ERL_NIF_TERM i2c_info(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    ERL_NIF_TERM info = enif_make_new_map(env);
#ifdef TEST_BACKEND
    enif_make_map_put(env, info, enif_make_atom(env, "test?"), enif_make_atom(env, "true"), &info);
#endif
    return info;
}

static ErlNifFunc nif_funcs[] =
{
    {"open", 2, i2c_open, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"read", 4, i2c_read, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"write", 4, i2c_write, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"write_read", 5, i2c_write_read, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"close", 1, i2c_close, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"info", 0, i2c_info, 0}
};

ERL_NIF_INIT(Elixir.Circuits.I2C.Nif, nif_funcs, i2c_load, NULL, NULL, i2c_unload)
