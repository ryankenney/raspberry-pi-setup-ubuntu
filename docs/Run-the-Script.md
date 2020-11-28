Run the Script
================

With the SD Card inserted, and the two mount points active
(which default to `/media/$USER/writable` and `/media/$USER/system-boot`)...

Execute the script:

    cd raspberry-pi-ubuntu-bootstrap
    bash pi-provision.sh execute

... which should result in something similar to:

    [[[ Loading Config Options ]]]


    [[[ Validating Config Options ]]]


    [[[ Generating SSH Server Keys ]]]


    [[[ Adding SSH Server to Workstation known_hosts ]]]

    /home/user/.ssh/known_hosts updated.
    Original contents retained as /home/user/.ssh/known_hosts.old

    [[[ Generating Cloud-init user-data ]]]


    [[[ Generating Cloud-init network-config ]]]


    [[[ Unmounting SD Card ]]]

Pull the SD Card out

