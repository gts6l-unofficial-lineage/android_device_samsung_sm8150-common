#
# SPDX-FileCopyrightText: 2026 lunar-seal
# SPDX-License-Identifier: Apache-2.0
#

import common


def FullOTA_InstallEnd(info):
    OTA_InstallEnd(info)


def IncrementalOTA_InstallEnd(info):
    info.input_zip = info.target_zip
    OTA_InstallEnd(info)


def AddImage(info, basename, dest):
    data = info.input_zip.read("IMAGES/" + basename)
    common.ZipWriteStr(info.output_zip, basename, data)
    info.script.Print("Patching {} image unconditionally...".format(dest.split("/")[-1]))
    info.script.AppendExtra('package_extract_file("%s", "%s");' % (basename, dest))


def OTA_InstallEnd(info):
    # The device tree overlays belong to the kernel: the stock dtbo describes stock's
    # partition layout (vendor and product on their own partitions, verified).
    AddImage(info, "dtbo.img", "/dev/block/bootdevice/by-name/dtbo")
