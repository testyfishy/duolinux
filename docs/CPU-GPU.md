# CPU and GPU stack

Checked 2026-10-31 on kernel `7.2.0` (ROCKNIX SM6115 tree), Debian 13, Mesa 25.0.7.

## Verdict

Both processors are on the correct upstream drivers. There is no wrong or missing CPU or GPU driver;
the gaps that exist are in the device tree and in subsystems upstream does not support for this part
yet.

## CPU

```
4 x Cortex-A53  (part 0x801)  cpus 0-3   policy0  300 MHz .. 1.8048 GHz
4 x Cortex-A73  (part 0x800)  cpus 4-7   policy4  300 MHz .. 2.016 GHz
driver qcom-cpufreq-hw, governor schedutil, qcom-cpr bound, CONFIG_ENERGY_MODEL=y
cpuidle: WFI + cpu-sleep-0-0 / cpu-sleep-1-0, governor menu (teo available)
cooling devices: cpufreq-cpu0, cpufreq-cpu4, devfreq-5900000.gpu, pwm-fan
```

`qcom-cpufreq-hw` is the SoC's own clock/voltage controller and the correct driver here; `cpufreq-dt`,
`qcom-cpr` and `qcom-cpufreq-nvmem` are built in but not attached to a device, which is normal.
Full OPP tables are exposed for both clusters, so nothing is capped by a speed grade.

Gaps:

- **No energy model.** `/sys/kernel/debug/energy_model` is empty and the device tree has no
  `dynamic-power-coefficient` on the CPU nodes. EAS is on (`sched_energy_aware=1`, capacities 573 vs
  1024) but works from capacity alone. Fixing it means a device-tree patch, so it is a kernel-side
  change, not tuning.
- **No cluster idle state.** Only per-core `WFI` and `cpu-sleep-*` exist, so the L2 cache and cluster
  rails are not powered down at idle. Again a device-tree gap.
- `clk_ignore_unused` is on the kernel command line, and dmesg shows `sync_state() pending due to
  596a000.gmu` and `due to pwm`. Clocks that no driver claimed are therefore never released at boot.
  The flag is in the boot image, not in `/boot` (which is empty and has no extlinux), so removing it
  means rebuilding the boot image and risks the display handoff. Do not remove it blindly: find the
  driver that fails to load first.

## GPU

```
msm DRM + freedreno, Mesa 25.0.7, OpenGL 4.6 core, renderer FD610
devfreq 5900000.gpu: simple_ondemand, 320 / 465 / 600 / 745 / 820 / 900 / 950 MHz
runtime_status: suspended at idle
Vulkan: Turnip Adreno (TM) 610, Mesa 25.0.7 (after installing mesa-vulkan-drivers)
firmware: qcom/sm6125/a610_zap.mbn + qcom/a630_sqe.fw
```

There is no GMU on Adreno 610, so devfreq is the intended design; `simple_ondemand` is what `msm`
expects and needs no change. At idle the device is `suspended` and spends most of its time at
320 MHz.

**Install Turnip** if any Vulkan software is used (emulators, vkmark, DXVK):

```sh
apt-get install -y mesa-vulkan-drivers vulkan-tools
vulkaninfo --summary | grep -i turnip    # Turnip Adreno (TM) 610
```

It only affects Vulkan. KWin composites with GL ES, and browsers use GL, so it does nothing for the
desktop or WebGL.

## What is genuinely missing

- **Hardware video decode (Venus).** The block exists in the SoC; there is no usable upstream driver
  for SM6115/SM6125. Video is decoded in software: 1080p H.264 is fine on the big cores, HEVC and VP9
  at 1080p are marginal. Do not install VA-API or VDPAU packages, there is no backend for them.
- **Camera (CAMSS).** No upstream support for this part.
- **Interconnect / DDR bandwidth votes** are not exposed by this tree
  (`/sys/kernel/debug/interconnect/interconnect_summary` is empty), so DDR scaling cannot be checked
  or tuned from userspace.

## Qualcomm's own Linux is not usable here

The QRB4210 (IoT sibling of SM6115) board support package is a downstream 4.19-era kernel whose GPU
driver is `kgsl`, not DRM. The closed Adreno GL/Vulkan libraries talk to `kgsl` directly, so adopting
them means replacing the kernel GPU driver, which breaks the display stack. Newer "Qualcomm Linux"
releases target QCS6490 and newer rather than QRB4210. Firmware from another board will not
authenticate on a Retroid; the blobs used here come from this device's own Android partitions.

## Do not bother

- Swapping `schedutil` or `simple_ondemand` for something else.
- VA-API/VDPAU, or chasing Venus without an upstream port.
- A kernel upgrade for CPU or GPU performance: capability there comes from Mesa, and desktop
  performance from the compositor's GL path.
