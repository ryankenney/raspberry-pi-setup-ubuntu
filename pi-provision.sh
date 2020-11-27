#!/bin/bash

set -ex

SCRIPT_FILE="$(basename "$0")"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

function print_usage_and_exit() {
    echo ""
    echo "USAGE: $SCRIPT_FILE execute"
    echo ""
    echo "(Shows this usage message if \"execute\" not specified.)"
    echo ""
    exit 1
}

function print_action() {
    echo ""
    echo "[[[ $1 ]]]"
    echo ""
}

function print_error_and_exit() {
    echo "" >&2
    echo "ERROR: $1" >&2
    echo "" >&2
    exit 1
}

function verify_required_variable() {
    var_name="$1"
    shift

    if [[ "${!var_name}" == "" ]]; then
        print_error_and_exit "Missing required variable [${var_name}]"
    fi
}

function verify_dir_exists() {
    if [[ ! -d "$1" ]]; then
        print_error_and_exit "Missing required directory [$1]"
    fi
}

function verify_file_exists() {
    if [[ ! -f "$1" ]]; then
        print_error_and_exit "Missing required file [$1]"
    fi
}

function verify_sudo_access() {
    sudo ls
}

function clear_cloudinit_userdata() {
    local cloudinit_root="$1"
    shift

    echo "" | sudo tee "$cloudinit_root/user-data" >/dev/null
}


function generate_sshd_keys() {
    local ssh_keys_dir="$1"
    shift

    sudo ssh-keygen -q -N "" -C "" -t ed25519 \
      -f "$ssh_keys_dir/ssh_host_ed25519_key"
    sudo ssh-keygen -q -N "" -C "" -t ecdsa \
      -f "$ssh_keys_dir/ssh_host_ecdsa_key"
    sudo ssh-keygen -q -N "" -C "" -t rsa \
      -f "$ssh_keys_dir/ssh_host_rsa_key"
}

function configure_cloudinit_ssh_server() {
    local ssh_keys_dir="$1"
    shift
    local cloudinit_root="$1"
    shift

    # Write out a Cloud-init yaml containing the SSH server keys.
    # "sed 's/^/    /'": Indents the content to match the yaml.
    sudo tee -a "$cloudinit_root/user-data" >/dev/null << EOF
ssh_keys:
  rsa_private: |
$(sudo sed 's/^/    /' "$ssh_keys_dir/ssh_host_rsa_key")
  rsa_public: $(sudo cat "$ssh_keys_dir/ssh_host_rsa_key.pub")

  ed25519_private: |
$(sudo sed 's/^/    /' "$ssh_keys_dir/ssh_host_ed25519_key")
  ed25519_public: $(sudo cat "$ssh_keys_dir/ssh_host_ed25519_key.pub")

  ecdsa_private: |
$(sudo sed 's/^/    /' "$ssh_keys_dir/ssh_host_ecdsa_key")
  ecdsa_public: $(sudo cat "$ssh_keys_dir/ssh_host_ecdsa_key.pub")

# Ensure password auth is disbled for SSHd (we require keys)
ssh_pwauth: false

EOF
}

function add_server_to_workstation_trust() {
    local ssh_keys_dir="$1"
    shift
    local target_ip="$1"
    shift
    local workstation_known_hosts="$1"
    shift

    # Remove any existing entry for this IP
    ssh-keygen -R "$target_ip" -f "$workstation_known_hosts"

    # Add trust entry for the generated ssh keys
    echo "$target_ip $(cat "$ssh_keys_dir/ssh_host_ecdsa_key.pub")" \
      >> "$workstation_known_hosts"

    # ATTENTION: I could have applied known_hosts hashing to the new entry,
    # but in general I turn off that feature in order to improve auditing.
}

function configure_cloudinit_user() {
    local ssh_keys_dir="$1"
    shift
    local cloudinit_root="$1"
    shift
    local workstation_ssh_pub="$1"
    shift

    sudo tee -a "$cloudinit_root/user-data" >/dev/null << EOF
# Provision the default user
users:
- name: ubuntu
  # The default user in ubuntu has passwordless sudo,
  # and we're using up ssh key auth, so there's no need for a password.
  lock_passwd: true
  # Trust workstation ssh key
  ssh_authorized_keys:
  - "$(cat "$workstation_ssh_pub")"

EOF
}

function configure_cloudinit_wifi() {
    local cloudinit_root="$1"
    shift
    local server_ip="$1"
    shift
    local subnet_mask_bits="$1"
    shift
    local router_ip="$1"
    shift
    local wifi_name="$1"
    shift
    local wifi_pass="$1"
    shift

    echo sudo tee -a "$cloudinit_root/network-config" >/dev/null << EOF
wifis:
  wlan0:
    dhcp4: false
    addresses: ["${server_ip}/${subnet_mask_bits}"]
    gateway4: "${router_ip}"
    nameservers:
      # Cloudflare, then Google
      addresses: ["1.1.1.1", "8.8.8.8", "8.8.4.4"]
    optional: true
    access-points:
      ${wifi_name}:
        password: "${wifi_pass}"

EOF
}

