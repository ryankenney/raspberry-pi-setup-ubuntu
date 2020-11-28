Use the Raspberry Pi
================

Booting and Connecting
----------------

After executing the setup script, simply insert the SD Card into the Raspberry Pi and boot.

For a Raspberry Pi 3, the provision process took about 120s exactly,
and the reboot took another 40s. At that point the devices was ready for SSH connections.

To ssh in, use (where `192.168.1.50` is the server IP you specified in the config):

    ssh ubuntu@192.168.1.50


Debugging
----------------

If this process fails, and you need local terminal access (USB keyboard and HDMI video),
you can re-provision the SD Card, after making a small edit to the provisioning script:

    #- ubuntu:RANDOM
    - "ubuntu:<your-password>"

... after which you can login using whatever you typed for `<your-password>`.


