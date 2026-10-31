import io, sys

p = "/home/user/rocknix-nf/port/repo/drivers/power/supply/bq256xx_charger.c"
src = io.open(p, encoding="utf-8").read()

# Current (conflict-resolution) order: reset action, notifiers, JEITA init.
# Wanted: reset action first (stable's comment: devm runs it first), then JEITA
# init - the position the patch used on 7.2.0, before the IRQ handler that does
# mod_delayed_work(&bq->jeita_work) - then the USB notifiers, so a failing JEITA
# init cannot leave notifiers registered against freed memory.
old = """\tif (!IS_ERR_OR_NULL(bq->usb3_phy))
\t\tusb_register_notifier(bq->usb3_phy, &bq->usb_nb);

\tINIT_DELAYED_WORK(&bq->jeita_work, bq256xx_jeita_work);
\tbq->jeita_band = BQ256XX_JEITA_BAND_UNKNOWN;
\tret = devm_add_action_or_reset(dev, bq256xx_jeita_cleanup, bq);
\tif (ret)
\t\treturn ret;
"""

new = """\tINIT_DELAYED_WORK(&bq->jeita_work, bq256xx_jeita_work);
\tbq->jeita_band = BQ256XX_JEITA_BAND_UNKNOWN;
\tret = devm_add_action_or_reset(dev, bq256xx_jeita_cleanup, bq);
\tif (ret)
\t\treturn ret;

\tif (!IS_ERR_OR_NULL(bq->usb2_phy))
\t\tusb_register_notifier(bq->usb2_phy, &bq->usb_nb);

\tif (!IS_ERR_OR_NULL(bq->usb3_phy))
\t\tusb_register_notifier(bq->usb3_phy, &bq->usb_nb);
"""

if old not in src:
    sys.exit("pattern not found")

# drop the original usb2/usb3 registration block that preceded it
old_full = """\tif (!IS_ERR_OR_NULL(bq->usb2_phy))
\t\tusb_register_notifier(bq->usb2_phy, &bq->usb_nb);

""" + old

if old_full not in src:
    sys.exit("full block not found")

src = src.replace(old_full, new, 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(src)
print("reordered: JEITA init now precedes the USB notifier registration")