function unmount_sd_card() {
    local filesystem_root="$1"
    shift
    local cloudinit_root="$1"
    shift

    umount "$filesystem_root"
    umount "$cloudinit_root"
}

function main() {

    if [[ $# -eq 0 || "$1" == "-h" || "$1" != "execute" ]]; then
        print_usage_and_exit
    fi

    # Load the config file if it's defined
    if [[ -f "$SCRIPT_DIR/pi-provision.config.sh" ]]; then
        print_action "Loading Config Options"
        . "$SCRIPT_DIR/pi-provision.config.sh"
    fi

    print_action "Validating Config Options"
    verify_required_variable PIPROV_SD_CARD_WRITABLE
    verify_required_variable PIPROV_SD_CARD_SYSTEMBOOT
    verify_required_variable PIPROV_WORKSTATION_KNOWNHOSTS
    verify_required_variable PIPROV_WORKSTATION_ID_RSA_PUB
    verify_required_variable PIPROV_NET_SERVER_IP
    verify_required_variable PIPROV_NET_SUBNET_MASK_BITS
    verify_required_variable PIPROV_NET_GATEWAY_IP
    verify_required_variable PIPROV_NET_WIFI_NAME
    verify_required_variable PIPROV_NET_WIFI_PASS

    verify_dir_exists "$PIPROV_SD_CARD_WRITABLE"
    verify_dir_exists "$PIPROV_SD_CARD_SYSTEMBOOT"
    # Normalize
    export PIPROV_SD_CARD_WRITABLE="$(readlink -f "$PIPROV_SD_CARD_WRITABLE")"
    export PIPROV_SD_CARD_SYSTEMBOOT="$(readlink -f "$PIPROV_SD_CARD_SYSTEMBOOT")"

    verify_file_exists "$PIPROV_WORKSTATION_KNOWNHOSTS"
    verify_file_exists "$PIPROV_WORKSTATION_ID_RSA_PUB"

    local ssh_keys_dir="$PIPROV_SD_CARD_WRITABLE/etc/ssh"

    # Verify and activate user's sodo access
    # ----
    verify_sudo_access

    # Wipe the existing Cloud-init user-data
    # ----
    print_action "Wiping Cloud-init user-data"
    clear_cloudinit_userdata "$PIPROV_SD_CARD_SYSTEMBOOT"

    # Generate the SSH server keys on the SD Card, noting that:
    #
    # * These will technically be wiped from the system
    #   when Cloud-init bootstraps the OS. However, this is as good
    #   a place as any to store the files temporarily--it's convenient
    #   that we're NOT writing these files to our workstation disk.
    # 
    # * These are being generated using the standards of our workstation
    #   OS (key lengths, etc). If the workstation is running an older
    #   openssh implementation, this could be an issue, but it's easily
    #   resolved by regenerating the keys once the server is up.
    # ----
    print_action "Generating SSH Server Keys"
    generate_sshd_keys "$ssh_keys_dir"

    # Generate the Cloud-init yaml config to load the generated SSH server keys,
    # noting that:
    #
    # * Technically, we could have simply set `ssh_deletekeys` to `false`
    #   in the Cloud-init config, and there would have been no need to communicate
    #   the keys via yaml, but I thought this this was a more complete example
    #   for future uses of Cloud-init--ones in which I don't have direct access
    #   to the physical disk.
    #   
    # * The Cloud-init config file now contains "secret" data (private keys),
    #   so care must be taken. Note that this volume is mounted to the running
    #   Raspberry Pi.
    # ----
    print_action "Generating SSH Cloud-init Config"
    configure_cloudinit_ssh_server "$ssh_keys_dir" "$PIPROV_SD_CARD_SYSTEMBOOT"

    # Add trust of server SSH key to local workstation
    # ----
    print_action "Adding SSH Server to Workstation known_hosts"
    add_server_to_workstation_trust \
      "$ssh_keys_dir" \
      "$PIPROV_NET_SERVER_IP" \
      "$PIPROV_WORKSTATION_KNOWNHOSTS"

    # Configure the default user created by Ubuntu:
    #
    # * Disable the user's password. (No need for a password.
    #   We have passwordless sudo and an ssh key for login.)
    #
    # * Add trust of the local workstation's ssh key to the Ubuntu user.
    # ----
    configure_cloudinit_user \
      "$ssh_keys_dir" \
      "$PIPROV_SD_CARD_SYSTEMBOOT" \
      "$PIPROV_WORKSTATION_ID_RSA_PUB"

    # Generate Cloud-init yaml config with wifi connectivity and a static IP
    # ----
    print_action "Generating SSH Network Config"
    configure_cloudinit_wifi \
      "$ssh_keys_dir" \
      "$PIPROV_NET_SERVER_IP" \
      "$PIPROV_NET_SUBNET_MASK_BITS" \
      "$PIPROV_NET_GATEWAY_IP" \
      "$PIPROV_NET_WIFI_NAME" \
      "$PIPROV_NET_WIFI_PASS"

    # Unmount the SD Card volumes for safe removal
    # ----
    print_action "Unmounting SD Card"
    unmount_sd_card \
      "$PIPROV_SD_CARD_WRITABLE" \
      "$PIPROV_SD_CARD_SYSTEMBOOT"
}

main "$@"

