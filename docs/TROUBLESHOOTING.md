# Troubleshooting

## Code 10 on USB Video Device

Someone bound usbvideo.sys to a vendor specific interface. Check it:

    Get-PnpDevice | Where-Object { $_.InstanceId -like '*VID_045E&PID_00F5*' }

The video interface is MI_00. Its compatible IDs read Class_ff, not Class_0e, which
is why the UVC driver cannot start it. Installing this package replaces that binding.
If Windows keeps the old driver, open Device Manager, right click the device, Update
driver, Browse my computer, and point at the staging folder from -KeepStage.

## pnputil is not recognized

The shell is 32 bit, or PATH is damaged. Call it by full path:

    C:\Windows\System32\pnputil.exe /add-driver <inf> /install

From a 32 bit host use C:\Windows\Sysnative\pnputil.exe instead.

## The camera disappeared after install

Check the whole device tree rather than the Cameras node:

    Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like '*PID_00F5*' }

This driver installs as Image class, so Device Manager files it under Imaging
devices. A camera on a different USB port than before also gets a fresh instance ID,
and the old one stays in the registry as a non present device.

## An app lists two cameras and one is black

The second entry is the interface registration from a port the camera used earlier.
Capture device order comes from this key, oldest registration first:

    HKLM\SYSTEM\CurrentControlSet\Control\DeviceClasses\{6994ad05-93ef-11d0-a3cc-00a0c9223196}

Entries whose Linked value is 0 are dead. Unplug, remove the non present device from
Device Manager with Show hidden devices turned on, then plug back in.

## The Windows Camera app does not list it

The driver registers KSCATEGORY_CAPTURE and KSCATEGORY_VIDEO. DirectShow apps work.
The Camera app and other Media Foundation clients were not tested here.

## The catalog does not verify

The signature is SHA-1 from 2009 and depends on the pre 2015 grandfather rule. A
machine with stricter code integrity policy, or a tampered file, will refuse it. Run
with -CheckOnly first and compare the hashes against checksums/sha256-known.txt.

## Removing it

    pnputil /enum-drivers

Find the oemN.inf whose original name is VX3000.inf, then:

    pnputil /delete-driver oemN.inf /uninstall
