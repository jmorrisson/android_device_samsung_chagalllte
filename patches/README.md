# Build patches for external repos

These patches must be applied to the checked-out source tree before building.
They are needed because the upstream repos are frozen at LineageOS 19.1 and do
not satisfy the Android 14 build system.

Apply them after `repo sync`:

```bash
cd ~/android/lineage-21.0/hardware/samsung_slsi/exynos5420
git apply device/samsung/chagalllte/patches/0001-mobicore-build-as-platform-modules.patch
```

## 0001 - mobicore: build as platform modules

**Symptom** (kati aborts before compiling anything):

```
hardware/samsung_slsi/exynos5/libkeymaster/Android.mk: error: "keystore.exynos5 (native:platform) can not link against libMcClient (native:vendor)"
hardware/samsung_slsi/exynos5420/mobicore/daemon/Android.mk: error: "libPaApi (native:platform) can not link against libMcClient (native:vendor)"
hardware/samsung_slsi/exynos5420/mobicore/provlib/jni/Android.mk: error: "libgdmcprov (native:platform) can not link against libMcClient (native:vendor)"
hardware/samsung_slsi/exynos5420/mobicore/rootpa/.../CommonPAWrapper/Android.mk: error: "libcommonpawrapper (native:platform) can not link against libMcClient (native:vendor)"
build/make/core/main.mk:1184: error: exiting from previous errors.
```

**Cause**: `libMcClient`, `mcDriverDaemon` and `libMcRegistry` are declared
`LOCAL_VENDOR_MODULE := true`, but every consumer of them is a platform module
(`libPaApi`, `libgdmcprov`, `libcommonpawrapper`, `keystore.exynos5`).
Android 14's link-type check rejects `native:platform -> native:vendor`
(`build/make/core/binary.mk:1328-1340`).

**Fix**: drop the vendor declaration so the modules build as platform modules.
The device does not lose anything: it already ships the vendor-side copies as
prebuilt blobs from the vendor tree (`mcDriverDaemon`, `libMcClient.so`,
`libMcRegistry.so` in `/vendor/bin` and `/vendor/lib`). This also removes a
latent install-path collision between the built module and the copied blob.
