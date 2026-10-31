#!/bin/sh
# Evidence pack for CPU/GPU driver and performance review.
set -u

echo "=== kernel / board"
uname -a
cat /proc/device-tree/model 2>/dev/null; echo

echo "=== cpu topology"
grep -E "^(processor|BogoMIPS|Features|CPU implementer|CPU architecture|CPU variant|CPU part)" /proc/cpuinfo | head -40

echo "=== cpufreq policies"
for p in /sys/devices/system/cpu/cpufreq/policy*; do
    echo "$(basename $p): cpus=$(cat $p/related_cpus) driver=$(cat $p/scaling_driver) gov=$(cat $p/scaling_governor)"
    echo "   min=$(cat $p/scaling_min_freq) max=$(cat $p/scaling_max_freq) cur=$(cat $p/scaling_cur_freq)"
    echo "   freqs=$(cat $p/scaling_available_frequencies 2>/dev/null)"
done

echo "=== cpr / nvmem / cpufreq drivers bound"
ls /sys/devices/platform/soc/ 2>/dev/null | grep -iE "cpr|nvmem|cpufreq|opp|devfreq" | head -10
ls /sys/bus/nvmem/devices 2>/dev/null
ls /sys/bus/platform/drivers/ 2>/dev/null | grep -iE "cpufreq|cpr" | head -5

echo "=== gpu / display dmesg"
dmesg 2>/dev/null | grep -iE "msm|adreno|a610|gpu|dpu|dsi|panel" | head -25

echo "=== devfreq devices"
for d in /sys/class/devfreq/*; do
    echo "$(basename $d): governor=$(cat $d/governor 2>/dev/null) cur=$(cat $d/cur_freq 2>/dev/null)"
    echo "   avail=$(cat $d/available_frequencies 2>/dev/null | head -c 300)"
done

echo "=== mesa / vulkan packages"
dpkg -l 2>/dev/null | grep -E "^ii  (mesa|libgl|libegl|libvulkan|vulkan)" | awk '{print $2, $3}' | head -15

echo "=== GL renderer"
command -v glxinfo >/dev/null && glxinfo -B 2>/dev/null | head -14 || echo "glxinfo not installed"
command -v eglinfo >/dev/null && eglinfo 2>/dev/null | grep -iE "renderer|vendor|version" | head -6 || echo "eglinfo not installed"
command -v vulkaninfo >/dev/null && vulkaninfo --summary 2>/dev/null | head -12 || echo "vulkaninfo not installed"

echo "=== gpu firmware"
ls /lib/firmware/qcom/ 2>/dev/null | head -15
ls -l /lib/firmware/qcom/a610* /lib/firmware/qcom/sm61* 2>/dev/null | head -10

echo "=== kernel config (graphics/cpu)"
zcat /proc/config.gz 2>/dev/null | grep -E "CONFIG_(DRM_MSM|QCOM_|ARM_QCOM|DEVFREQ|THERMAL|ARM_SMMU|ENERGY_MODEL|CPU_FREQ|CPU_IDLE|SCHED_MC|SCHED_CLUSTER)" | head -45

echo "=== thermal zones"
for t in /sys/class/thermal/thermal_zone*; do
    echo "$(cat $t/type 2>/dev/null): $(cat $t/temp 2>/dev/null)"
done | head -12

echo "=== governor/tuning visible in sysfs"
ls /sys/devices/system/cpu/cpu0/cpuidle/ 2>/dev/null
cat /sys/devices/system/cpu/cpu0/cpuidle/state*/name 2>/dev/null
