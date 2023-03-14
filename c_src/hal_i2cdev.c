/*
 *  Copyright 2018 Frank Hunleth, Mark Sebald
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * I2C NIF implementation.
 */

#include "i2c_nif.h"
#include "linux/i2c-dev.h"

#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

ERL_NIF_TERM hal_info(ErlNifEnv *env)
{
    ERL_NIF_TERM info = enif_make_new_map(env);
    enif_make_map_put(env, info, enif_make_atom(env, "name"), enif_make_atom(env, "i2cdev"), &info);
    return info;
}

int hal_i2c_open(const unsigned char *device, size_t device_len)
{
    char devpath[32];
    snprintf(devpath, sizeof(devpath), "/dev/%.*s", (int) device_len, device);
    return open(devpath, O_RDWR);
}

void hal_i2c_close(int fd)
{
    close(fd);
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
        rc = ioctl(fd, I2C_RDWR, data);
    } while (rc < 0 && retries-- > 0);

    return rc;
}

int hal_i2c_transfer(int fd,
                     unsigned int addr,
                     const uint8_t *to_write, size_t to_write_len,
                     uint8_t *to_read, size_t to_read_len, int retries)
{
    struct i2c_rdwr_ioctl_data data;
    struct i2c_msg msgs[2];

    msgs[0].addr = addr;
    msgs[0].flags = 0;
    msgs[0].len = to_write_len;
    msgs[0].buf = (uint8_t *) to_write;

    msgs[1].addr = addr;
    msgs[1].flags = I2C_M_RD;
    msgs[1].len = to_read_len;
    msgs[1].buf = (uint8_t *) to_read;

    if (to_write_len != 0)
        data.msgs = &msgs[0];
    else
        data.msgs = &msgs[1];

    data.nmsgs = (to_write_len != 0 && to_read_len != 0) ? 2 : 1;

    return retry_rdwr_ioctl(fd, &data, retries);
}

