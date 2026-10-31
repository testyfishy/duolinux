#!/usr/bin/env python3
"""Patch the wvkbd fork so key output goes through uinput when available."""
import pathlib
import re

root = pathlib.Path(r"C:\Users\HTPC-Aran\Documents\Default Project\duolinux\out\wvkbd-0.15")

# ---------------------------------------------------------------- keyboard.h
kh = root / "keyboard.h"
text = kh.read_text()
if "uinput_fd" not in text:
    text = text.replace(
        "\tstruct zwp_virtual_keyboard_v1 *vkbd;",
        "\tstruct zwp_virtual_keyboard_v1 *vkbd;\n"
        "\tint uinput_fd; /* >= 0 when key output goes through the kernel */",
    )
    kh.write_text(text)
    print("keyboard.h: uinput_fd added")

# ---------------------------------------------------------------- keyboard.c
kc = root / "keyboard.c"
text = kc.read_text()

if '#include "uinput.h"' not in text:
    text = text.replace('#include "keyboard.h"',
                        '#include "keyboard.h"\n#include "uinput.h"', 1)

helpers = '''
/*
 * Key output. uinput is preferred: it works on every compositor, including
 * KWin, which does not implement the wlroots virtual-keyboard protocol.
 */
static void
vk_send(struct kbd *kb, uint32_t code, uint32_t state)
{
    if (kb->uinput_fd >= 0) {
        uinput_key(kb->uinput_fd, code,
                   state == WL_KEYBOARD_KEY_STATE_PRESSED);
    } else if (kb->vkbd) {
        zwp_virtual_keyboard_v1_key(kb->vkbd, 0, code, state);
    }
}

static void
vk_mods(struct kbd *kb, uint32_t mods)
{
    if (kb->uinput_fd >= 0) {
        uinput_mods(kb->uinput_fd, mods);
    } else if (kb->vkbd) {
        zwp_virtual_keyboard_v1_modifiers(kb->vkbd, mods, 0, 0, 0);
    }
}
'''

if "static void\nvk_send" not in text:
    anchor = text.index("void\nkbd_unpress_key")
    text = text[:anchor] + helpers.strip() + "\n\n" + text[anchor:]

# protocol modifiers -> vk_mods(kb, X)
text = re.sub(
    r"zwp_virtual_keyboard_v1_modifiers\(\s*kb->vkbd,\s*([^,]+?),\s*0,\s*0,\s*0\)",
    r"vk_mods(kb, \1)", text)

# protocol key -> vk_send(kb, CODE, STATE)
text = re.sub(
    r"zwp_virtual_keyboard_v1_key\(\s*kb->vkbd,\s*(?:time,\s*)?([^,]+?),\s*(WL_KEYBOARD_KEY_STATE_[A-Z]+)\)",
    r"vk_send(kb, \1, \2)", text)

# compose keys: with uinput there is no temporary keymap, so type the code point
text = text.replace(
    """        create_and_upload_keymap(kb, kb->layout->keymap_name, k->code,
                                 k->code_mod);
        vk_mods(kb, kb->mods);
        vk_send(kb, 127, // COMP key
                                    WL_KEYBOARD_KEY_STATE_PRESSED);""",
    """        if (kb->uinput_fd >= 0) {
            /* typed on release, see kbd_unpress_key */
        } else {
            create_and_upload_keymap(kb, kb->layout->keymap_name, k->code,
                                     k->code_mod);
            vk_mods(kb, kb->mods);
            vk_send(kb, 127, /* COMP key */
                    WL_KEYBOARD_KEY_STATE_PRESSED);
        }""")

kc.write_text(text)
print("keyboard.c: patched")

# ---------------------------------------------------------------- main.c
mc = root / "main.c"
text = mc.read_text()

if "uinput.h" not in text:
    text = text.replace('#include "keyboard.h"',
                        '#include "keyboard.h"\n#include "uinput.h"', 1)

old = """    if (vkbd_mgr == NULL) {
        die("virtual_keyboard_manager not available\\n");
    }
"""
new = """    /* Prefer uinput: KWin does not implement the virtual-keyboard protocol,
     * so on Plasma this is the only way keys can be delivered at all. */
    keyboard.uinput_fd = uinput_open();
    if (keyboard.uinput_fd < 0) {
        fprintf(stderr, "wvkbd: uinput unavailable, falling back to protocol\\n");
    }
    if (vkbd_mgr == NULL && keyboard.uinput_fd < 0) {
        die("no way to send keys (neither uinput nor virtual_keyboard)\\n");
    }
"""
if old in text:
    text = text.replace(old, new)
    print("main.c: uinput init added")
else:
    print("main.c: ANCHOR NOT FOUND")

old2 = """    keyboard.vkbd =
        zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(vkbd_mgr, seat);
    if (keyboard.vkbd == NULL) {
        die("failed to init virtual keyboard_manager\\n");
    }
"""
new2 = """    if (vkbd_mgr != NULL) {
        keyboard.vkbd = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(
            vkbd_mgr, seat);
        if (keyboard.vkbd == NULL) {
            fprintf(stderr, "wvkbd: no virtual keyboard object\\n");
        }
    }
"""
if old2 in text:
    text = text.replace(old2, new2)
    print("main.c: protocol init made conditional")
else:
    print("main.c: second anchor NOT FOUND")

mc.write_text(text)
