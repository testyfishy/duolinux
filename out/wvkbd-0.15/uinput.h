#ifndef WVKBD_UINPUT_H
#define WVKBD_UINPUT_H

#include <stdint.h>

/*
 * Kernel-level key injection.
 *
 * The wlroots virtual-keyboard protocol does not exist in KWin, so on KDE
 * Plasma there is no way for a wlroots-style keyboard to type at all. uinput
 * sidesteps the compositor entirely: the kernel creates a real keyboard device,
 * every compositor delivers its events, and applications cannot tell the
 * difference from a USB keyboard.
 */

/* Returns a file descriptor, or -1 if uinput is unavailable. */
int uinput_open(void);

/* Press or release one key by Linux input code (not XKB keycode). */
void uinput_key(int fd, uint32_t code, int pressed);

/* Synchronise the current modifier bit mask with the real modifier keys. */
void uinput_mods(int fd, uint32_t mods);

/* Type an arbitrary unicode code point as a Ctrl+Shift+U sequence. */
void uinput_type_codepoint(int fd, uint32_t codepoint);

void uinput_close(int fd);

/* Modifier bits, matching keyboard.h's enum key_modifier_type. */
#define UINPUT_MOD_SHIFT 1
#define UINPUT_MOD_CAPS 2
#define UINPUT_MOD_CTRL 4
#define UINPUT_MOD_ALT 8
#define UINPUT_MOD_SUPER 64
#define UINPUT_MOD_ALTGR 128

#endif
