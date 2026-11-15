

# Find your actual EBS identifier
ls -l /dev/disk/by-id/ | grep Amazon_Elastic_Block_Store

#Example:
# nvme-Amazon_Elastic_Block_Store_vol0123456789abcdef

# Update these variables in the script:
EBS_DEVICE_ID="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_volXXXXXXXX"

FORMAT_EBS="false"



================================================================================================================================================================================================




#!/bin/bash

# ============================================================
# JENKINS INSTALLATION WITH SEPARATE EBS + FIREWALL
# ============================================================
#
# Operating System : Ubuntu 24.04 LTS
# Java Version     : OpenJDK 21
# Jenkins Release  : LTS
# Storage          : Separate AWS EBS Volume
# Filesystem       : ext4
# Jenkins Home     : /var/lib/jenkins
# Firewall         : firewalld
# Jenkins UI       : TCP 8080
# Jenkins Agent    : TCP 50000 (only when inbound TCP agents are enabled)
#
# LEARNING FORMAT:
# WHAT  : What does the command do?
# WHY   : Why are we using this command?
# WHEN  : When do we use this command in real-world projects?
#
# IMPORTANT:
# 1. Review EBS_DEVICE and the CIDR values before running.
# 2. FORMAT_EBS=false is the safe default. Change it to true only
#    for a verified new/empty EBS volume that has no filesystem.
# 3. Port 50000 is opened in firewalld, but the Jenkins inbound
#    agent listener must also be enabled in Manage Jenkins > Security.
# 4. Configure matching inbound rules in the EC2 Security Group.
# ============================================================


# ------------------------------------------------------------
# STEP 1: ENABLE BASH STRICT MODE
# ------------------------------------------------------------

# WHAT: Specifies Bash as the interpreter and enables strict mode.
# WHY : Stops on command failures, undefined variables and pipeline errors.
# WHEN: Use this in reliable installation and deployment scripts.

set -Eeuo pipefail

# WHAT: Prints each command before execution.
# WHY : Helps identify the command that failed during troubleshooting.
# WHEN: Useful while learning and debugging automation scripts.
# Note: -x is enabled separately so the script can be run quietly
#       later by removing the x option.
set -x

# WHAT: Makes package installation non-interactive.
# WHY : Prevents package prompts from stopping automation.
# WHEN: When installing packages through automated scripts.
export DEBIAN_FRONTEND=noninteractive


# ------------------------------------------------------------
# STEP 2: DEFINE CONFIGURATION VARIABLES
# ------------------------------------------------------------

# WHAT: Defines the EBS device attached to the EC2 instance.
# WHY : Jenkins data will be stored on a separate EBS volume.
# WHEN: When configuring dedicated application storage.
EBS_DEVICE="/dev/nvme1n1"

# WHAT: Defines Jenkins home.
# WHY : Jenkins stores jobs, plugins, credentials, configuration
#       and build history here.
# WHEN: When configuring or migrating Jenkins storage.
JENKINS_HOME_DIR="/var/lib/jenkins"

# WHAT: Defines a temporary mount directory for migration.
# WHY : Allows the EBS filesystem to be inspected before final mounting.
# WHEN: When copying data between filesystems.
TEMP_MOUNT_DIR="/mnt/jenkins-ebs"

# WHAT: Controls whether the script may format EBS.
# WHY : Formatting destroys existing filesystem data.
# WHEN: Set true only for a verified new and empty EBS volume.
FORMAT_EBS="false"

# Jenkins network configuration.
JENKINS_PORT=8080
JENKINS_LISTEN_ADDRESS="0.0.0.0"
JENKINS_ACCESS_CIDR="172.31.0.0/16"

# Jenkins inbound agent configuration.
JENKINS_AGENT_PORT=50000
JENKINS_AGENT_CIDR="172.31.0.0/16"


# ------------------------------------------------------------
# STEP 3: VERIFY EBS DEVICE
# ------------------------------------------------------------

# WHAT: Lists block devices, filesystem types, UUIDs and mount points.
# WHY : Helps identify the correct EBS device before storage operations.
# WHEN: When attaching, formatting or mounting additional disks.
lsblk -f

# WHAT: Checks whether the selected path is a block device.
# WHY : Prevents operations on a nonexistent device.
# WHEN: Before formatting or mounting a disk.
if [[ ! -b "$EBS_DEVICE" ]]; then
    echo "ERROR: EBS device $EBS_DEVICE does not exist."
    exit 1
fi

# WHAT: Resolves the canonical device path.
# WHY : Makes device comparisons more reliable.
# WHEN: When comparing device paths or symbolic links.
EBS_DEVICE=$(readlink -f "$EBS_DEVICE")
echo "Selected EBS device: $EBS_DEVICE"


# ------------------------------------------------------------
# STEP 4: VERIFY EBS IS NOT THE ROOT DISK
# ------------------------------------------------------------

