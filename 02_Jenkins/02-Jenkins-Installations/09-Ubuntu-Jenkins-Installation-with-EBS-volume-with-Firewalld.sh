
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
# Jenkins Agent    : TCP 50000
#
# ============================================================
#
# LEARNING FORMAT:
#
# WHAT  : What does the command do?
# WHY   : Why are we using this command?
# WHEN  : When do we use this command in real-world projects?
#
# ============================================================


# ------------------------------------------------------------
# STEP 1: ENABLE BASH STRICT MODE
# ------------------------------------------------------------

# WHAT:
# Specifies Bash as the interpreter for this script.
#
# WHY:
# Ensures the script executes using Bash syntax.
#
# WHEN:
# Whenever we create a Bash automation script.

#!/bin/bash


# WHAT:
# -e : Exit when a command fails.
# -u : Treat undefined variables as errors.
# -x : Print commands before executing them.
# -o pipefail : Fail a pipeline if any command fails.
#
# WHY:
# Prevents the script from silently continuing after errors.
# Also helps us identify which command failed.
#
# WHEN:
# When creating reliable installation and deployment scripts.

set -euxo pipefail


# WHAT:
# Sets Debian package installation to non-interactive mode.
#
# WHY:
# Prevents installation prompts from stopping automation.
#
# WHEN:
# When installing packages through automated scripts.

export DEBIAN_FRONTEND=noninteractive


# ------------------------------------------------------------
# STEP 2: DEFINE CONFIGURATION VARIABLES
# ------------------------------------------------------------

# WHAT:
# Defines the EBS device attached to the EC2 instance.
#
# WHY:
# Jenkins data will be stored on a separate EBS volume.
#
# WHEN:
# When configuring dedicated storage for applications.

EBS_DEVICE="/dev/nvme1n1"


# WHAT:
# Defines Jenkins' home directory.
#
# WHY:
# Jenkins stores jobs, plugins, credentials, configurations
# and build history inside this directory.
#
# WHEN:
# When configuring or migrating Jenkins storage.

JENKINS_HOME_DIR="/var/lib/jenkins"


# WHAT:
# Defines a temporary mount directory.
#
# WHY:
# We temporarily mount EBS here before migrating Jenkins data.
#
# WHEN:
# When copying data between existing and new filesystems.

TEMP_MOUNT_DIR="/mnt/jenkins-ebs"


# WHAT:
# Controls whether the script is permitted to format EBS.
#
# WHY:
# Formatting destroys existing filesystem data.
#
# WHEN:
# Set to true only for a verified new and empty EBS volume.

FORMAT_EBS="false"


# ------------------------------------------------------------
# JENKINS NETWORK CONFIGURATION
# ------------------------------------------------------------

# WHAT:
# Defines the Jenkins web interface port.
#
# WHY:
# Jenkins uses TCP port 8080 by default.
#
# WHEN:
# When configuring Jenkins networking and firewall rules.

JENKINS_PORT=8080


# WHAT:
# Defines the IP address on which Jenkins listens.
#
# WHY:
# 0.0.0.0 means Jenkins listens on all IPv4 interfaces.
# Network access will be restricted through the firewall
# and AWS Security Groups.
#
# WHEN:
# When Jenkins must be reachable through private networking
# or a load balancer.

JENKINS_LISTEN_ADDRESS="0.0.0.0"


# WHAT:
# Defines the allowed source network for Jenkins UI access.
#
# WHY:
# Prevents Jenkins UI access from unauthorized networks.
#
# WHEN:
# When restricting Jenkins access to trusted VPC networks.

JENKINS_ACCESS_CIDR="172.31.0.0/16"


# ------------------------------------------------------------
# JENKINS AGENT CONFIGURATION
# ------------------------------------------------------------

# WHAT:
# Defines the Jenkins inbound agent TCP port.
#
# WHY:
# Agents can connect to the Jenkins controller using this port
# when inbound TCP agent connections are enabled.
#
# WHEN:
# When configuring separate Jenkins build agents.

JENKINS_AGENT_PORT=50000


# WHAT:
# Defines the allowed source network for Jenkins agents.
#
# WHY:
# Only trusted agent machines should connect to this port.
#
# WHEN:
# When configuring secure controller-agent communication.

JENKINS_AGENT_CIDR="172.31.0.0/16"


# ------------------------------------------------------------
# STEP 3: VERIFY EBS DEVICE
# ------------------------------------------------------------

# WHAT:
# Lists block devices, filesystem types, UUIDs and mount points.
#
# WHY:
# Helps identify the correct EBS device before performing
# storage operations.
#
# WHEN:
# When attaching, formatting or mounting additional disks.

lsblk -f


# WHAT:
# Checks whether the specified path is a block device.
#
# WHY:
# Prevents the script from operating on a nonexistent device.
#
# WHEN:
# Before formatting or mounting an EBS volume.

if [[ ! -b "$EBS_DEVICE" ]]; then
    echo "ERROR: EBS device $EBS_DEVICE does not exist."
    exit 1
