/*
 * SPDX-FileCopyrightText: 2026 lunar-seal
 * SPDX-FileCopyrightText: 2019-2025 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 *
 * LiveDisplay for the Samsung SM8150 panels, based on hardware/samsung/aidl/livedisplay
 * (samsung-qcom). Differences: no display colour calibration (this panel driver applies
 * sensorRGB only in Samsung's browser and e-book scenarios, and an unusable calibration
 * made the LiveDisplay service in system_server crash at screen off), and the mDNIe
 * nodes are read back as the text the driver prints ("Current Mode: AUTO_MODE",
 * "Current outdoor Mode: OUTDOOR_ON_MODE"), not as numbers.
 */

#define LOG_TAG "vendor.lineage.livedisplay-service.samsung-sm8150"

#include <aidl/vendor/lineage/livedisplay/BnAdaptiveBacklight.h>
#include <aidl/vendor/lineage/livedisplay/BnDisplayModes.h>
#include <aidl/vendor/lineage/livedisplay/BnSunlightEnhancement.h>
#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/parseint.h>
#include <android-base/strings.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include <fstream>
#include <map>
#include <string>
#include <vector>

using android::base::ParseInt;
using android::base::ReadFileToString;
using android::base::Trim;
using android::base::WriteStringToFile;

namespace aidl::vendor::lineage::livedisplay::sm8150 {

static constexpr const char* kBacklightPath = "/sys/class/lcd/panel/power_reduce";
static constexpr const char* kModePath = "/sys/class/mdnie/mdnie/mode";
static constexpr const char* kOutdoorPath = "/sys/class/mdnie/mdnie/outdoor";
static constexpr const char* kDefaultModePath = "/data/vendor/display/.displaymodedefault";

static bool isWritable(const char* path) {
    std::fstream file(path, file.in | file.out);
    return file.good();
}

static ndk::ScopedAStatus unsupported() {
    return ndk::ScopedAStatus::fromExceptionCode(EX_UNSUPPORTED_OPERATION);
}

// ACL (automatic current limit): content-based power saving. Reads back "0" or "1".
class AdaptiveBacklight : public BnAdaptiveBacklight {
  public:
    ndk::ScopedAStatus getEnabled(bool* _aidl_return) override {
        std::string tmp;
        int value = 0;
        if (!ReadFileToString(kBacklightPath, &tmp) || !ParseInt(Trim(tmp), &value)) {
            return unsupported();
        }
        *_aidl_return = value > 0;
        return ndk::ScopedAStatus::ok();
    }
    ndk::ScopedAStatus setEnabled(bool enabled) override {
        if (!WriteStringToFile(enabled ? "1" : "0", kBacklightPath, true)) {
            return unsupported();
        }
        return ndk::ScopedAStatus::ok();
    }
};

// mDNIe screen modes; the ids are the driver's enum MODE.
class DisplayModes : public BnDisplayModes {
  public:
    DisplayModes() {
        std::string tmp;
        int value;
        if (ReadFileToString(kDefaultModePath, &tmp) && ParseInt(Trim(tmp), &value) &&
            kModes.count(value)) {
            mDefaultModeId = value;
        }
        write(mDefaultModeId);
    }

    ndk::ScopedAStatus getDisplayModes(std::vector<DisplayMode>* _aidl_return) override {
        _aidl_return->clear();
        for (const auto& [id, mode] : kModes) _aidl_return->push_back({id, mode.name});
        return ndk::ScopedAStatus::ok();
    }
    ndk::ScopedAStatus getCurrentDisplayMode(DisplayMode* _aidl_return) override {
        int32_t current = mDefaultModeId;
        std::string tmp;
        if (ReadFileToString(kModePath, &tmp)) {
            for (const auto& [id, mode] : kModes) {
                if (tmp.find(mode.kernelName) != std::string::npos) {
                    current = id;
                    break;
                }
            }
        }
        *_aidl_return = {current, kModes.at(current).name};
        return ndk::ScopedAStatus::ok();
    }
    ndk::ScopedAStatus getDefaultDisplayMode(DisplayMode* _aidl_return) override {
        *_aidl_return = {mDefaultModeId, kModes.at(mDefaultModeId).name};
        return ndk::ScopedAStatus::ok();
    }
    ndk::ScopedAStatus setDisplayMode(int32_t modeID, bool makeDefault) override {
        if (!kModes.count(modeID) || !write(modeID)) return unsupported();
        if (makeDefault) {
            if (!WriteStringToFile(std::to_string(modeID), kDefaultModePath)) return unsupported();
            mDefaultModeId = modeID;
        }
        return ndk::ScopedAStatus::ok();
    }

  private:
    struct Mode {
        std::string name;
        std::string kernelName;
    };
    static inline const std::map<int32_t, Mode> kModes = {
            {0, {"Dynamic", "DYNAMIC_MODE"}}, {1, {"Standard", "STANDARD_MODE"}},
            {2, {"Natural", "NATURAL_MODE"}}, {3, {"Cinema", "MOVIE_MODE"}},
            {4, {"Adaptive", "AUTO_MODE"}},   {5, {"Reading", "READING_MODE"}},
    };
    static bool write(int32_t id) { return WriteStringToFile(std::to_string(id), kModePath, true); }
    int32_t mDefaultModeId = 4;
};

// mDNIe outdoor mode. Reads back "Current outdoor Mode: OUTDOOR_ON_MODE" / "..._OFF_MODE".
class SunlightEnhancement : public BnSunlightEnhancement {
  public:
    ndk::ScopedAStatus getEnabled(bool* _aidl_return) override {
        std::string tmp;
        if (!ReadFileToString(kOutdoorPath, &tmp)) return unsupported();
        *_aidl_return = tmp.find("OUTDOOR_ON_MODE") != std::string::npos;
        return ndk::ScopedAStatus::ok();
    }
    ndk::ScopedAStatus setEnabled(bool enabled) override {
        if (!WriteStringToFile(enabled ? "1" : "0", kOutdoorPath, true)) return unsupported();
        return ndk::ScopedAStatus::ok();
    }
};

static bool add(const ndk::SpAIBinder& binder, const char* descriptor) {
    std::string instance = std::string(descriptor) + "/default";
    binder_status_t status = AServiceManager_addService(binder.get(), instance.c_str());
    if (status != STATUS_OK) {
        LOG(ERROR) << "Could not register " << instance << " (" << status << ")";
        return false;
    }
    return true;
}

}  // namespace aidl::vendor::lineage::livedisplay::sm8150

using namespace aidl::vendor::lineage::livedisplay::sm8150;

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(1);
    ABinderProcess_startThreadPool();

    // The VINTF manifest declares all three; register them all, or none (exit) so that
    // no declared interface is left waiting.
    if (!isWritable(kBacklightPath) || !isWritable(kModePath) || !isWritable(kOutdoorPath)) {
        LOG(ERROR) << "mDNIe or panel nodes not writable, exiting";
        return EXIT_FAILURE;
    }

    auto adaptiveBacklight = ndk::SharedRefBase::make<AdaptiveBacklight>();
    auto displayModes = ndk::SharedRefBase::make<DisplayModes>();
    auto sunlightEnhancement = ndk::SharedRefBase::make<SunlightEnhancement>();

    if (!add(adaptiveBacklight->asBinder(), AdaptiveBacklight::descriptor) ||
        !add(displayModes->asBinder(), DisplayModes::descriptor) ||
        !add(sunlightEnhancement->asBinder(), SunlightEnhancement::descriptor)) {
        return EXIT_FAILURE;
    }

    LOG(INFO) << "LiveDisplay HAL service is ready.";
    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;
}
