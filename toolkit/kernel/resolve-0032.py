import io, re, sys

p = "/home/aran/rocknix-nf/port/repo/drivers/power/supply/bq256xx_charger.c"
src = io.open(p, encoding="utf-8").read()

start = src.index("<<<<<<< HEAD")
end = src.index(">>>>>>> f2232bf")
end = src.index("\n", end) + 1

resolved = """\t/* Register after the power supplies so devm runs it first. */
\tret = devm_add_action_or_reset(dev, bq256xx_charger_reset, bq);
\tif (ret)
\t\treturn ret;

\tif (!IS_ERR_OR_NULL(bq->usb2_phy))
\t\tusb_register_notifier(bq->usb2_phy, &bq->usb_nb);

\tif (!IS_ERR_OR_NULL(bq->usb3_phy))
\t\tusb_register_notifier(bq->usb3_phy, &bq->usb_nb);

\tINIT_DELAYED_WORK(&bq->jeita_work, bq256xx_jeita_work);
\tbq->jeita_band = BQ256XX_JEITA_BAND_UNKNOWN;
\tret = devm_add_action_or_reset(dev, bq256xx_jeita_cleanup, bq);
\tif (ret)
\t\treturn ret;
"""

src = src[:start] + resolved + src[end:]
assert "<<<<<<<" not in src and ">>>>>>>" not in src
io.open(p, "w", encoding="utf-8", newline="\n").write(src)
print("resolved 0032")