fi


# WHAT:
# Resolves the actual device path.
#
# WHY:
# Provides a canonical device path for reliable comparison.
#
# WHEN:
# When comparing Linux device paths or symbolic links.

EBS_DEVICE=$(readlink -f "$EBS_DEVICE")

echo "Selected EBS device: $EBS_DEVICE"


# ------------------------------------------------------------
# STEP 4: VERIFY EBS IS NOT THE ROOT DISK
# ------------------------------------------------------------

# WHAT:
# Identifies the device mounted as the root filesystem.
#
# WHY:
# Prevents accidentally selecting the operating system disk.
#
# WHEN:
# Before performing destructive disk operations.

ROOT_SOURCE=$(findmnt -n -o SOURCE /)


# WHAT:
# Resolves the actual root device path.
#
# WHY:
# Makes it possible to compare the root device with EBS.
#
# WHEN:
# When validating storage device identities.

ROOT_DEVICE=$(readlink -f "$ROOT_SOURCE")


# WHAT:
# Checks whether the root device is a valid block device.
#
# WHY:
# Stops execution if the root disk cannot be identified.
#
# WHEN:
# Before continuing with disk configuration.

if [[ ! -b "$ROOT_DEVICE" ]]; then
    echo "ERROR: Unable to identify the root block device."
    exit 1
fi


# WHAT:
# Lists the selected root device and its parent devices.
#
# WHY:
# Helps detect whether the selected EBS device belongs
# to the root disk hierarchy.
#
# WHEN:
# When checking disk dependencies.

ROOT_DEVICES=$(lsblk -s -nrpo NAME "$ROOT_DEVICE")


# WHAT:
# Reads each device from the ROOT_DEVICES variable.
#
# WHY:
# Allows us to compare every device in the root hierarchy
# with the selected EBS device.
#
# WHEN:
# When processing multiline command output in Bash.

while IFS= read -r DEVICE; do

    DEVICE=$(readlink -f "$DEVICE")

    if [[ "$DEVICE" == "$EBS_DEVICE" ]]; then
        echo "ERROR: Selected EBS device is part of the root disk."
        exit 1
    fi

done <<< "$ROOT_DEVICES"


# ------------------------------------------------------------
# STEP 5: CHECK WHETHER EBS IS ALREADY MOUNTED
# ------------------------------------------------------------

# WHAT:
# Retrieves mount information for the selected EBS device.
#
# WHY:
# Prevents mounting an already-mounted filesystem elsewhere.
#
# WHEN:
# Before mounting an additional disk.

EBS_MOUNT_INFO=$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE")


# WHAT:
# Checks whether the device has an existing mount point.
#
# WHY:
# Avoids conflicting mounts and unexpected storage operations.
#
# WHEN:
# Before migrating or mounting EBS.

if [[ -n "$(echo "$EBS_MOUNT_INFO" | grep -v '^[[:space:]]*$' || true)" ]]; then

    echo "EBS mount information:"
    echo "$EBS_MOUNT_INFO"

    # WHAT:
    # Checks whether Jenkins home is already a mount point.
    #
    # WHY:
    # Allows the correct EBS volume to remain mounted there.
    #
    # WHEN:
    # When rerunning an installation script.

    if mountpoint -q "$JENKINS_HOME_DIR"; then

        # WHAT:
        # Retrieves the UUID of the filesystem mounted at Jenkins home.
        #
        # WHY:
        # Verifies that the mounted filesystem is our intended EBS volume.
        #
        # WHEN:
        # When validating existing mounts.

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

# WHAT:
# Downloads the latest package information from repositories.
#
# WHY:
# Ensures Ubuntu knows about the latest available package versions.
#
# WHEN:
# Before installing software or after adding repositories.

sudo apt update


# ------------------------------------------------------------
# STEP 7: INSTALL REQUIRED UTILITIES, JAVA AND FIREWALL
# ------------------------------------------------------------

# WHAT:
# Installs the packages required for Jenkins and EBS configuration.
#
# WHY:
# wget       : Downloads installation files.
# git        : Supports source-code checkout.
# fontconfig : Provides font configuration support for Java.
# openjdk-21-jre : Runs Jenkins using Java 21.
# rsync      : Migrates Jenkins data.
# e2fsprogs  : Provides ext4 filesystem utilities.
# firewalld  : Manages Linux firewall rules.
#
# WHEN:
# During initial Linux server and Jenkins preparation.
#
# -y:
# Automatically confirms package installation prompts.

sudo apt install -y \
    wget \
    git \
    fontconfig \
    openjdk-21-jre \
    rsync \
    e2fsprogs \
    firewalld


# ------------------------------------------------------------
# STEP 8: VERIFY JAVA
# ------------------------------------------------------------

# WHAT:
# Displays the installed Java version.
#
# WHY:
# Jenkins requires a supported Java runtime.
#
# WHEN:
# After installing Java or troubleshooting Jenkins startup.

java -version


# ------------------------------------------------------------
# STEP 9: CREATE APT KEYRINGS DIRECTORY
# ------------------------------------------------------------

