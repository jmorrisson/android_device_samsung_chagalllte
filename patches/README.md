# Build patches for external repos

These patches must be applied to the checked-out source tree before building.
They are needed because the upstream repos are frozen at LineageOS 19.1 and do
not satisfy the Android 14 build system.

Apply them after `repo sync`:

```bash
cd ~/android/lineage-21.0
git -C hardware/samsung_slsi/exynos5420 apply \
    device/samsung/chagalllte/patches/0001-mobicore-build-as-platform-modules.patch
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

## 0002 - lineage-sdk: match UL's `IUserSwitchObserver` signature

```bash
cd ~/android/lineage-21.0
git -C lineage-sdk apply \
    device/samsung/chagalllte/patches/0002-lineage-sdk-iuserswitchobserver-signature.patch
```

**Symptom** (javac, ~26% into the build):

```
lineage-sdk/.../UserContentObserver.java:35: error: <anonymous ...> is not abstract
    and does not override abstract method onBeforeUserSwitching(int) in IUserSwitchObserver
```

**Cause**: `lineage-sdk` is LineageOS's repo (UL does not fork it) and implements
LineageOS's variant of the callback:

| Tree | `onBeforeUserSwitching` |
|---|---|
| LineageOS `frameworks/base` | `void onBeforeUserSwitching(int newUserId, IRemoteCallback reply)` |
| LineageOS-UL `frameworks/base` (what we build) | `void onBeforeUserSwitching(int newUserId)` (AOSP 14) |

**Fix**: implement the signature the framework actually declares. The override
body is empty in both variants, so behaviour is unchanged. (Patching lineage-sdk
rather than the framework is deliberate: the two-argument form is part of
LineageOS's user-switching machinery, which UL's framework does not have.)

## 0003 - Trebuchet: drop two LineageOS-only framework APIs

```bash
cd ~/android/lineage-21.0
git -C packages/apps/Trebuchet apply \
    device/samsung/chagalllte/patches/0003-trebuchet-ul-framework-apis.patch
```

**Symptom** (javac, ~15% into the build):

```
packages/apps/Trebuchet/quickstep/src/com/android/quickstep/SystemUiProxy.java:213:
    error: method does not override or implement a method from a supertype
.../SystemUiProxy.java:217: error: cannot find symbol  method onKeyEvent(int) ... ISystemUiProxy
.../QuickstepProcessInitializer.java:86: error: cannot find symbol  setDefaultProcessListener(...)
```

**Cause**: `packages/apps/Trebuchet` and `lineage-sdk` are LineageOS repos that UL does not
fork, while **UL's `frameworks/base` fork is frozen at 2025-04-04** — about seven months behind
the LineageOS 21.0 tip the apps are taken from. Trebuchet uses two framework APIs LineageOS added
after that date: `ISystemUiProxy.onKeyEvent(int)` and
`ImageDecoder.setDefaultProcessListener(...)`.

**Fix**: remove the usages — the port loses "hardware-keyboard HOME" forwarding from the recents
overview and the launcher's image-decoder memory tuning, both optional. Patching the app rather
than pinning it to an older revision keeps the rest of the LineageOS pieces (LineageParts,
Settings, …) consistent with `lineage-sdk` at the tip.

## 0004 - IntentResolver: UL has no 4-arg `resolveActivityAsUser`

```bash
cd ~/android/lineage-21.0
git -C packages/modules/IntentResolver apply \
    device/samsung/chagalllte/patches/0004-intentresolver-ul-resolveactivityasuser.patch
```

**Symptom** (javac):

```
packages/modules/IntentResolver/.../IntentForwarderActivity.java:434:
    error: no suitable method found for resolveActivityAsUser(Intent,String,int,int)
```

**Cause**: same UL-vs-LineageOS skew as 0002/0003. LineageOS's `PackageManager` carries a
4-argument `resolveActivityAsUser(Intent, String resolvedType, int flags, int userId)`; UL's fork
has only `(Intent, int flags, int userId)` and the `ResolveInfoFlags` variant.

**Fix**: call the 3-argument overload from the callback; the framework derives the MIME type from
the Intent itself (`resolvedType` was only a hint).

## 0005 - Settings: four LineageOS-only framework APIs

```bash
cd ~/android/lineage-21.0
git -C packages/apps/Settings apply \
    device/samsung/chagalllte/patches/0005-settings-ul-framework-apis.patch
```

**Symptom** (javac, 4 errors): `config_biometric_protected_package_names` (framework resource),
`DeviceAdminInfo.loadDescriptionSafe(PackageManager)` (2 call sites) and
`BiometricPrompt.Builder.setClassNameIfItIsConfirmDeviceCredentialActivity()`.

**Fix**:

| API | Replacement | Effect |
|---|---|---|
| `com.android.internal.R.array.config_biometric_protected_package_names` | `return false` | no package is biometric-protected (LineageOS feature) |
| `DeviceAdminInfo.loadDescriptionSafe(pm)` | `loadDescription(pm)` | the call sites already catch `Resources.NotFoundException` |
| `Builder.setClassNameIfItIsConfirmDeviceCredentialActivity()` | dropped | default class name is used |

(An RRO overlay cannot fix the resource case: the symbol must exist in the framework's `R` class
at compile time.)

## 0006 - ContactsProvider: UL has no SQLiteTokenizer.OPTION_CHECK_BRACKETS

```bash
cd ~/android/lineage-21.0
git -C packages/providers/ContactsProvider apply \
    device/samsung/chagalllte/patches/0006-contactsprovider-ul-sqlitetokenizer.patch
```

**Symptom**:

```
.../contacts/util/SelectionBuilder.java:48: error: cannot find symbol
  symbol:   variable OPTION_CHECK_BRACKETS
  location: class SQLiteTokenizer
```

**Cause**: `android.database.sqlite.SQLiteTokenizer` in UL's framework only defines
`OPTION_NONE` and `OPTION_TOKEN_ONLY`; LineageOS later added `OPTION_CHECK_BRACKETS`
(bracket-balance validation of SQL clauses).

**Fix**: tokenize with `OPTION_NONE`. The clause is still tokenized; only the extra
validation is skipped.