# WHAT: Identifies the device backing the root filesystem.
# WHY : Prevents selecting the operating system disk.
# WHEN: Before performing destructive disk operations.
ROOT_SOURCE=$(findmnt -n -o SOURCE /)
ROOT_DEVICE=$(readlink -f "$ROOT_SOURCE")

if [[ ! -b "$ROOT_DEVICE" ]]; then
    echo "ERROR: Unable to identify the root block device."
    exit 1
fi

# WHAT: Lists the root device and its parent-device hierarchy.
# WHY : Detects whether the selected EBS device belongs to the root disk.
# WHEN: When validating storage-device identities.
ROOT_DEVICES=$(lsblk -s -nrpo NAME "$ROOT_DEVICE")

while IFS= read -r DEVICE; do
    [[ -z "$DEVICE" ]] && continue
    DEVICE=$(readlink -f "$DEVICE")

    if [[ "$DEVICE" == "$EBS_DEVICE" ]]; then
        echo "ERROR: Selected EBS device is part of the root disk."
        exit 1
    fi
done <<< "$ROOT_DEVICES"


# ------------------------------------------------------------
# STEP 5: CHECK WHETHER EBS IS ALREADY MOUNTED
# ------------------------------------------------------------

# WHAT: Retrieves mount points for the selected device and its children.
# WHY : Prevents mounting a filesystem that is already mounted elsewhere.
# WHEN: Before mounting an additional disk.
EBS_MOUNT_INFO=$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE")

if [[ -n "$(echo "$EBS_MOUNT_INFO" | grep -v '^[[:space:]]*$' || true)" ]]; then
    echo "EBS mount information:"
    echo "$EBS_MOUNT_INFO"

    # WHAT: Checks whether Jenkins home is already a mount point.
    # WHY : Allows the intended EBS volume to remain mounted there.
    # WHEN: When rerunning an installation script.
    if mountpoint -q "$JENKINS_HOME_DIR"; then
        CURRENT_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")
        EXISTING_UUID=$(sudo blkid -s UUID -o value "$EBS_DEVICE")

        if [[ "$CURRENT_UUID" != "$EXISTING_UUID" ]]; then
            echo "ERROR: Jenkins home is mounted from another volume."
            exit 1
        fi
    else
        echo "ERROR: EBS device is already mounted elsewhere."
        echo "Manual verification is required."
        exit 1
    fi
fi


# ------------------------------------------------------------
# STEP 6: UPDATE UBUNTU PACKAGE INFORMATION
# ------------------------------------------------------------

# WHAT: Downloads the latest package information from repositories.
# WHY : Ensures Ubuntu knows the latest available package versions.
# WHEN: Before installing software or after adding repositories.
sudo apt update


# ------------------------------------------------------------
# STEP 7: INSTALL REQUIRED UTILITIES, JAVA AND FIREWALL
# ------------------------------------------------------------

# WHAT: Installs packages required for Jenkins and EBS configuration.
# WHY :
# wget       - downloads files
# git        - supports source-code checkout
# fontconfig - Java font configuration support
# openjdk-21-jre - runs Jenkins using Java 21
# rsync      - migrates Jenkins data
# e2fsprogs  - provides ext4 filesystem utilities
# firewalld  - manages Linux firewall rules
# WHEN: During initial Linux server and Jenkins preparation.
sudo apt install -y \
    wget \
    git \
    fontconfig \
    openjdk-21-jre \
    rsync \
    e2fsprogs \
    firewalld \
    util-linux


# ------------------------------------------------------------
# STEP 8: VERIFY JAVA
# ------------------------------------------------------------

# WHAT: Displays the installed Java version.
# WHY : Confirms the Java runtime installed for Jenkins.
# WHEN: After installing Java or troubleshooting Jenkins startup.
java -version


# ------------------------------------------------------------
# STEP 9: CREATE APT KEYRINGS DIRECTORY
# ------------------------------------------------------------

# WHAT: Creates the APT keyrings directory.
# WHY : Stores repository signing keys separately from application files.
# WHEN: When configuring signed third-party APT repositories.
sudo mkdir -p /etc/apt/keyrings


# ------------------------------------------------------------
# STEP 10: DOWNLOAD JENKINS REPOSITORY SIGNING KEY
# ------------------------------------------------------------

# WHAT: Downloads the official Jenkins LTS repository signing key.
# WHY : Allows APT to verify packages using the repository signing key.
# WHEN: Before adding and using the Jenkins package repository.
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key


# ------------------------------------------------------------
# STEP 11: ADD JENKINS LTS REPOSITORY
# ------------------------------------------------------------

# WHAT: Creates the Jenkins LTS repository configuration file.
# WHY : Allows APT to download Jenkins from the official repository.
# WHEN: When installing Jenkins using its official package repository.
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | \
    sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null


# ------------------------------------------------------------
# STEP 12: DETECT EBS FILESYSTEM
# ------------------------------------------------------------