# WHAT:
# Creates the APT keyrings directory.
#
# WHY:
# Stores repository signing keys separately from application files.
#
# WHEN:
# When configuring signed third-party APT repositories.
#
# -p:
# Creates parent directories if needed.
# Does not fail if the directory already exists.

sudo mkdir -p /etc/apt/keyrings


# ------------------------------------------------------------
# STEP 10: DOWNLOAD JENKINS REPOSITORY SIGNING KEY
# ------------------------------------------------------------

# WHAT:
# Downloads the official Jenkins repository signing key.
#
# WHY:
# Allows APT to verify packages using the repository's key.
#
# WHEN:
# Before adding and using the Jenkins package repository.
#
# -O:
# Saves the downloaded file using the specified filename.

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key


# ------------------------------------------------------------
# STEP 11: ADD JENKINS LTS REPOSITORY
# ------------------------------------------------------------

# WHAT:
# Creates the Jenkins repository configuration file.
#
# WHY:
# Allows Ubuntu APT to download Jenkins packages from
# the official Jenkins repository.
#
# WHEN:
# When installing Jenkins using its official package repository.
#
# echo:
# Prints repository configuration.
#
# |:
# Passes the output to tee.
#
# tee:
# Writes the configuration into the specified file.
#
# > /dev/null:
# Suppresses duplicate terminal output.

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | \
    sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null


# ------------------------------------------------------------
# STEP 12: DETECT EBS FILESYSTEM
# ------------------------------------------------------------

# WHAT:
# Detects the filesystem type on the EBS device.
#
# WHY:
# Determines whether the volume is already formatted.
#
# WHEN:
# Before deciding whether formatting is necessary.
#
# || true:
# Prevents the script from exiting if blkid does not find
# an existing filesystem.

FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE" || true)

echo "Detected filesystem: ${FS_TYPE:-NONE}"


# ------------------------------------------------------------
# STEP 13: FORMAT EBS ONLY WHEN EXPLICITLY ALLOWED
# ------------------------------------------------------------

# WHAT:
# Checks whether the EBS volume has a detected filesystem.
#
# WHY:
# Prevents unnecessary formatting of an existing filesystem.
#
# WHEN:
# When preparing a new EBS volume.

