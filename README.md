# Microsoft LifeCam VX-3000 driver for Windows 10 and 11

The VX-3000 is not a UVC camera. Its video interface enumerates as vendor specific
(USB\VID_045E&PID_00F5&MI_00, class ff), so nothing inbox drives it. Force the
generic USB Video Device onto it and you get a camera parked at code 10, which is
where most people give up.

The 2009 driver still loads on Windows 11. Its catalog is signed by Microsoft and
timestamped in 2009, under the rules that came before the 2015 signing cutoff, so no
test signing and no Secure Boot changes are needed. What stops people is the package
layout: the INF wants the resource DLLs in a folder named after your language ID, and
most downloads of this package arrive with those subfolders collapsed. Install it flat
and you can end up with Korean strings, or a copy error, or nothing at all.

This repo is the installer that sorts that out.

## Install

Clone or download this repo, then from an elevated PowerShell in the repo folder:

    .\Install-VX3000.ps1

Switches:

    -Path <folder>     where the driver files live, default .\driver
    -Language <lcid>   resource language, default 1033
    -CheckOnly         verify the package and report, install nothing
    -KeepStage         keep the staging folder and print where it is

The script finds VX3000.inf, rebuilds the layout in TEMP with the right language
DLLs, checks the catalog signature, compares every file against
checksums/sha256-known.txt, hands the result to pnputil, then prints the device
state. Staging is deleted on the way out.

## What is in driver\

The Windows 7 x64 package, driver version 1.3.10.0 dated 06/04/2009, English only,
with the resource DLLs in the 1033 folder where the INF looks for them. The catalog
is Microsoft's and untouched, so every file still verifies against it, and
checksums/sha256-known.txt lists what each one hashes to, including the other
languages in case you are checking a package of your own.

The official download is gone. Microsoft wrote this driver and it stays theirs. The
copy here exists so the camera works, nothing more.

Already have the package somewhere else? Point the script at it with -Path. It reads
each resource DLL's version block to find your language, so a download that arrived
with the language folders flattened into one directory still installs correctly.

## After it installs

The camera shows up as Microsoft LifeCam VX-3000 under Imaging devices, not under
Cameras, because this is a still image class driver with KS capture interfaces
bolted on. Apps that go through DirectShow see it. Verified here with OpenCV at
640x480.

The microphone is a separate interface on the same composite device and runs on the
inbox audio driver, with or without this install.

Move the camera to another USB port and Windows enumerates it as a new device. The
old port leaves a registry entry behind, so some apps list a capture device that
opens and never delivers a frame. That ghost is the old port, not a broken install.

## Tested on

Windows 11 build 26200, x64, one VX-3000, driver 1.3.10.0. Reports from other builds
are welcome.

## Acknowledgements

Designed by Bootdsc, encabulated by Claude.

The driver itself is Microsoft's work. This repo adds the installer and the notes.

## Cyberdeck Cafe

Old hardware, new tricks, and the people who keep both running.
https://cyberdeck.cafe/
