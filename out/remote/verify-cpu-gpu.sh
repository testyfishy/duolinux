#!/bin/sh
# Install Turnip and verify the CPU/GPU idle-power items from the review.
set -u

echo "=== Turnip + tools"
DEBIAN_FRONTEND=noninteractive apt-get install -y mesa-vulkan-drivers vulkan-tools >/tmp/vk-apt.log 2>&1
echo "apt exit=$?"
command -v vulkaninfo

echo "=== Vulkan devices"
vulkaninfo --summary 2>/dev/null | grep -iE "deviceName|driverName|driverInfo|deviceType|apiVersion" | head -12

echo "=== kernel command line"
cat /proc/cmdline

echo "=== clock/power-domain handoff"
dmesg 2>/dev/null | grep -iE "sync_state|deferred probe" | head -8 || echo "no sync_state/deferred messages"
ls /sys/kernel/debug/devices_deferred 2>/dev/null && cat /sys/kernel/debug/devices_deferred 2>/dev/null | head -5

echo "=== EAS / energy model"
cat /proc/sys/kernel/sched_energy_aware 2>/dev/null || echo "sched_energy_aware file absent (EAS off)"
mount -t debugfs none /sys/kernel/debug 2>/dev/null
ls /sys/kernel/debug/energy_model/ 2>/dev/null | head -10 || echo "no energy_model in debugfs"
for c in 0 4; do
    echo "cpu$c capacity: $(cat /sys/devices/system/cpu/cpu$c/cpu_capacity 2>/dev/null)"
done
for c in 0 4; do
    echo "cpu$c dynamic-power-coefficient: $(cat /sys/firmware/devicetree/base/cpus/cpu@$c/dynamic-power-coefficient 2>/dev/null | od -An -tx1 | head -1)"
done

echo "=== cpuidle"
echo "governor: $(cat /sys/devices/system/cpu/cpuidle/current_governor 2>/dev/null)"
for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do
    echo "cpu0 $(cat $s/name): usage=$(cat $s/usage) time_us=$(cat $s/time)"
done
echo "--- power domains"
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary 2>/dev/null | head -12 || echo "no pm_genpd debugfs"

echo "=== thermal cooling devices"
for c in /sys/class/thermal/cooling_device*; do echo "$(cat $c/type) cur=$(cat $c/cur_state) max=$(cat $c/max_state)"; done | head -10
grep -h . /sys/class/thermal/thermal_zone*/policy 2>/dev/null | sort | uniq -c

echo "=== GPU idle state"
cat /sys/class/devfreq/5900000.gpu/trans_stat 2>/dev/null | head -12
cat /sys/devices/platform/soc@0/5900000.gpu/power/runtime_status 2>/dev/null \
  || find /sys/devices -maxdepth 5 -name "5900000.gpu" -path "*platform*" 2>/dev/null | head -2

echo "=== interconnect"
cat /sys/kernel/debug/interconnect/interconnect_summary 2>/dev/null | head -12 || echo "no interconnect summary"

echo "=== power draw now"
for d in /sys/class/power_supply/*/; do
    echo "$(basename $d): status=$(cat $d/status 2>/dev/null) current_now=$(cat $d/current_now 2>/dev/null) voltage_now=$(cat $d/voltage_now 2>/dev/null) power_now=$(cat $d/power_now 2>/dev/null)"
done | head -6