if [[ -z "$FS_TYPE" ]]; then

    if [[ "$FORMAT_EBS" != "true" ]]; then

        echo "ERROR: No filesystem detected on $EBS_DEVICE."
        echo "Set FORMAT_EBS=true only after verifying the volume."
        exit 1

    fi


    # WHAT:
    # Counts the block-device entries under the selected device.
    #
    # WHY:
    # Refuses automatic formatting when partitions are detected.
    #
    # WHEN:
    # Before formatting a new EBS device.

    DEVICE_COUNT=$(lsblk -nrpo NAME "$EBS_DEVICE" | wc -l)

    if [[ "$DEVICE_COUNT" -ne 1 ]]; then
        echo "ERROR: EBS device contains partitions."
        echo "Refusing automatic formatting."
        exit 1
    fi


    # WHAT:
    # Checks existing filesystem and partition signatures
    # without modifying them.
    #
    # WHY:
    # Prevents formatting a device containing recognizable
    # existing disk signatures.
    #
    # WHEN:
    # Before formatting a verified blank disk.

    EXISTING_SIGNATURES=$(sudo wipefs -n "$EBS_DEVICE" || true)

    if [[ -n "$EXISTING_SIGNATURES" ]]; then
        echo "ERROR: Existing disk signatures detected."
        echo "$EXISTING_SIGNATURES"
        echo "Refusing automatic formatting."
        exit 1
    fi


    # WHAT:
    # Checks whether the EBS device is currently mounted.
    #
    # WHY:
    # Never format a mounted filesystem.
    #
    # WHEN:
    # Immediately before formatting.

    if [[ -n "$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE" | tr -d '[:space:]')" ]]; then
        echo "ERROR: EBS device is mounted."
        exit 1
    fi


    # WHAT:
    # Creates an ext4 filesystem on the EBS device.
    #
    # WHY:
    # ext4 is the filesystem selected for Jenkins storage.
    #
    # WHEN:
    # Only when preparing a verified new and empty EBS volume.
    #
    # WARNING:
    # Formatting can destroy existing data.

    echo "Creating ext4 filesystem on $EBS_DEVICE..."

    sudo mkfs.ext4 "$EBS_DEVICE"

    FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE")

fi


# ------------------------------------------------------------
# STEP 14: VERIFY FILESYSTEM TYPE
# ------------------------------------------------------------

# WHAT:
# Checks whether the detected filesystem is ext4.
#
# WHY:
# Ensures the EBS filesystem matches our configuration.
#
# WHEN:
# After detecting or creating a filesystem.

if [[ "$FS_TYPE" != "ext4" ]]; then

    echo "ERROR: Expected ext4 filesystem."
    echo "Detected filesystem: $FS_TYPE"

    exit 1

fi


# ------------------------------------------------------------
# STEP 15: GET EBS UUID
# ------------------------------------------------------------

# WHAT:
# Retrieves the filesystem UUID.
#
# WHY:
# UUID uniquely identifies the filesystem.
# Device names can change after EC2 reboots.
#
# WHEN:
# When configuring persistent filesystem mounting.

EBS_UUID=$(sudo blkid -s UUID -o value "$EBS_DEVICE")

if [[ -z "$EBS_UUID" ]]; then
    echo "ERROR: Unable to retrieve EBS UUID."
    exit 1
fi

echo "EBS UUID: $EBS_UUID"


# ------------------------------------------------------------
# STEP 16: STOP EXISTING JENKINS SERVICE
# ------------------------------------------------------------

# WHAT:
# Checks whether Jenkins service is installed.
#
# WHY:
# Avoids attempting to stop a nonexistent service.
#
# WHEN:
# When rerunning installation or migrating existing Jenkins.

if systemctl list-unit-files jenkins.service --no-legend |
    grep -q '^jenkins.service'; then

    # WHAT:
    # Stops the Jenkins service.
    #
    # WHY:
    # Prevents Jenkins from modifying data during migration.
    #
    # WHEN:
    # Before migrating Jenkins home to another filesystem.

    sudo systemctl stop jenkins || true

fi


# ------------------------------------------------------------
# STEP 17: PREPARE TEMPORARY MOUNT DIRECTORY
# ------------------------------------------------------------

# WHAT:
# Creates the temporary mount directory.
#
# WHY:
# Provides a location to temporarily access the EBS filesystem.
#
# WHEN:
# During filesystem migration.

sudo mkdir -p "$TEMP_MOUNT_DIR"


# WHAT:
# Checks whether the temporary directory is already mounted.
#
# WHY:
# Prevents accidental overlapping mounts.
#
# WHEN:
# Before mounting a filesystem.

if mountpoint -q "$TEMP_MOUNT_DIR"; then
    echo "ERROR: Temporary mount directory is already mounted."
    exit 1
fi


# ------------------------------------------------------------
# STEP 18: MOUNT EBS TEMPORARILY AND VERIFY
# ------------------------------------------------------------

# WHAT:
# Checks whether Jenkins home is already mounted.
#
# WHY:
# Avoids mounting the same EBS volume unnecessarily.
#
# WHEN:
# During installation reruns.

if mountpoint -q "$JENKINS_HOME_DIR"; then

    CURRENT_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

    if [[ "$CURRENT_UUID" != "$EBS_UUID" ]]; then
        echo "ERROR: Jenkins home is mounted from another volume."
        exit 1
    fi

    echo "Correct EBS volume is already mounted at Jenkins home."

else

    # WHAT:
    # Mounts the EBS filesystem temporarily.
    #
    # WHY:
    # Allows us to inspect the destination before migrating data.
    #
    # WHEN:
    # During EBS data migration.

    sudo mount "$EBS_DEVICE" "$TEMP_MOUNT_DIR"


    # WHAT:
    # Retrieves the UUID of the temporarily mounted filesystem.
    #
    # WHY:
    # Confirms that the correct EBS volume was mounted.
    #
    # WHEN:
    # Immediately after mounting.

    TEMP_UUID=$(findmnt -n -o UUID --target "$TEMP_MOUNT_DIR")

    if [[ "$TEMP_UUID" != "$EBS_UUID" ]]; then
        echo "ERROR: Temporary mount UUID verification failed."
        sudo umount "$TEMP_MOUNT_DIR"
        exit 1
    fi


    # --------------------------------------------------------
    # STEP 19: DETECT SOURCE AND DESTINATION DATA
    # --------------------------------------------------------

    # WHAT:
    # Initializes two Boolean variables.
    #
    # WHY:
    # Tracks whether Jenkins home and EBS contain data.
    #
    # WHEN:
    # Before deciding whether data migration is required.

    SOURCE_HAS_DATA=false
    DESTINATION_HAS_DATA=false


    # WHAT:
    # Checks whether Jenkins home contains files or directories.
    #
    # WHY:
    # Determines whether existing Jenkins data must be migrated.
    #
    # WHEN:
    # When moving Jenkins to dedicated storage.

    if [[ -d "$JENKINS_HOME_DIR" ]] &&
       [[ -n "$(sudo find "$JENKINS_HOME_DIR" \
           -mindepth 1 -maxdepth 1 -print -quit)" ]]; then

        SOURCE_HAS_DATA=true

    fi


    # WHAT:
    # Checks whether the EBS destination already contains data.
    #
    # WHY:
    # Prevents overwriting existing EBS data.
    #
    # WHEN:
    # Before migrating Jenkins data.

    # lost+found is normally created automatically by ext4.
    # We ignore it only when it is empty.
    # Recovered files inside it must be preserved.

    if [[ -n "$(sudo find "$TEMP_MOUNT_DIR" \
        -mindepth 1 -maxdepth 1 \
        ! -name "lost+found" \
        -print -quit)" ]]; then

        DESTINATION_HAS_DATA=true

    elif [[ -d "$TEMP_MOUNT_DIR/lost+found" ]] &&
         [[ -n "$(sudo find "$TEMP_MOUNT_DIR/lost+found" \
             -mindepth 1 -print -quit)" ]]; then

        DESTINATION_HAS_DATA=true

    fi


    echo "SOURCE_HAS_DATA=$SOURCE_HAS_DATA"
    echo "DESTINATION_HAS_DATA=$DESTINATION_HAS_DATA"


    # --------------------------------------------------------
    # STEP 20: PREVENT DATA OVERWRITE
    # --------------------------------------------------------

    # WHAT:
    # Checks whether both source and destination contain data.
    #
    # WHY:
    # Automatically copying data could overwrite or mix
    # existing Jenkins information.
    #
    # WHEN:
    # Before migrating between storage volumes.

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

    # WHAT:
    # Copies Jenkins data to the EBS volume.
    #
    # WHY:
    # Preserves jobs, plugins, credentials and build history.
    #
    # WHEN:
    # When moving existing Jenkins data to dedicated storage.
    #
    # -a : Archive mode.
    # -H : Preserve hard links.
    # -A : Preserve ACL permissions.
    # -X : Preserve extended attributes.
    # --numeric-ids : Preserve numeric ownership IDs.

    if [[ "$SOURCE_HAS_DATA" == "true" ]] &&
       [[ "$DESTINATION_HAS_DATA" == "false" ]]; then

        echo "Migrating existing Jenkins data to EBS..."

        sudo rsync -aHAX --numeric-ids \
            "$JENKINS_HOME_DIR/" "$TEMP_MOUNT_DIR/"

        echo "Jenkins data migration completed."

    elif [[ "$SOURCE_HAS_DATA" == "false" ]] &&
         [[ "$DESTINATION_HAS_DATA" == "true" ]]; then

        echo "Source is empty."
        echo "Existing EBS data will be preserved."

    else

        echo "Both Jenkins source and EBS destination are empty."

    fi


    # --------------------------------------------------------
    # STEP 22: UNMOUNT TEMPORARY EBS MOUNT
    # --------------------------------------------------------

    # WHAT:
    # Unmounts the temporary EBS mount.
    #
    # WHY:
    # The volume must be detached from the temporary directory
    # before mounting it at Jenkins home.
    #
    # WHEN:
    # After completing data migration.

    sudo umount "$TEMP_MOUNT_DIR"


    # --------------------------------------------------------
    # STEP 23: MOUNT EBS AT JENKINS HOME
    # --------------------------------------------------------

    # WHAT:
    # Ensures Jenkins home directory exists.
    #
    # WHY:
    # Linux needs an existing directory as the mount point.
    #
    # WHEN:
    # Before mounting the EBS filesystem.

    sudo mkdir -p "$JENKINS_HOME_DIR"


    # WHAT:
    # Mounts EBS directly at Jenkins home.
    #
    # WHY:
    # Jenkins will now store its data on the dedicated EBS volume.
    #
    # WHEN:
    # After completing data migration.

    sudo mount "$EBS_DEVICE" "$JENKINS_HOME_DIR"

fi


# ------------------------------------------------------------
# STEP 24: CONFIGURE AUTOMATIC EBS MOUNT AT BOOT
# ------------------------------------------------------------

# WHAT:
# Uses awk to inspect /etc/fstab.
#
# WHY:
# Detects whether the correct UUID and mount point already exist.
# Also detects conflicting mount configurations.
#
# WHEN:
# Before adding persistent filesystem configuration.
#
# awk:
# Processes structured text files.
#
# -v:
# Passes shell variables into awk.
#
# $1:
# First column in /etc/fstab.
#
# $2:
# Second column in /etc/fstab.

FSTAB_CHECK=$(sudo awk \
    -v uuid="UUID=$EBS_UUID" \
    -v mount="$JENKINS_HOME_DIR" \
    '
    /^[[:space:]]*#/ { next }

    $1 == uuid && $2 == mount { correct=1 }

    $2 == mount && $1 != uuid { conflict=1 }

    $1 == uuid && $2 != mount { conflict=1 }

    END {
        if (conflict) {
            print "CONFLICT"
        } else if (correct) {
            print "EXISTS"
        } else {
            print "MISSING"
        }
    }
    ' /etc/fstab
)


if [[ "$FSTAB_CHECK" == "CONFLICT" ]]; then

    echo "ERROR: Conflicting EBS entry found in /etc/fstab."
    echo "Manual verification is required."
    exit 1

elif [[ "$FSTAB_CHECK" == "MISSING" ]]; then

    # WHAT:
    # Appends an EBS UUID entry to /etc/fstab.
    #
    # WHY:
    # Ensures EBS is mounted automatically after server reboot.
    #
    # WHEN:
    # When configuring persistent storage.
    #
    # tee -a:
    # Appends content instead of overwriting the file.

    echo "UUID=$EBS_UUID $JENKINS_HOME_DIR ext4 defaults,nofail 0 2" | \
        sudo tee -a /etc/fstab

fi


# ------------------------------------------------------------
# STEP 25: VERIFY EBS MOUNT
# ------------------------------------------------------------

# WHAT:
# Displays the filesystem mounted at Jenkins home.
#
# WHY:
# Confirms that EBS is mounted at the expected location.
#
# WHEN:
# After configuring the mount.

sudo findmnt "$JENKINS_HOME_DIR"


# WHAT:
# Retrieves the UUID of the mounted filesystem.
#
# WHY:
# Confirms that Jenkins home uses the correct EBS volume.
#
# WHEN:
# During storage validation.

MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then

    echo "ERROR: Jenkins home is mounted from an unexpected volume."
    exit 1

fi

echo "EBS mount verified successfully."


# ------------------------------------------------------------
# STEP 26: INSTALL JENKINS
# ------------------------------------------------------------

# WHAT:
# Refreshes package information.
#
# WHY:
# Makes Ubuntu aware of the newly configured Jenkins repository.
#
# WHEN:
# After adding a new APT repository.

sudo apt update


# WHAT:
# Installs Jenkins from the official repository.
#
# WHY:
# Installs the Jenkins controller service and required files.
#
# WHEN:
# After preparing Java, storage and the repository.

sudo apt install -y jenkins


# ------------------------------------------------------------
# STEP 27: SET JENKINS HOME OWNERSHIP AND PERMISSIONS
# ------------------------------------------------------------

# WHAT:
# Changes ownership recursively.
#
# WHY:
# Jenkins must own its home directory to read and write
# jobs, plugins, configurations and build data.
#
# WHEN:
# After mounting EBS or migrating Jenkins data.
#
# -R:
# Applies ownership changes recursively.

sudo chown -R jenkins:jenkins "$JENKINS_HOME_DIR"


# WHAT:
# Restricts access to Jenkins home.
#
# WHY:
# Prevents other local users from accessing Jenkins data.
#
# WHEN:
# When securing application data and configuration directories.
#
# 700:
# Owner has full access.
# Group and others have no access.

sudo chmod 700 "$JENKINS_HOME_DIR"

echo "Jenkins home ownership and permissions configured."


# ------------------------------------------------------------
# STEP 28: CONFIGURE FIREWALL
# ------------------------------------------------------------

echo "============================================================"
echo "CONFIGURING JENKINS FIREWALL"
echo "============================================================"


# ------------------------------------------------------------
# 28.1: ENABLE FIREWALL SERVICE
# ------------------------------------------------------------

# WHAT:
# Enables firewalld at boot and starts it immediately.
#
# WHY:
# Ensures the Linux firewall is active.
#
# WHEN:
# When configuring network security on Linux servers.
#
# enable:
# Starts automatically during boot.
#
# --now:
# Starts the service immediately.

sudo systemctl enable --now firewalld


# WHAT:
# Checks whether firewalld is running.
#
# WHY:
# Verifies that firewall management is available.
#
# WHEN:
# After enabling firewalld.

sudo firewall-cmd --state


# ------------------------------------------------------------
# 28.2: DETECT ACTIVE NETWORK ZONE
# ------------------------------------------------------------

# WHAT:
# Identifies the default network interface.
#
# WHY:
# Firewall zones can be associated with network interfaces.
# We need to identify the interface used by the EC2 instance.
#
# WHEN:
# Before configuring firewall rules.

DEFAULT_INTERFACE=$(ip -o route show default | awk '{print $5; exit}')


# WHAT:
# Validates the detected network interface.
#
# WHY:
# Prevents firewall configuration against an unidentified
# network interface.

if [[ -z "$DEFAULT_INTERFACE" ]]; then
    echo "ERROR: Unable to detect default network interface."
    exit 1
fi


# WHAT:
# Retrieves the firewall zone associated with the interface.
#
# WHY:
# We must add Jenkins rules to the zone handling EC2 traffic.
#
# WHEN:
# Before configuring firewall rules.

ACTIVE_ZONE=$(sudo firewall-cmd \
    --get-zone-of-interface="$DEFAULT_INTERFACE" 2>/dev/null || true)


# WHAT:
# Falls back to the default zone when no interface-specific
# zone is found.
#
# WHY:
# Ensures a valid firewall zone is selected.

if [[ -z "$ACTIVE_ZONE" || "$ACTIVE_ZONE" == "no zone" ]]; then
    ACTIVE_ZONE=$(sudo firewall-cmd --get-default-zone)
fi


echo "Network interface : $DEFAULT_INTERFACE"
echo "Firewall zone     : $ACTIVE_ZONE"


# ------------------------------------------------------------
# 28.3: VERIFY SSH ACCESS BEFORE APPLYING RULES
# ------------------------------------------------------------

# WHAT:
# Checks whether SSH is already allowed in the active zone.
#
# WHY:
# We are configuring a remote EC2 server.
# Accidentally removing SSH access could lock us out.
#
# WHEN:
# Before applying firewall configuration.

if ! sudo firewall-cmd --zone="$ACTIVE_ZONE" --query-service=ssh; then

    echo "ERROR: SSH service is not allowed in the active zone."
    echo "Configure and verify SSH access before continuing."
    exit 1

fi


# ------------------------------------------------------------
# 28.4: CONFIGURE JENKINS WEB UI ACCESS
# ------------------------------------------------------------

# WHAT:
# Creates a source-restricted firewall rule for Jenkins UI.
#
# WHY:
# Only clients within the configured private network
# should access Jenkins web interface.
#
# WHEN:
# When restricting access to Jenkins port 8080.
#
# family="ipv4":
# Applies to IPv4 traffic.
#
# source address:
# Defines the permitted source CIDR.
#
# port:
# Defines the destination port.
#
# protocol="tcp":
# Uses TCP.
#
# accept:
# Allows matching connections.

JENKINS_UI_RULE="rule family=\"ipv4\" source address=\"${JENKINS_ACCESS_CIDR}\" port port=\"${JENKINS_PORT}\" protocol=\"tcp\" accept"


# WHAT:
# Adds the Jenkins UI rule permanently to firewalld.
#
# WHY:
# Keeps the rule after a firewall reload or server reboot.
#
# WHEN:
# When configuring permanent firewall access.

sudo firewall-cmd \
    --permanent \
    --zone="$ACTIVE_ZONE" \
    --add-rich-rule="$JENKINS_UI_RULE"


# ------------------------------------------------------------
# 28.5: CONFIGURE JENKINS AGENT ACCESS
# ------------------------------------------------------------

# WHAT:
# Creates a source-restricted firewall rule for Jenkins agents.
#
# WHY:
# Allows trusted agent machines to connect to the controller.
#
# WHEN:
# When configuring inbound Jenkins agent communication.

JENKINS_AGENT_RULE="rule family=\"ipv4\" source address=\"${JENKINS_AGENT_CIDR}\" port port=\"${JENKINS_AGENT_PORT}\" protocol=\"tcp\" accept"


# WHAT:
# Adds the Jenkins agent firewall rule permanently.
#
# WHY:
# Allows authorized agent connections on TCP 50000.
#
# WHEN:
# When enabling inbound agent communication.

sudo firewall-cmd \
    --permanent \
    --zone="$ACTIVE_ZONE" \
    --add-rich-rule="$JENKINS_AGENT_RULE"


# ------------------------------------------------------------
# 28.6: RELOAD FIREWALL
# ------------------------------------------------------------

# WHAT:
# Reloads firewalld configuration.
#
# WHY:
# Applies the permanent Jenkins firewall rules.
#
# WHEN:
# After adding, modifying or removing permanent firewall rules.

sudo firewall-cmd --reload


# ------------------------------------------------------------
# 28.7: VERIFY FIREWALL RULES
# ------------------------------------------------------------

# WHAT:
# Displays the active zone configuration.
#
# WHY:
# Helps verify interfaces, services, ports and rich rules.
#
# WHEN:
# After configuring firewall access.

sudo firewall-cmd --zone="$ACTIVE_ZONE" --list-all


# WHAT:
# Checks whether the Jenkins UI rule exists.
#
# WHY:
# Confirms that the port 8080 rule is configured.
#
# WHEN:
# During firewall validation.

sudo firewall-cmd \
    --zone="$ACTIVE_ZONE" \
    --query-rich-rule="$JENKINS_UI_RULE"


# WHAT:
# Checks whether the Jenkins agent rule exists.
#
# WHY:
# Confirms that the port 50000 rule is configured.
#
# WHEN:
# During firewall validation.

sudo firewall-cmd \
    --zone="$ACTIVE_ZONE" \
    --query-rich-rule="$JENKINS_AGENT_RULE"


echo "Jenkins firewall configuration completed."


# ------------------------------------------------------------
# STEP 29: CONFIGURE JENKINS LISTEN ADDRESS
# ------------------------------------------------------------

# WHAT:
# Creates a Jenkins systemd service override directory.
#
# WHY:
# Allows us to customize Jenkins service configuration
# without modifying the original package-managed service file.
#
# WHEN:
# When changing Jenkins JVM options, service limits
# or network listening configuration.

sudo mkdir -p /etc/systemd/system/jenkins.service.d


# WHAT:
# Creates a systemd drop-in configuration.
#
# WHY:
# Explicitly configures Jenkins HTTP listening address and port.
#
# WHEN:
# When configuring Jenkins to listen on specific interfaces.
#
# IMPORTANT:
# This uses the current systemd package's JENKINS_PORT and
# JENKINS_LISTEN_ADDRESS environment variables.

cat <<EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf
[Service]
Environment="JENKINS_PORT=${JENKINS_PORT}"
Environment="JENKINS_LISTEN_ADDRESS=${JENKINS_LISTEN_ADDRESS}"
EOF


# WHAT:
# Reloads systemd unit configuration.
#
# WHY:
# Makes systemd recognize the new Jenkins service override.
#
# WHEN:
# After creating or modifying service drop-in files.

sudo systemctl daemon-reload


# ------------------------------------------------------------
# STEP 30: ENABLE AND START JENKINS
# ------------------------------------------------------------

# WHAT:
# Enables Jenkins at system boot.
#
# WHY:
# Jenkins should automatically start after an EC2 reboot.
#
# WHEN:
# When configuring Jenkins as a permanent service.

sudo systemctl enable jenkins


# WHAT:
# Starts Jenkins immediately.
#
# WHY:
# Makes the Jenkins web application available.
#
# WHEN:
# After completing installation and configuration.

sudo systemctl start jenkins


# ------------------------------------------------------------
# STEP 31: VERIFY JENKINS SERVICE
# ------------------------------------------------------------

# WHAT:
# Displays Jenkins service status and recent log messages.
#
# WHY:
# Helps identify whether Jenkins started successfully.
#
# WHEN:
# After starting Jenkins or troubleshooting service failures.
#
# --no-pager:
# Displays output directly without opening a pager.

sudo systemctl status jenkins --no-pager


# WHAT:
# Retrieves the current Jenkins service state.
#
# WHY:
# Allows the script to verify Jenkins is running.
#
# WHEN:
# In automated health checks.

JENKINS_STATUS=$(systemctl is-active jenkins)


if [[ "$JENKINS_STATUS" != "active" ]]; then
    echo "ERROR: Jenkins service is not active."
    exit 1
fi


# ------------------------------------------------------------
# STEP 32: VERIFY EBS MOUNT
# ------------------------------------------------------------

# WHAT:
# Checks whether Jenkins home is a mounted filesystem.
#
# WHY:
# Prevents Jenkins from running against the root filesystem
# when the dedicated EBS volume is not mounted.
#
# WHEN:
# During Jenkins storage health checks.

if ! mountpoint -q "$JENKINS_HOME_DIR"; then
    echo "ERROR: Jenkins home is not mounted."
    exit 1
fi


# WHAT:
# Retrieves the UUID of the mounted filesystem.
#
# WHY:
# Confirms that the correct EBS volume is being used.
#
# WHEN:
# During final storage verification.

MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")


if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then
    echo "ERROR: EBS UUID verification failed."
    exit 1
fi


# ------------------------------------------------------------
# STEP 33: VERIFY JENKINS PORT
# ------------------------------------------------------------

# WHAT:
# Displays listening TCP ports and associated processes.
#
# WHY:
# Helps confirm that Jenkins is listening on port 8080.
#
# WHEN:
# When troubleshooting Jenkins networking.

sudo ss -lntp


# WHAT:
# Searches the listening socket output for Jenkins port 8080.
#
# WHY:
# Automatically verifies that the configured port is listening.
#
# WHEN:
# During automated application health checks.

if ! sudo ss -lntp | grep -q ":${JENKINS_PORT} "; then
    echo "ERROR: Jenkins port $JENKINS_PORT is not listening."
    exit 1
fi


# ------------------------------------------------------------
# STEP 34: COLLECT INSTALLATION INFORMATION
# ------------------------------------------------------------

# WHAT:
# Retrieves the installed Jenkins package version.
#
# WHY:
# Records the installed Jenkins release for verification.
#
# WHEN:
# During installation reporting and troubleshooting.

JENKINS_VERSION=$(dpkg-query -W -f='${Version}' jenkins)


# WHAT:
# Retrieves the installed Java version.
#
# WHY:
# Records which Java runtime is being used.
#
# WHEN:
# During application compatibility checks.

JAVA_VERSION=$(java -version 2>&1 | head -n 1)


# ============================================================
# JENKINS INSTALLATION COMPLETED SUCCESSFULLY
# ============================================================

echo ""
echo "============================================================"
echo "JENKINS INSTALLATION COMPLETED SUCCESSFULLY"
echo "============================================================"

echo "Jenkins version       : $JENKINS_VERSION"
echo "Java version          : $JAVA_VERSION"
echo "Jenkins status        : $JENKINS_STATUS"

echo "EBS device            : $EBS_DEVICE"
echo "EBS UUID              : $EBS_UUID"
echo "Jenkins home          : $JENKINS_HOME_DIR"
echo "Filesystem            : $FS_TYPE"
echo "EBS mount             : VERIFIED"

echo "Jenkins listen address: $JENKINS_LISTEN_ADDRESS"
echo "Jenkins UI port       : $JENKINS_PORT"
echo "Jenkins UI CIDR       : $JENKINS_ACCESS_CIDR"

echo "Jenkins Agent port    : $JENKINS_AGENT_PORT"
echo "Jenkins Agent CIDR    : $JENKINS_AGENT_CIDR"

echo "Firewall status       : $(sudo firewall-cmd --state)"
echo "Firewall zone         : $ACTIVE_ZONE"

echo "============================================================"

echo "Initial Jenkins admin password:"
echo "sudo cat ${JENKINS_HOME_DIR}/secrets/initialAdminPassword"

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
