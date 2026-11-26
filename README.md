# Device tree for Samsung Qualcomm SM8150 devices (sm8150-common)

Common LineageOS 24.0 device configuration for Samsung devices based on the
Qualcomm SM8150 (Snapdragon 855, "msmnile") platform. Its first user is the
Galaxy Tab S6 LTE (SM-T865, `gts6l`), see `android_device_samsung_gts6l`.

| Basic                   | Spec Sheet                                    |
|------------------------:|:----------------------------------------------|
| SoC                     | Qualcomm SM8150 Snapdragon 855                |
| Platform                | msmnile                                        |
| Kernel                  | Linux 4.14 (`kernel/samsung/sm8150`)          |
| Launch Android version  | 9 (stock firmware: vendor 11, system 12)      |

## Dependencies

This tree needs the following besides the LineageOS default manifest. `lineage.dependencies`
lists the first two; the GCC prebuilts come from the local manifest:

- `android_hardware_samsung` (`hardware/samsung`) from LineageOS.
- `android_kernel_samsung_sm8150` (`kernel/samsung/sm8150`, branch `lineage-24.0`).
- The LineageOS GCC 4.9 prebuilts (`lineage-19.1`): the kernel is compiled with clang
  but linked with GNU ld (needed for `CONFIG_MODVERSIONS` on this 4.14 kernel).

The kernel, this tree and `android_device_samsung_gts6l` are not hosted on LineageOS's
GitHub, so `roomservice` cannot resolve them by name. The `local_manifests` repository published next to this one
contains the manifest (`gts6l.xml`) together with build and install instructions.

WPA3 (SAE) needs `NL80211_WPA_VERSION_3` in the kernel; `android_kernel_samsung_sm8150`
`lineage-24.0` carries the upstream backport.

The kernel is built without Samsung's uH/RKP hypervisor support (as the LineageOS Samsung
kernels do), so the BPF JIT works and the platform needs no patches.

This tree is based on the official LineageOS trees listed in `NOTICE` and on the stock
Samsung firmware. `/metadata` on the OMR partition follows LineageOS
`android_device_samsung_exynos9820-common`.
