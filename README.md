raspberry-pi-setup-ubuntu
================

Overview
----------------

This is a procedure/script for bootstrapping a fresh Raspberry Pi server
with Ubuntu Server 20.04 LTS.

How this compares to the
[Official Instructions](https://ubuntu.com/tutorials/how-to-install-ubuntu-on-your-raspberry-pi):

* Automatically configures SSH keys and mutual client/server trust.
  (Prevents opportunity for a MitM attack.)
    * Generates the server SSH keys directly on the SD card (before booting)
    * Updates `known_hosts` on the local workstation
    * Updates `authorized_keys` on the SD card
* Elimininates the need for any password on the default ubuntu user (randomizes it)
    * NOTE: This means there's no known password for local terminal access by default
* Configures a wifi network on the SD card
* Auto-reboots the server once provisioned (necessary for wifi to initialize)


Usage
----------------

NOTE: These instructions were documented against Ubuntu 20.04 LTS as a workstation.

1. [Load the Raspberry Pi Image](docs/Load-the-Raspberry-Pi-Image.md)
2. [Configure the Script](docs/Configure-the-Script.md)
3. [Run the Script](docs/Run-the-Script.md)
3. [Use the Raspberry Pi](docs/Use-the-Raspberry-Pi.md)


