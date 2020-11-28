Load the Raspberry Pi Image
================

Overview
----------------

Why I recommend not using the Raspberry Pi Imager:

1. In contrast to a manual download of the image,
   the RaspPi Imager doesn't ask which architecture (32/64-bit) or
   Raspberry Pi model (2/3/4) I want to support with the image.
   This makes me wonder what common denominator image they're using.

2. I'm not real confident that the RaspPi Imager is doing a proper hash
   validation on the downloaded image.


Manually (Recommended)
----------------

Download an image from the [Ubuntu Page](https://ubuntu.com/download/raspberry-pi)

This page provides a `verify your download` popup, with something similar to the following:

    echo "73a9... *ubuntu-20.10-preinstalled-server-arm64+raspi.img.xz" | shasum -a 256 --check

Running that from the command line allows us to validate the hash of the image.

Extract the image (which automatically deletes the `.xz` file):

    unxz "ubuntu-20.10-preinstalled-server-arm64+raspi.img.xz"

Insert the SD Card

At this point, I think we could use the Raspberry Pi Imager to load the image,
but why bother? Let's use native utilities.

Unmounted any mounted volumes:

    # List volumes
    lsblk -p

    # For each mounted volume under mmcblk0, unmount
    umount /media/$USER/system-boot
    umount ...

Copy the extracted image to the SD Card (disk device, not partition):

    sudo dd bs=4M status=progress conv=fsync \
      if=/home/$USER/Downloads/ubuntu-20.10-preinstalled-server-arm64+raspi.img \
      of=/dev/mmcblk0


Using the Imager (Not Recommended)
----------------

Install the Raspberry Pi Imager via one of these:

    sudo apt install rpi-imager
    # I used this
    sudo snap install rpi-imager

Insert the SD Card

Use the UI to install the Ubuntu Server 20 LTS image to the SD Card