# WHAT: Detects the filesystem type on the EBS device.
# WHY : Determines whether the volume is already formatted.
# WHEN: Before deciding whether formatting is necessary.
FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE" || true)
echo "Detected filesystem: ${FS_TYPE:-NONE}"


# ------------------------------------------------------------
# STEP 13: FORMAT EBS ONLY WHEN EXPLICITLY ALLOWED
# ------------------------------------------------------------

# WHAT: Formats only a verified blank EBS device when explicitly enabled.
# WHY : Prevents accidental destruction of existing filesystem data.
# WHEN: Only while preparing a new and empty EBS volume.
if [[ -z "$FS_TYPE" ]]; then
    if [[ "$FORMAT_EBS" != "true" ]]; then
        echo "ERROR: No filesystem detected on $EBS_DEVICE."
        echo "Set FORMAT_EBS=true only after verifying the volume."
        exit 1
    fi

    # WHAT: Counts block-device entries under the selected device.
    # WHY : Refuses automatic formatting when partitions are detected.
    # WHEN: Immediately before formatting a new EBS device.
    DEVICE_COUNT=$(lsblk -nrpo NAME "$EBS_DEVICE" | wc -l)
    if [[ "$DEVICE_COUNT" -ne 1 ]]; then
        echo "ERROR: EBS device contains partitions."
        echo "Refusing automatic formatting."
        exit 1
    fi

    # WHAT: Checks disk signatures without modifying the device.
    # WHY : Refuses formatting when recognizable signatures exist.
    # WHEN: Before formatting a verified blank disk.
    EXISTING_SIGNATURES=$(sudo wipefs -n "$EBS_DEVICE" || true)
    if [[ -n "$EXISTING_SIGNATURES" ]]; then
        echo "ERROR: Existing disk signatures detected."
        echo "$EXISTING_SIGNATURES"
        echo "Refusing automatic formatting."
        exit 1
    fi

    # WHAT: Checks whether the device is mounted.
    # WHY : A mounted filesystem must never be formatted.
    # WHEN: Immediately before formatting.
    if [[ -n "$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE" | tr -d '[:space:]')" ]]; then
        echo "ERROR: EBS device is mounted."
        exit 1
    fi

    # WHAT: Creates an ext4 filesystem.
    # WHY : ext4 is the filesystem selected for Jenkins storage.
    # WHEN: Only for a verified new and empty EBS volume.
    # WARNING: Formatting can destroy existing data.
    echo "Creating ext4 filesystem on $EBS_DEVICE..."
    sudo mkfs.ext4 "$EBS_DEVICE"
    FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE")
fi


# ------------------------------------------------------------
# STEP 14: VERIFY FILESYSTEM TYPE
# ------------------------------------------------------------

# WHAT: Checks whether the detected filesystem is ext4.
# WHY : Ensures the EBS filesystem matches our configuration.
# WHEN: After detecting or creating a filesystem.
if [[ "$FS_TYPE" != "ext4" ]]; then
    echo "ERROR: Expected ext4 filesystem. Detected: $FS_TYPE"
    exit 1
fi


# ------------------------------------------------------------
# STEP 15: GET EBS UUID
# ------------------------------------------------------------

# WHAT: Retrieves the filesystem UUID.
# WHY : UUID identifies the filesystem even if Linux device names change.
# WHEN: When configuring persistent filesystem mounting.
EBS_UUID=$(sudo blkid -s UUID -o value "$EBS_DEVICE")
if [[ -z "$EBS_UUID" ]]; then
    echo "ERROR: Unable to retrieve EBS UUID."
    exit 1
fi
echo "EBS UUID: $EBS_UUID"


# ------------------------------------------------------------
# STEP 16: STOP EXISTING JENKINS SERVICE
# ------------------------------------------------------------

# WHAT: Checks whether the Jenkins service unit is installed.
# WHY : Avoids stopping a nonexistent service.
# WHEN: When rerunning installation or migrating existing Jenkins.
if systemctl list-unit-files jenkins.service --no-legend |
    grep -q '^jenkins.service'; then
    # WHAT: Stops Jenkins.
    # WHY : Prevents Jenkins from changing data during migration.
    # WHEN: Before migrating Jenkins home to another filesystem.
    sudo systemctl stop jenkins
fi


# ------------------------------------------------------------
# STEP 17: PREPARE TEMPORARY MOUNT DIRECTORY
# ------------------------------------------------------------

# WHAT: Creates the temporary mount directory.
# WHY : Provides a location to access EBS during migration.
# WHEN: During filesystem migration.
sudo mkdir -p "$TEMP_MOUNT_DIR"

# WHAT: Checks whether the temporary directory is already mounted.
# WHY : Prevents overlapping or unexpected mounts.
# WHEN: Before mounting a filesystem.
if mountpoint -q "$TEMP_MOUNT_DIR"; then
    echo "ERROR: Temporary mount directory is already mounted."
    exit 1
fi


# ------------------------------------------------------------
# STEP 18: MOUNT EBS TEMPORARILY AND VERIFY
# ------------------------------------------------------------

# WHAT: Checks whether Jenkins home is already mounted.
# WHY : Avoids mounting the same EBS volume unnecessarily.
# WHEN: During installation reruns.
if mountpoint -q "$JENKINS_HOME_DIR"; then
    CURRENT_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")
    if [[ "$CURRENT_UUID" != "$EBS_UUID" ]]; then
        echo "ERROR: Jenkins home is mounted from another volume."
        exit 1
    fi
    echo "Correct EBS volume is already mounted at Jenkins home."
else
    # WHAT: Mounts EBS temporarily.
    # WHY : Allows inspection of the destination before migration.
    # WHEN: During EBS data migration.
    sudo mount "$EBS_DEVICE" "$TEMP_MOUNT_DIR"

    # WHAT: Verifies the UUID of the temporary mount.
    # WHY : Confirms that the correct EBS volume was mounted.
    # WHEN: Immediately after mounting.
    TEMP_UUID=$(findmnt -n -o UUID --target "$TEMP_MOUNT_DIR")
    if [[ "$TEMP_UUID" != "$EBS_UUID" ]]; then
        echo "ERROR: Temporary mount UUID verification failed."
        sudo umount "$TEMP_MOUNT_DIR"
        exit 1
    fi

    # --------------------------------------------------------
    # STEP 19: DETECT SOURCE AND DESTINATION DATA
    # --------------------------------------------------------

    # WHAT: Tracks whether Jenkins home and EBS contain data.
    # WHY : Determines whether migration is required.
    # WHEN: Before choosing a data migration path.
    SOURCE_HAS_DATA=false
    DESTINATION_HAS_DATA=false

    # WHAT: Checks whether Jenkins home contains files/directories.
    # WHY : Determines whether existing Jenkins data must be migrated.
    # WHEN: When moving Jenkins to dedicated storage.
    if [[ -d "$JENKINS_HOME_DIR" ]] &&
       [[ -n "$(sudo find "$JENKINS_HOME_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        SOURCE_HAS_DATA=true
    fi

    # WHAT: Checks whether EBS contains data other than an empty lost+found.
    # WHY : Prevents overwriting existing EBS data.
    # WHEN: Before migrating Jenkins data.
    if [[ -n "$(sudo find "$TEMP_MOUNT_DIR" -mindepth 1 -maxdepth 1 \
        ! -name "lost+found" -print -quit)" ]]; then
        DESTINATION_HAS_DATA=true
    elif [[ -d "$TEMP_MOUNT_DIR/lost+found" ]] &&
         [[ -n "$(sudo find "$TEMP_MOUNT_DIR/lost+found" -mindepth 1 -print -quit)" ]]; then
        DESTINATION_HAS_DATA=true
    fi

    echo "SOURCE_HAS_DATA=$SOURCE_HAS_DATA"
    echo "DESTINATION_HAS_DATA=$DESTINATION_HAS_DATA"


    # --------------------------------------------------------
    # STEP 20: PREVENT DATA OVERWRITE
    # --------------------------------------------------------

    # WHAT: Detects data on both source and destination.
    # WHY : Avoids mixing or overwriting existing Jenkins information.
    # WHEN: Before migrating between storage volumes.
    if [[ "$SOURCE_HAS_DATA" == "true" ]] &&
       [[ "$DESTINATION_HAS_DATA" == "true" ]]; then
        echo "ERROR: Both Jenkins home and EBS contain data."
        echo "Manual verification is required."
        sudo umount "$TEMP_MOUNT_DIR"
        exit 1
    fi


    # --------------------------------------------------------
    # STEP 21: MIGRATE EXISTING JENKINS DATA
    # --------------------------------------------------------

    # WHAT: Copies Jenkins data to EBS.
    # WHY : Preserves jobs, plugins, credentials and build history.
    # WHEN: When moving existing Jenkins data to dedicated storage.
    # -a archive; -H hard links; -A ACLs; -X extended attributes;
    # --numeric-ids preserves numeric ownership IDs.
    if [[ "$SOURCE_HAS_DATA" == "true" ]] &&
       [[ "$DESTINATION_HAS_DATA" == "false" ]]; then
        echo "Migrating existing Jenkins data to EBS..."
        sudo rsync -aHAX --numeric-ids "$JENKINS_HOME_DIR/" "$TEMP_MOUNT_DIR/"
        echo "Jenkins data migration completed."
    elif [[ "$SOURCE_HAS_DATA" == "false" ]] &&
         [[ "$DESTINATION_HAS_DATA" == "true" ]]; then
        echo "Source is empty. Existing EBS data will be preserved."
    else
        echo "Both Jenkins source and EBS destination are empty."
    fi


    # --------------------------------------------------------
    # STEP 22: UNMOUNT TEMPORARY EBS MOUNT
    # --------------------------------------------------------

    # WHAT: Unmounts EBS from the temporary directory.
    # WHY : The volume must be unmounted before final mounting.
    # WHEN: After completing data migration.
    sudo umount "$TEMP_MOUNT_DIR"


    # --------------------------------------------------------
    # STEP 23: MOUNT EBS AT JENKINS HOME
    # --------------------------------------------------------

    # WHAT: Ensures the Jenkins home mount-point directory exists.
    # WHY : Linux requires an existing directory as the mount point.
    # WHEN: Before mounting EBS at Jenkins home.
    sudo mkdir -p "$JENKINS_HOME_DIR"

    # WHAT: Mounts EBS at Jenkins home.
    # WHY : Jenkins data will reside on the dedicated EBS filesystem.
    # WHEN: After migration is complete.
    sudo mount "$EBS_DEVICE" "$JENKINS_HOME_DIR"
fi


# ------------------------------------------------------------
# STEP 24: CONFIGURE AUTOMATIC EBS MOUNT AT BOOT
# ------------------------------------------------------------

# WHAT: Inspects /etc/fstab for the EBS UUID and mount point.
# WHY : Prevents duplicate or conflicting mount entries.
# WHEN: Before adding persistent filesystem configuration.
FSTAB_CHECK=$(sudo awk \
    -v uuid="UUID=$EBS_UUID" \
    -v mount="$JENKINS_HOME_DIR" '
    /^[[:space:]]*#/ { next }
    $1 == uuid && $2 == mount { correct=1 }
    $2 == mount && $1 != uuid { conflict=1 }
    $1 == uuid && $2 != mount { conflict=1 }
    END {
        if (conflict) print "CONFLICT"
        else if (correct) print "EXISTS"
        else print "MISSING"
    }' /etc/fstab)

if [[ "$FSTAB_CHECK" == "CONFLICT" ]]; then
    echo "ERROR: Conflicting EBS entry found in /etc/fstab."
    echo "Manual verification is required."
    exit 1
elif [[ "$FSTAB_CHECK" == "MISSING" ]]; then
    # WHAT: Appends an EBS UUID entry to /etc/fstab.
    # WHY : Ensures EBS mounts automatically after reboot.
    # WHEN: When configuring persistent storage.
    # nofail allows boot to continue if the volume is unavailable;
    # RequiresMountsFor in the Jenkins unit still makes Jenkins depend
    # on the mount being available before Jenkins starts.
    echo "UUID=$EBS_UUID $JENKINS_HOME_DIR ext4 defaults,nofail 0 2" | \
        sudo tee -a /etc/fstab
fi

# WHAT: Validates filesystem-table entries.
# WHY : Detects malformed or inconsistent /etc/fstab configuration.
# WHEN: After changing /etc/fstab and before relying on boot mounts.
sudo findmnt --verify --verbose

# WHAT: Reloads systemd's generated mount units after fstab changes.
# WHY : Makes systemd recognize the updated mount configuration.
# WHEN: After modifying /etc/fstab.
sudo systemctl daemon-reload


# ------------------------------------------------------------
# STEP 25: VERIFY EBS MOUNT
# ------------------------------------------------------------

# WHAT: Displays the filesystem mounted at Jenkins home.
# WHY : Confirms EBS is mounted at the expected location.
# WHEN: After configuring the mount.
sudo findmnt "$JENKINS_HOME_DIR"

# WHAT: Retrieves the mounted filesystem UUID.
# WHY : Confirms Jenkins home uses the intended EBS volume.
# WHEN: During storage validation.
MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")
if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then
    echo "ERROR: Jenkins home is not mounted from the expected EBS UUID."
    exit 1
fi
echo "EBS mount verified successfully."


# ------------------------------------------------------------
# STEP 26: INSTALL JENKINS
# ------------------------------------------------------------

# WHAT: Refreshes package information after adding Jenkins repository.
# WHY : Makes APT aware of the Jenkins package.
# WHEN: After adding a new APT repository.
sudo apt update

# WHAT: Installs Jenkins from the official LTS repository.
# WHY : Installs the Jenkins controller service and required files.
# WHEN: After preparing Java, storage and the repository.
sudo apt install -y jenkins


# ------------------------------------------------------------
# STEP 27: SET JENKINS HOME OWNERSHIP AND PERMISSIONS
# ------------------------------------------------------------

# WHAT: Changes ownership recursively to the Jenkins service account.
# WHY : Jenkins must read and write its jobs, plugins and configuration.
# WHEN: After mounting EBS or migrating Jenkins data.
sudo chown -R jenkins:jenkins "$JENKINS_HOME_DIR"

# WHAT: Restricts access to the Jenkins home directory.
# WHY : Prevents other local users from accessing Jenkins data.
# WHEN: When securing application data.
# 700 = owner full access; group and others no access.
sudo chmod 700 "$JENKINS_HOME_DIR"
echo "Jenkins home ownership and permissions configured."


# ------------------------------------------------------------
# STEP 28: CONFIGURE FIREWALL
# ------------------------------------------------------------

echo "============================================================"
echo "CONFIGURING JENKINS FIREWALL"
echo "============================================================"

# 28.1: ENABLE FIREWALL SERVICE
# WHAT: Enables firewalld at boot and starts it immediately.
# WHY : Ensures Linux firewall is active.
# WHEN: When configuring network security on Linux servers.
sudo systemctl enable --now firewalld
sudo firewall-cmd --state


# 28.2: DETECT ACTIVE NETWORK ZONE
# WHAT: Identifies the default network interface.
# WHY : Firewall zones may be associated with network interfaces.
# WHEN: Before configuring firewall rules.
DEFAULT_INTERFACE=$(ip -o route show default | awk '{print $5; exit}')
if [[ -z "$DEFAULT_INTERFACE" ]]; then
    echo "ERROR: Unable to detect default network interface."
    exit 1
fi

# WHAT: Finds the zone assigned to the interface, or the default zone.
# WHY : Adds rules to the zone handling the EC2 interface's traffic.
# WHEN: Before configuring firewall rules.
ACTIVE_ZONE=$(sudo firewall-cmd --get-zone-of-interface="$DEFAULT_INTERFACE" 2>/dev/null || true)
if [[ -z "$ACTIVE_ZONE" || "$ACTIVE_ZONE" == "no zone" ]]; then
    ACTIVE_ZONE=$(sudo firewall-cmd --get-default-zone)
fi
echo "Network interface : $DEFAULT_INTERFACE"
echo "Firewall zone     : $ACTIVE_ZONE"


# 28.3: VERIFY SSH ACCESS BEFORE APPLYING RULES
# WHAT: Checks whether SSH is allowed in the active zone.
# WHY : Avoids accidentally locking out remote administration.
# WHEN: Before applying firewall configuration.
if ! sudo firewall-cmd --zone="$ACTIVE_ZONE" --query-service=ssh; then
    echo "ERROR: SSH service is not allowed in the active zone."
    echo "Configure and verify SSH access before continuing."
    exit 1
fi


# 28.4: CONFIGURE JENKINS WEB UI ACCESS
# WHAT: Creates a source-restricted rule for Jenkins UI.
# WHY : Limits TCP 8080 access to the trusted private network.
# WHEN: When restricting Jenkins web-interface access.
JENKINS_UI_RULE="rule family=\"ipv4\" source address=\"${JENKINS_ACCESS_CIDR}\" port port=\"${JENKINS_PORT}\" protocol=\"tcp\" accept"

# WHAT: Adds the permanent UI rule only if it does not already exist.
# WHY : Makes the script safe to rerun without ALREADY_ENABLED errors.
# WHEN: During initial setup and repeatable firewall configuration.
if ! sudo firewall-cmd --permanent --zone="$ACTIVE_ZONE" \
    --query-rich-rule="$JENKINS_UI_RULE" >/dev/null; then
    sudo firewall-cmd --permanent --zone="$ACTIVE_ZONE" \
        --add-rich-rule="$JENKINS_UI_RULE"
else
    echo "Jenkins UI firewall rule already exists."
fi


# 28.5: CONFIGURE JENKINS AGENT ACCESS
# WHAT: Creates a source-restricted rule for inbound Jenkins agents.
# WHY : Allows trusted agent machines to connect to the controller.
# WHEN: Only when using inbound TCP agent connections.
JENKINS_AGENT_RULE="rule family=\"ipv4\" source address=\"${JENKINS_AGENT_CIDR}\" port port=\"${JENKINS_AGENT_PORT}\" protocol=\"tcp\" accept"

# WHAT: Adds the permanent agent rule only if it does not already exist.
# WHY : Makes firewall configuration repeatable.
# WHEN: During initial setup and repeatable firewall configuration.
if ! sudo firewall-cmd --permanent --zone="$ACTIVE_ZONE" \
    --query-rich-rule="$JENKINS_AGENT_RULE" >/dev/null; then
    sudo firewall-cmd --permanent --zone="$ACTIVE_ZONE" \
        --add-rich-rule="$JENKINS_AGENT_RULE"
else
    echo "Jenkins agent firewall rule already exists."
fi


# 28.6: RELOAD FIREWALL
# WHAT: Reloads firewalld configuration.
# WHY : Applies permanent Jenkins firewall rules.
# WHEN: After adding, modifying or removing permanent rules.
sudo firewall-cmd --reload


# 28.7: VERIFY FIREWALL RULES
# WHAT: Displays active zone configuration and checks both rich rules.
# WHY : Confirms the expected rules are present.
# WHEN: After configuring firewall access.
sudo firewall-cmd --zone="$ACTIVE_ZONE" --list-all
sudo firewall-cmd --zone="$ACTIVE_ZONE" --query-rich-rule="$JENKINS_UI_RULE"
sudo firewall-cmd --zone="$ACTIVE_ZONE" --query-rich-rule="$JENKINS_AGENT_RULE"
echo "Jenkins firewall configuration completed."


# ------------------------------------------------------------
# STEP 29: CONFIGURE JENKINS LISTEN ADDRESS AND EBS DEPENDENCY
# ------------------------------------------------------------

# WHAT: Creates the systemd service override directory.
# WHY : Customizes Jenkins without editing the package-managed unit.
# WHEN: When changing service startup dependencies or environment.
sudo mkdir -p /etc/systemd/system/jenkins.service.d

# WHAT: Writes the Jenkins systemd drop-in configuration.
# WHY :
# RequiresMountsFor ensures systemd starts Jenkins only after the
# filesystem containing JENKINS_HOME is mounted.
# Environment variables set Jenkins HTTP port and listen address.
# WHEN: When Jenkins uses a dedicated filesystem and custom network settings.
#
# IMPORTANT:
# Keep the [Unit] dependency and [Service] settings in the same file.
# This avoids replacing the EBS startup dependency with only port settings.
cat <<EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf
[Unit]
RequiresMountsFor=${JENKINS_HOME_DIR}

[Service]
Environment="JENKINS_PORT=${JENKINS_PORT}"
Environment="JENKINS_LISTEN_ADDRESS=${JENKINS_LISTEN_ADDRESS}"
EOF

# WHAT: Reloads systemd unit configuration.
# WHY : Makes systemd recognize the updated Jenkins override.
# WHEN: After creating or modifying service drop-in files.
sudo systemctl daemon-reload

# WHAT: Displays the effective Jenkins unit and drop-in configuration.
# WHY : Allows verification that both mount dependency and environment
#       settings are present.
# WHEN: After changing a systemd service override.
sudo systemctl cat jenkins


# ------------------------------------------------------------
# STEP 30: ENABLE AND START JENKINS
# ------------------------------------------------------------

# WHAT: Enables Jenkins at system boot.
# WHY : Jenkins should automatically start after an EC2 reboot.
# WHEN: When configuring Jenkins as a permanent service.
sudo systemctl enable jenkins

# WHAT: Starts Jenkins immediately.
# WHY : Makes the Jenkins web application available.
# WHEN: After completing installation and configuration.
sudo systemctl start jenkins


# ------------------------------------------------------------
# STEP 31: VERIFY JENKINS SERVICE
# ------------------------------------------------------------

# WHAT: Displays Jenkins service status.
# WHY : Shows whether Jenkins started and provides recent status.
# WHEN: After starting Jenkins or troubleshooting startup.
sudo systemctl status jenkins --no-pager

# WHAT: Retrieves the current Jenkins service state.
# WHY : Allows the script to verify Jenkins is running.
# WHEN: During automated health checks.
JENKINS_STATUS=$(systemctl is-active jenkins)
if [[ "$JENKINS_STATUS" != "active" ]]; then
    echo "ERROR: Jenkins service is not active."
    sudo journalctl -u jenkins -n 80 --no-pager || true
    exit 1
fi


# ------------------------------------------------------------
# STEP 32: VERIFY EBS MOUNT
# ------------------------------------------------------------

# WHAT: Checks whether Jenkins home is a mounted filesystem.
# WHY : Prevents Jenkins from using the root filesystem accidentally.
# WHEN: During Jenkins storage health checks.
if ! mountpoint -q "$JENKINS_HOME_DIR"; then
    echo "ERROR: Jenkins home is not mounted."
    exit 1
fi

# WHAT: Retrieves the mounted filesystem UUID.
# WHY : Confirms that the correct EBS volume is in use.
# WHEN: During final storage verification.
MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")
if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then
    echo "ERROR: EBS UUID verification failed."
    exit 1
fi


# ------------------------------------------------------------
# STEP 33: VERIFY JENKINS PORT
# ------------------------------------------------------------

# WHAT: Displays listening TCP sockets and associated processes.
# WHY : Helps confirm Jenkins is listening on the configured port.
# WHEN: When troubleshooting Jenkins networking.
sudo ss -lntp

# WHAT: Waits up to 60 seconds for Jenkins to open its HTTP port.
# WHY : Jenkins may take time to initialize after service start.
# WHEN: During automated application health checks.
PORT_LISTENING=false
for ATTEMPT in $(seq 1 30); do
    if sudo ss -lntH | awk -v port=":${JENKINS_PORT}" '$4 ~ (port "$") { found=1 } END { exit !found }'; then
        PORT_LISTENING=true
        break
    fi
    echo "Waiting for Jenkins port ${JENKINS_PORT}... attempt ${ATTEMPT}/30"
    sleep 2
done

if [[ "$PORT_LISTENING" != "true" ]]; then
    echo "ERROR: Jenkins port $JENKINS_PORT is not listening."
    sudo journalctl -u jenkins -n 80 --no-pager || true
    exit 1
fi

echo "Jenkins HTTP port is listening."


# ------------------------------------------------------------
# STEP 34: COLLECT INSTALLATION INFORMATION
# ------------------------------------------------------------

# WHAT: Retrieves the installed Jenkins package version.
# WHY : Records the installed Jenkins release.
# WHEN: During installation reporting and troubleshooting.
JENKINS_VERSION=$(dpkg-query -W -f='${Version}' jenkins)

# WHAT: Retrieves the installed Java version string.
# WHY : Records which Java runtime is available.
# WHEN: During application compatibility checks.
JAVA_VERSION=$(java -version 2>&1 | head -n 1)

# WHAT: Checks whether the Jenkins inbound agent port is listening.
# WHY : A firewalld rule alone does not enable the Jenkins listener.
# WHEN: When inbound TCP agents are intended to be used.
AGENT_PORT_STATUS="NOT ENABLED OR NOT LISTENING"
if sudo ss -lntH | awk -v port=":${JENKINS_AGENT_PORT}" '$4 ~ (port "$") { found=1 } END { exit !found }'; then
    AGENT_PORT_STATUS="LISTENING"
fi


# ============================================================
# JENKINS INSTALLATION COMPLETED SUCCESSFULLY
# ============================================================

echo ""
echo "============================================================"
echo "JENKINS INSTALLATION COMPLETED SUCCESSFULLY"
echo "============================================================"

echo "Jenkins version        : $JENKINS_VERSION"
echo "Java version           : $JAVA_VERSION"
echo "Jenkins status         : $JENKINS_STATUS"

echo "EBS device             : $EBS_DEVICE"
echo "EBS UUID               : $EBS_UUID"
echo "Jenkins home           : $JENKINS_HOME_DIR"
echo "Filesystem             : $FS_TYPE"
echo "EBS mount              : VERIFIED"

echo "Jenkins listen address : $JENKINS_LISTEN_ADDRESS"
echo "Jenkins UI port        : $JENKINS_PORT"
echo "Jenkins UI CIDR        : $JENKINS_ACCESS_CIDR"

echo "Jenkins Agent port     : $JENKINS_AGENT_PORT"
echo "Jenkins Agent CIDR     : $JENKINS_AGENT_CIDR"
echo "Agent listener status  : $AGENT_PORT_STATUS"

echo "Firewall status        : $(sudo firewall-cmd --state)"
echo "Firewall zone          : $ACTIVE_ZONE"

echo "============================================================"
echo "Initial Jenkins admin password:"
echo "sudo cat ${JENKINS_HOME_DIR}/secrets/initialAdminPassword"
echo "============================================================"

echo "IMPORTANT:"
echo "If you use inbound TCP agents, enable Fixed port ${JENKINS_AGENT_PORT}"
echo "in Manage Jenkins > Security > Agents > TCP port for inbound agents."
echo "Also configure matching inbound rules in the EC2 Security Group."
echo "============================================================"




===========================================================================================================================================================================================


# to give access to my ip
sudo firewall-cmd --zone=jenkins-access --add-source=205.254.168.156/32 --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --zone=jenkins-access --list-all


# to remove access to my ip
sudo firewall-cmd --zone=jenkins-access --remove-source=205.254.168.156/32 --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --zone=jenkins-access --list-all


# to create the zone
sudo firewall-cmd --new-zone=devops-access --permanent
sudo firewall-cmd --permanent --zone=devops-access --set-target=ACCEPT
sudo firewall-cmd --reload


# to list all id address listed to zone
sudo firewall-cmd --zone=devops-access --list-all


# to give access to my ip
sudo firewall-cmd --zone=devops-access --add-source=205.254.168.156/32 --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --zone=devops-access --list-all


#to not allow the traffic
sudo firewall-cmd --permanent --zone=devops-access --set-target=REJECT
sudo firewall-cmd --reload
sudo firewall-cmd --zone=devops-access --list-all


# to delete the zone
sudo firewall-cmd --permanent --delete-zone=devops-access
sudo firewall-cmd --reload


# to list the zones
sudo firewall-cmd --permanent --get-zones




Error: [Errno 30] Read-only file system: '/etc/firewalld/zones/jenkins-access.xml'
==================================================================================
# Check if firewalld is sandboxed
systemctl show firewalld.service --property=ProtectSystem

#If it says ProtectSystem=yes or ProtectSystem=strict: Systemd is explicitly preventing firewalld from writing to its own configuration folder.
  sudo systemctl edit firewalld.service

  [Service]
  ProtectSystem=no

  sudo systemctl daemon-reload
  sudo systemctl restart firewalld.service

  sudo firewall-cmd --zone=jenkins-access --add-source=205.254.168.187/32 --permanent
  sudo firewall-cmd --reload
  sudo firewall-cmd --zone=jenkins-access --list-all
