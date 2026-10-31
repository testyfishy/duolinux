#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "uinput.h"

static uint32_t current_mods = 0;

static void
emit(int fd, uint16_t type, uint16_t code, int32_t value)
{
    struct input_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = type;
    ev.code = code;
    ev.value = value;
    if (write(fd, &ev, sizeof(ev)) < 0)
        fprintf(stderr, "wvkbd: uinput write failed: %s\n", strerror(errno));
}

static void
sync_ev(int fd)
{
    emit(fd, EV_SYN, SYN_REPORT, 0);
}

int
uinput_open(void)
{
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0)
        fd = open("/dev/input/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        fprintf(stderr, "wvkbd: cannot open uinput: %s\n", strerror(errno));
        return -1;
    }

    if (ioctl(fd, UI_SET_EVBIT, EV_KEY) < 0 ||
        ioctl(fd, UI_SET_EVBIT, EV_SYN) < 0) {
        fprintf(stderr, "wvkbd: uinput setup failed: %s\n", strerror(errno));
        close(fd);
        return -1;
    }

    /* Every key the kernel knows about, so no layout can fall outside the set. */
    for (int code = 1; code <= KEY_MAX; code++)
        ioctl(fd, UI_SET_KEYBIT, code);

    struct uinput_setup setup;
    memset(&setup, 0, sizeof(setup));
    snprintf(setup.name, UINPUT_MAX_NAME_SIZE, "duo-on-screen keyboard");
    setup.id.bustype = BUS_USB;
    setup.id.vendor = 0x1209;
    setup.id.product = 0x0001;
    setup.id.version = 1;

    if (ioctl(fd, UI_DEV_SETUP, &setup) < 0 ||
        ioctl(fd, UI_DEV_CREATE) < 0) {
        fprintf(stderr, "wvkbd: cannot create uinput device: %s\n",
                strerror(errno));
        close(fd);
        return -1;
    }

    /* Give udev a moment to publish the device before the first keystroke. */
    usleep(250 * 1000);
    current_mods = 0;
    return fd;
}

void
uinput_key(int fd, uint32_t code, int pressed)
{
    if (fd < 0)
        return;
    emit(fd, EV_KEY, (uint16_t)code, pressed ? 1 : 0);
    sync_ev(fd);
}

static void
set_key(int fd, uint32_t code, int down)
{
    emit(fd, EV_KEY, (uint16_t)code, down ? 1 : 0);
}

void
uinput_mods(int fd, uint32_t mods)
{
    static const struct {
        uint32_t bit;
        uint32_t key;
    } mapping[] = {
        {UINPUT_MOD_SHIFT, KEY_LEFTSHIFT},
        {UINPUT_MOD_CTRL, KEY_LEFTCTRL},
        {UINPUT_MOD_ALT, KEY_LEFTALT},
        {UINPUT_MOD_SUPER, KEY_LEFTMETA},
        {UINPUT_MOD_ALTGR, KEY_RIGHTALT},
    };

    if (fd < 0)
        return;

    for (size_t i = 0; i < sizeof(mapping) / sizeof(mapping[0]); i++) {
        int was = (current_mods & mapping[i].bit) != 0;
        int now = (mods & mapping[i].bit) != 0;
        if (was != now)
            set_key(fd, mapping[i].key, now);
    }

    /* Caps lock is a toggle in the kernel, so one tap per state change keeps
     * wvkbd's latching state and the kernel's modifier state in step. */
    if (((current_mods ^ mods) & UINPUT_MOD_CAPS) != 0) {
        set_key(fd, KEY_CAPSLOCK, 1);
        set_key(fd, KEY_CAPSLOCK, 0);
    }

    current_mods = mods & ~UINPUT_MOD_CAPS;
    if (mods & UINPUT_MOD_CAPS)
        current_mods |= UINPUT_MOD_CAPS;
    sync_ev(fd);
}

void
uinput_type_codepoint(int fd, uint32_t codepoint)
{
    if (fd < 0)
        return;

    char hex[16];
    int len = snprintf(hex, sizeof(hex), "%x", codepoint);

    /* Unmodified typing: release anything currently held. */
    uinput_mods(fd, 0);

    set_key(fd, KEY_LEFTCTRL, 1);
    set_key(fd, KEY_LEFTSHIFT, 1);
    set_key(fd, KEY_U, 1);
    set_key(fd, KEY_U, 0);
    set_key(fd, KEY_LEFTSHIFT, 0);
    set_key(fd, KEY_LEFTCTRL, 0);
    sync_ev(fd);

    static const uint32_t digits[] = {KEY_0, KEY_1, KEY_2, KEY_3, KEY_4,
                                      KEY_5, KEY_6, KEY_7, KEY_8, KEY_9};
    for (int i = 0; i < len; i++) {
        char c = hex[i];
        uint32_t key;
        if (c >= '0' && c <= '9')
            key = digits[c - '0'];
        else if (c >= 'a' && c <= 'f')
            key = KEY_A + (c - 'a');
        else
            continue;
        set_key(fd, key, 1);
        set_key(fd, key, 0);
        sync_ev(fd);
    }

    set_key(fd, KEY_ENTER, 1);
    set_key(fd, KEY_ENTER, 0);
    sync_ev(fd);
}

void
uinput_close(int fd)
{
    if (fd < 0)
        return;
    ioctl(fd, UI_DEV_DESTROY);
    close(fd);
}
