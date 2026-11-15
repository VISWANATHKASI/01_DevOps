
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
# JENKINS INSTALLATION WITH SEPARATE AWS EBS VOLUME
# ============================================================
#
# Operating System : Ubuntu 24.04 LTS
# Java Version     : OpenJDK 21
# Jenkins Release  : LTS
# Storage          : Separate AWS EBS Volume
# Filesystem       : ext4
# Jenkins Home     : /var/lib/jenkins
# Mount Type       : UUID-based persistent mount
#
# ============================================================
#
# BEFORE RUNNING:
#
# 1. Identify your actual EBS volume:
#
#    ls -l /dev/disk/by-id/ | grep Amazon_Elastic_Block_Store
#
# 2. Update EBS_DEVICE_ID with the actual volume identifier.
#
# 3. FORMAT_EBS=false:
#    Never automatically format the volume.
#
# 4. FORMAT_EBS=true:
#    Allows formatting only when no filesystem, partition
#    or disk signatures are detected.
#
# IMPORTANT:
# Run this script only after verifying that the selected
# EBS volume is the correct additional storage volume.
#
# ============================================================


# ------------------------------------------------------------
# STEP 1: ENABLE BASH STRICT MODE
# ------------------------------------------------------------

# Command: set -euxo pipefail
#
# WHY:
# -e : Stop execution when a command fails.
# -u : Treat undefined variables as errors.
# -x : Display commands before executing them.
# -o pipefail : Detect failures inside pipelines.
#
# WHEN TO USE:
# Use strict mode in automation and provisioning scripts.
# It helps identify errors instead of silently continuing.
#
# IMPORTANT:
# Some commands that are expected to return non-zero status
# are explicitly handled using || true or conditional checks.

set -euxo pipefail


# ------------------------------------------------------------
# STEP 2: SET NON-INTERACTIVE PACKAGE INSTALLATION
# ------------------------------------------------------------

# Command: export DEBIAN_FRONTEND=noninteractive
#
# WHY:
# Prevents Debian package configuration from asking
# interactive questions during automated installation.
#
# WHEN TO USE:
# Useful in cloud provisioning, automated installations,
# cloud-init and CI/CD pipelines.
#
# NOTE:
# sudo configuration may discard exported environment variables.
# We will use sudo -E for APT operations where this setting
# must be preserved.

export DEBIAN_FRONTEND=noninteractive


# ------------------------------------------------------------
# STEP 3: DEFINE VARIABLES
# ------------------------------------------------------------

# WHY:
# Variables allow us to manage configuration from one place.
#
# WHEN TO USE:
# Use variables in scripts when device names, directories,
# ports or configuration values may change between servers.
#
# IMPORTANT:
# EBS_DEVICE_ID uses the stable EBS volume identifier.
# EBS_DEVICE will contain its current resolved Linux device.

EBS_DEVICE_ID="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_volXXXXXXXX"

EBS_DEVICE=""

JENKINS_HOME_DIR="/var/lib/jenkins"

TEMP_MOUNT_DIR="/mnt/jenkins-ebs"

FORMAT_EBS="false"

JENKINS_PORT="8080"

TEMP_MOUNT_ACTIVE=false


# ------------------------------------------------------------
# STEP 4: DEFINE CLEANUP FUNCTION
# ------------------------------------------------------------

# Command: trap cleanup EXIT
#
# WHY:
# If the script fails while the EBS volume is temporarily
# mounted, we should not leave that temporary mount behind.
#
# WHEN TO USE:
# Use trap when scripts create temporary files, mount
# filesystems or allocate temporary resources.
#
# IMPORTANT:
# Cleanup only applies to a temporary mount created by
# this script. It will not unmount an existing user mount.

cleanup() {

    if [[ "$TEMP_MOUNT_ACTIVE" == "true" ]] &&
       mountpoint -q "$TEMP_MOUNT_DIR"; then

        echo "Cleaning up temporary EBS mount..."

        sudo umount "$TEMP_MOUNT_DIR" ||
            echo "WARNING: Temporary EBS unmount failed."

    fi

}

trap cleanup EXIT


# ------------------------------------------------------------
# STEP 5: VERIFY EBS DEVICE IDENTIFIER
# ------------------------------------------------------------

# Command: ls -l /dev/disk/by-id/
#
# WHY:
# Displays persistent device identifiers and their
# corresponding Linux block device paths.
#
# WHEN TO USE:
# Use this when identifying EBS volumes on AWS Nitro instances.
#
# IMPORTANT:
# Never blindly assume that /dev/nvme1n1 will always
# represent the same EBS volume after a reboot.

if [[ "$EBS_DEVICE_ID" == *"XXXXXXXX"* ]]; then

    echo "ERROR: Replace EBS_DEVICE_ID with the actual EBS identifier."
    exit 1

fi

if [[ ! -L "$EBS_DEVICE_ID" ]]; then

    echo "ERROR: EBS identifier does not exist."
    echo "Check the actual EBS volume ID."
    exit 1

fi

EBS_DEVICE=$(readlink -f "$EBS_DEVICE_ID")

if [[ ! -b "$EBS_DEVICE" ]]; then

    echo "ERROR: Resolved EBS device is not a block device."
    exit 1

fi

echo "Stable EBS identifier: $EBS_DEVICE_ID"
echo "Resolved EBS device: $EBS_DEVICE"


# ------------------------------------------------------------
# STEP 6: VERIFY EBS DEVICE TYPE AND DETAILS
# ------------------------------------------------------------

# Command: lsblk
#
# WHY:
# Displays block devices, their sizes, filesystem types,
# mountpoints and storage relationships.
#
# WHEN TO USE:
# Use this when attaching, formatting, partitioning or
# troubleshooting additional storage volumes.
#
# IMPORTANT:
# This script expects an entire EBS disk, not an individual
# partition such as /dev/nvme1n1p1.

lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL

DEVICE_TYPE=$(lsblk -dn -o TYPE "$EBS_DEVICE")

if [[ "$DEVICE_TYPE" != "disk" ]]; then

    echo "ERROR: Selected EBS device is not a complete disk."
    echo "Detected device type: $DEVICE_TYPE"
    exit 1

fi


# ------------------------------------------------------------
# STEP 7: VERIFY EBS IS NOT THE ROOT DISK
# ------------------------------------------------------------

# Commands:
# findmnt -n -o SOURCE /
# readlink -f
# lsblk -s
#
# WHY:
# Identifies the Linux root filesystem and all block devices
# that contribute to it.
#
# WHEN TO USE:
# Always perform this safety check before formatting or
# modifying an additional storage device.
#
# IMPORTANT:
# Never format or overwrite the root disk because it
# contains the operating system.

ROOT_SOURCE=$(findmnt -n -o SOURCE /)

ROOT_DEVICE=$(readlink -f "$ROOT_SOURCE")

if [[ ! -b "$ROOT_DEVICE" ]]; then

    echo "ERROR: Unable to identify the root block device."
    exit 1

fi

ROOT_DEVICES=$(lsblk -s -nrpo NAME "$ROOT_DEVICE")

while IFS= read -r DEVICE; do

    DEVICE=$(readlink -f "$DEVICE")

    if [[ "$DEVICE" == "$EBS_DEVICE" ]]; then

        echo "ERROR: Selected EBS device is part of the root disk."
        exit 1

    fi

done <<< "$ROOT_DEVICES"

echo "Root disk protection check passed."


# ------------------------------------------------------------
# STEP 8: CHECK WHETHER EBS IS ALREADY MOUNTED
# ------------------------------------------------------------

# Commands:
# lsblk -nrpo MOUNTPOINTS
# mountpoint -q
# findmnt
# blkid
#
# WHY:
# Prevents accidentally mounting a volume that is already
# being used by another application or filesystem.
#
# WHEN TO USE:
# Use this before mounting, formatting or migrating data.
#
# IMPORTANT:
# An existing mount at Jenkins home is allowed only when
# its filesystem UUID matches the selected EBS volume.

EBS_MOUNT_INFO=$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE")

EBS_MOUNT_INFO=$(printf '%s\n' "$EBS_MOUNT_INFO" |
    sed '/^[[:space:]]*$/d')

if [[ -n "$EBS_MOUNT_INFO" ]]; then

    echo "Existing EBS mount information:"
    echo "$EBS_MOUNT_INFO"

    if ! mountpoint -q "$JENKINS_HOME_DIR"; then

        echo "ERROR: EBS device is mounted elsewhere."
        exit 1

    fi

    CURRENT_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

    EXISTING_UUID=$(sudo blkid -s UUID -o value "$EBS_DEVICE" || true)

    if [[ -z "$EXISTING_UUID" ]] ||
       [[ "$CURRENT_UUID" != "$EXISTING_UUID" ]]; then

        echo "ERROR: Jenkins home is mounted from another volume."
        exit 1

    fi

    while IFS= read -r MOUNTED_PATH; do

        if [[ "$MOUNTED_PATH" != "$JENKINS_HOME_DIR" ]]; then

            echo "ERROR: EBS has an additional mountpoint."
            exit 1

        fi

    done <<< "$EBS_MOUNT_INFO"

fi


# ------------------------------------------------------------
# STEP 9: UPDATE UBUNTU PACKAGE INFORMATION
# ------------------------------------------------------------

# Command: sudo -E apt update
#
# WHY:
# Downloads the latest package information from configured
# Ubuntu repositories.
#
# WHEN TO USE:
# Run before installing software or after adding a repository.
#
# IMPORTANT:
# apt update refreshes package information.
# It does not upgrade installed applications.

sudo -E apt update


# ------------------------------------------------------------
# STEP 10: INSTALL REQUIRED UTILITIES AND JAVA
# ------------------------------------------------------------

# Command:
# sudo -E apt install -y wget git fontconfig
#     openjdk-21-jre rsync e2fsprogs
#
# WHY:
#
# wget:
# Downloads files from URLs.
# Used to download the Jenkins repository signing key.
#
# git:
# Version control system used to retrieve application source
# code from GitHub, GitLab and other repositories.
#
# fontconfig:
# Provides font configuration support required by Jenkins.
#
# openjdk-21-jre:
# Provides the Java 21 runtime required to run Jenkins.
#
# rsync:
# Copies existing Jenkins data to the EBS volume while
# preserving permissions, ownership and file attributes.
#
# e2fsprogs:
# Provides ext4 filesystem utilities such as mkfs.ext4.
#
# -y:
# Automatically confirms package installation prompts.
#
# WHEN TO USE:
# Install these packages when preparing Ubuntu for Jenkins
# installation and EBS storage configuration.

sudo -E apt install -y \
    wget \
    git \
    fontconfig \
    openjdk-21-jre \
    rsync \
    e2fsprogs \
    util-linux


# ------------------------------------------------------------
# STEP 11: VERIFY JAVA INSTALLATION
# ------------------------------------------------------------

# Command: java -version
#
# WHY:
# Displays the installed Java version.
#
# WHEN TO USE:
# Verify Java before starting Java-based applications
# such as Jenkins.
#
# EXPECTED:
# OpenJDK 21.

java -version


# ------------------------------------------------------------
# STEP 12: CREATE APT KEYRINGS DIRECTORY
# ------------------------------------------------------------

# Command: sudo mkdir -p /etc/apt/keyrings
#
# WHY:
# Creates the directory used to store repository signing keys.
#
# WHEN TO USE:
# Use when configuring third-party APT repositories
# that require package signature verification.
#
# -p:
# Creates parent directories if necessary and does not
# fail when the directory already exists.

sudo mkdir -p /etc/apt/keyrings


# ------------------------------------------------------------
# STEP 13: DOWNLOAD JENKINS REPOSITORY SIGNING KEY
# ------------------------------------------------------------

# Command:
# sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc URL
#
# WHY:
# Downloads the official Jenkins repository signing key.
#
# WHEN TO USE:
# Use this when adding the official Jenkins repository.
#
# -O:
# Saves the downloaded file using the specified filename.
#
# SECURITY:
# APT uses this key to verify Jenkins package signatures.
# Never disable package signature verification to bypass errors.

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key


# ------------------------------------------------------------
# STEP 14: ADD JENKINS LTS APT REPOSITORY
# ------------------------------------------------------------

# Commands: echo, tee
#
# WHY:
# Configures Ubuntu to download Jenkins packages from
# the official Jenkins LTS repository.
#
# signed-by:
# Specifies which signing key APT must use to verify
# packages from this repository.
#
# tee:
# Writes the repository configuration into a protected file.
#
# WHY SUDO WITH TEE?
# Normal shell redirection does not automatically receive
# sudo privileges. sudo tee allows writing into protected
# system directories.
#
# WHEN TO USE:
# Use this when installing software from an official
# third-party APT repository.

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | \
    sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null


# ------------------------------------------------------------
# STEP 15: DETECT EBS FILESYSTEM
# ------------------------------------------------------------

# Command: sudo blkid -o value -s TYPE
#
# WHY:
# Detects the existing filesystem type on the EBS volume.
#
# WHEN TO USE:
# Always check the existing filesystem before formatting
# or mounting an additional disk.
#
# IMPORTANT:
# Never format a volume without first identifying whether
# it already contains a filesystem.

FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE" || true)

echo "Detected filesystem: ${FS_TYPE:-NONE}"


# ------------------------------------------------------------
# STEP 16: FORMAT EBS ONLY WHEN EXPLICITLY ALLOWED
# ------------------------------------------------------------

# Command: mkfs.ext4
#
# WHY:
# Creates an ext4 filesystem on a fresh EBS volume.
#
# WHEN TO USE:
# Only when preparing a verified, new, unformatted volume.
#
# IMPORTANT:
# Formatting destroys existing data.
# The script performs multiple checks before allowing it.
#
# FORMAT_EBS=false:
# Formatting is disabled.
#
# FORMAT_EBS=true:
# Formatting is allowed only when no filesystem,
# partitions or existing disk signatures are detected.

if [[ -z "$FS_TYPE" ]]; then

    if [[ "$FORMAT_EBS" != "true" ]]; then

        echo "ERROR: No filesystem detected on $EBS_DEVICE."
        echo "Set FORMAT_EBS=true only after verifying the volume."
        exit 1

    fi

    # Check that the device has no partitions.
    DEVICE_COUNT=$(lsblk -nrpo NAME "$EBS_DEVICE" | wc -l)

    if [[ "$DEVICE_COUNT" -ne 1 ]]; then

        echo "ERROR: EBS device contains partitions."
        echo "Refusing automatic formatting."
        exit 1

    fi

    # Check for existing disk signatures.
    EXISTING_SIGNATURES=$(sudo wipefs -n "$EBS_DEVICE" || true)

    if [[ -n "$EXISTING_SIGNATURES" ]]; then

        echo "ERROR: Existing disk signatures detected."
        echo "$EXISTING_SIGNATURES"
        echo "Refusing automatic formatting."
        exit 1

    fi

    # Check again that the device is not mounted.
    if [[ -n "$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE" |
        tr -d '[:space:]')" ]]; then

        echo "ERROR: EBS device is mounted."
        exit 1

    fi

    echo "Creating ext4 filesystem on $EBS_DEVICE..."

    sudo mkfs.ext4 "$EBS_DEVICE"

    FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE")

fi


# ------------------------------------------------------------
# STEP 17: VERIFY FILESYSTEM TYPE
# ------------------------------------------------------------

# WHY:
# Jenkins storage will use ext4 in this installation.
#
# WHEN TO USE:
# Verify filesystem compatibility before mounting
# application storage.
#
# IMPORTANT:
# This script supports a whole-disk ext4 filesystem.
# Existing XFS, partition-based or other layouts require
# separate manual verification.

if [[ "$FS_TYPE" != "ext4" ]]; then

    echo "ERROR: Expected ext4 filesystem."
    echo "Detected filesystem: $FS_TYPE"
    exit 1

fi

echo "Filesystem verification successful: $FS_TYPE"


# ------------------------------------------------------------
# STEP 18: GET EBS UUID
# ------------------------------------------------------------

# Command: sudo blkid -s UUID -o value
#
# WHY:
# Retrieves the filesystem UUID.
#
# WHEN TO USE:
# Use filesystem UUIDs when configuring persistent mounts.
#
# IMPORTANT:
# UUID is more reliable than /dev/nvme1n1 because the
# NVMe device enumeration order can change after reboot.

EBS_UUID=$(sudo blkid -s UUID -o value "$EBS_DEVICE")

if [[ -z "$EBS_UUID" ]]; then

    echo "ERROR: Unable to retrieve EBS UUID."
    exit 1

fi

echo "EBS UUID: $EBS_UUID"


# ------------------------------------------------------------
# STEP 19: STOP EXISTING JENKINS SERVICE
# ------------------------------------------------------------

# Commands:
# systemctl list-unit-files
# systemctl stop
#
# WHY:
# Jenkins must not write to its home directory while
# existing data is being migrated.
#
# WHEN TO USE:
# Stop an existing application before migrating its
# data directory or changing its storage location.
#
# IMPORTANT:
# The Jenkins service may not exist during a fresh install.
# Therefore, we check before attempting to stop it.

if systemctl list-unit-files jenkins.service --no-legend |
    grep -q '^jenkins.service'; then

    sudo systemctl stop jenkins || true

fi


# ------------------------------------------------------------
# STEP 20: PREPARE TEMPORARY MOUNT DIRECTORY
# ------------------------------------------------------------

# Command: sudo mkdir -p /mnt/jenkins-ebs
#
# WHY:
# Creates a temporary location to access the EBS filesystem.
#
# WHEN TO USE:
# Use a temporary mountpoint when migrating existing data
# before attaching the volume to its final location.
#
# IMPORTANT:
# Do not overwrite or reuse an existing active mountpoint.

sudo mkdir -p "$TEMP_MOUNT_DIR"

if mountpoint -q "$TEMP_MOUNT_DIR"; then

    echo "ERROR: Temporary mount directory is already mounted."
    exit 1

fi


# ------------------------------------------------------------
# STEP 21: MOUNT EBS TEMPORARILY AND VERIFY
# ------------------------------------------------------------

# Commands:
# mount
# findmnt
#
# WHY:
# Temporarily mounts EBS so we can inspect its existing data
# and migrate Jenkins home safely.
#
# WHEN TO USE:
# Use this approach when moving application data from the
# root filesystem to separate storage.
#
# IMPORTANT:
# Verify the mounted UUID before copying any data.

if mountpoint -q "$JENKINS_HOME_DIR"; then

    CURRENT_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

    if [[ "$CURRENT_UUID" != "$EBS_UUID" ]]; then

        echo "ERROR: Jenkins home is mounted from another volume."
        exit 1

    fi

    echo "Correct EBS volume is already mounted at Jenkins home."

else

    sudo mount "$EBS_DEVICE" "$TEMP_MOUNT_DIR"

    TEMP_MOUNT_ACTIVE=true

    TEMP_UUID=$(findmnt -n -o UUID --target "$TEMP_MOUNT_DIR")

    if [[ "$TEMP_UUID" != "$EBS_UUID" ]]; then

        echo "ERROR: Temporary mount UUID verification failed."
        exit 1

    fi


    # --------------------------------------------------------
    # STEP 22: DETECT SOURCE AND DESTINATION DATA
    # --------------------------------------------------------

    # Commands:
    # find
    #
    # WHY:
    # Identifies whether Jenkins home and the EBS volume
    # already contain data.
    #
    # WHEN TO USE:
    # Always inspect source and destination before migration.
    #
    # IMPORTANT:
    # lost+found is normally created by ext4.
    # An empty lost+found directory is ignored.
    # Recovered files inside lost+found are not ignored.

    SOURCE_HAS_DATA=false
    DESTINATION_HAS_DATA=false

    # Check existing Jenkins home.

    if [[ -d "$JENKINS_HOME_DIR" ]] &&
       [[ -n "$(sudo find "$JENKINS_HOME_DIR" \
           -mindepth 1 -maxdepth 1 -print -quit)" ]]; then

        SOURCE_HAS_DATA=true

    fi


    # Check EBS destination.

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
    # STEP 23: PREVENT DATA OVERWRITE
    # --------------------------------------------------------

    # WHY:
    # Prevents accidental overwriting when both locations
    # already contain data.
    #
    # WHEN TO USE:
    # Use before any storage migration or directory copy.
    #
    # IMPORTANT:
    # If both locations contain data, automatic migration
    # cannot safely decide which copy is authoritative.

    if [[ "$SOURCE_HAS_DATA" == "true" ]] &&
       [[ "$DESTINATION_HAS_DATA" == "true" ]]; then

        echo "ERROR: Both Jenkins home and EBS contain data."
        echo "Manual verification is required."

        exit 1

    fi


    # --------------------------------------------------------
    # STEP 24: MIGRATE EXISTING JENKINS DATA
    # --------------------------------------------------------

    # Command:
    # rsync -aHAX --numeric-ids
    #
    # WHY:
    # Copies files while preserving important Linux metadata.
    #
    # -a:
    # Archive mode. Preserves permissions, ownership,
    # timestamps and symbolic links.
    #
    # -H:
    # Preserves hard links.
    #
    # -A:
    # Preserves Access Control Lists (ACLs).
    #
    # -X:
    # Preserves extended attributes.
    #
    # --numeric-ids:
    # Preserves numeric user and group IDs instead of
    # translating names.
    #
    # WHEN TO USE:
    # Use rsync when migrating Linux application directories
    # between disks or servers.
    #
    # IMPORTANT:
    # Jenkins was stopped before this migration.

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
    # STEP 25: UNMOUNT TEMPORARY EBS MOUNT
    # --------------------------------------------------------

    # Command: sudo umount
    #
    # WHY:
    # Detaches the temporary mount before mounting the
    # filesystem at its final Jenkins home location.
    #
    # WHEN TO USE:
    # Use umount when moving a filesystem from one
    # mountpoint to another.

    sudo umount "$TEMP_MOUNT_DIR"

    TEMP_MOUNT_ACTIVE=false


    # --------------------------------------------------------
    # STEP 26: MOUNT EBS AT JENKINS HOME
    # --------------------------------------------------------

    # Command: sudo mount
    #
    # WHY:
    # Mounts the separate EBS filesystem directly at
    # /var/lib/jenkins.
    #
    # WHEN TO USE:
    # Use a dedicated mountpoint when application data
    # should be stored separately from the operating system.
    #
    # BENEFITS:
    # - Separates Jenkins data from the root disk.
    # - Allows independent storage expansion.
    # - Helps preserve Jenkins data independently.
    # - Makes storage management easier.

    sudo mkdir -p "$JENKINS_HOME_DIR"

    sudo mount "$EBS_DEVICE" "$JENKINS_HOME_DIR"

fi


# ------------------------------------------------------------
# STEP 27: CONFIGURE AUTOMATIC EBS MOUNT AT BOOT
# ------------------------------------------------------------

# File: /etc/fstab
#
# WHY:
# Linux uses /etc/fstab to define filesystems that should
# be mounted automatically during system startup.
#
# WHEN TO USE:
# Configure fstab whenever a filesystem must remain mounted
# automatically after an EC2 restart.
#
# UUID:
# Identifies the filesystem independently of NVMe device order.
#
# ext4:
# Specifies the filesystem type.
#
# defaults:
# Uses standard mount options.
#
# nofail:
# Allows boot to continue if the EBS volume is unavailable.
#
# 0:
# Disables dump backup processing.
#
# 2:
# Sets the filesystem check order after the root filesystem.
#
# IMPORTANT:
# Jenkins will separately be configured to require its
# storage mount before starting.

FSTAB_CHECK=$(sudo awk \
    -v uuid="UUID=$EBS_UUID" \
    -v mount="$JENKINS_HOME_DIR" \
    '
    /^[[:space:]]*#/ { next }

    NF >= 3 && ($1 == uuid || $2 == mount) {

        if ($1 == uuid && $2 == mount && $3 == "ext4") {
            matches++
        } else {
            conflict=1
        }

    }

    END {

        if (conflict || matches > 1) {
            print "CONFLICT"
        } else if (matches == 1) {
            print "EXISTS"
        } else {
            print "MISSING"
        }

    }
    ' /etc/fstab
)

if [[ "$FSTAB_CHECK" == "CONFLICT" ]]; then

    echo "ERROR: Conflicting or duplicate EBS entry found."
    echo "Manual verification is required."
    exit 1

elif [[ "$FSTAB_CHECK" == "MISSING" ]]; then

    echo "UUID=$EBS_UUID $JENKINS_HOME_DIR ext4 defaults,nofail 0 2" |
        sudo tee -a /etc/fstab

fi


# ------------------------------------------------------------
# STEP 28: VERIFY FSTAB CONFIGURATION
# ------------------------------------------------------------

# Command: findmnt --verify --tab-file /etc/fstab
#
# WHY:
# Checks filesystem table configuration for errors.
#
# WHEN TO USE:
# Always validate fstab after adding or modifying entries.
#
# IMPORTANT:
# This checks the complete fstab file, so pre-existing
# unrelated configuration errors may also be reported.

sudo findmnt --verify --tab-file /etc/fstab


# ------------------------------------------------------------
# STEP 29: VERIFY EBS MOUNT
# ------------------------------------------------------------

# Commands:
# findmnt
# findmnt -n -o UUID
#
# WHY:
# Confirms that the EBS volume is mounted at the correct
# Jenkins home directory.
#
# WHEN TO USE:
# Verify mounts after mounting, storage migration and
# filesystem configuration changes.

sudo findmnt "$JENKINS_HOME_DIR"

MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then

    echo "ERROR: Jenkins home is mounted from an unexpected volume."
    exit 1

fi

echo "EBS mount verified successfully."


# ------------------------------------------------------------
# STEP 30: REFRESH PACKAGE INFORMATION
# ------------------------------------------------------------

# Command: sudo -E apt update
#
# WHY:
# Refreshes package information after adding the Jenkins
# repository.
#
# WHEN TO USE:
# Always run apt update after adding a new APT repository.

sudo -E apt update


# ------------------------------------------------------------
# STEP 31: INSTALL JENKINS
# ------------------------------------------------------------

# Command: sudo -E apt install -y jenkins
#
# WHY:
# Installs Jenkins from the official Jenkins LTS repository.
#
# WHEN TO USE:
# Use this when installing Jenkins on Ubuntu.
#
# AFTER INSTALLATION:
# - Jenkins systemd service is created.
# - Jenkins Linux user is created.
# - Jenkins home defaults to /var/lib/jenkins.
# - Jenkins listens on port 8080 by default.
#
# IMPORTANT:
# The package may automatically start Jenkins.
# We will stop it before correcting storage ownership.

sudo -E apt install -y jenkins


# ------------------------------------------------------------
# STEP 32: STOP JENKINS BEFORE OWNERSHIP CONFIGURATION
# ------------------------------------------------------------

# Command: sudo systemctl stop jenkins
#
# WHY:
# Package installation may automatically start Jenkins.
# Stop it before changing ownership of Jenkins home.
#
# WHEN TO USE:
# Use this when changing application storage permissions
# or migrating an application's data directory.

sudo systemctl stop jenkins


# ------------------------------------------------------------
# STEP 33: CONFIGURE JENKINS HOME OWNERSHIP
# ------------------------------------------------------------

# Command: chown
#
# WHY:
# Jenkins runs using the dedicated Linux user named jenkins.
# It needs permission to read and write its home directory.
#
# WHEN TO USE:
# Use this after mounting or migrating application storage.
#
# IMPORTANT:
# The ext4 lost+found directory remains owned by root.
# Other Jenkins home contents are assigned to Jenkins.

sudo chown jenkins:jenkins "$JENKINS_HOME_DIR"

sudo find "$JENKINS_HOME_DIR" \
    -mindepth 1 -maxdepth 1 \
    ! -name "lost+found" \
    -exec chown -R jenkins:jenkins {} +


# ------------------------------------------------------------
# STEP 34: CONFIGURE JENKINS STORAGE DEPENDENCY
# ------------------------------------------------------------

# File:
# /etc/systemd/system/jenkins.service.d/override.conf
#
# Configuration:
# RequiresMountsFor=/var/lib/jenkins
#
# WHY:
# Jenkins must not start before its separate EBS volume
# is successfully mounted.
#
# nofail in fstab allows the operating system to continue
# booting if the EBS volume is unavailable.
#
# Without a service dependency, Jenkins might otherwise
# attempt to use the empty directory on the root filesystem.
#
# RequiresMountsFor:
# Adds the necessary systemd mount requirements and ordering
# for the specified directory.
#
# WHEN TO USE:
# Use this when an application depends on a separately
# mounted filesystem.

JENKINS_DROPIN_DIR="/etc/systemd/system/jenkins.service.d"

sudo mkdir -p "$JENKINS_DROPIN_DIR"

sudo tee "$JENKINS_DROPIN_DIR/override.conf" > /dev/null <<EOF
[Unit]
RequiresMountsFor=$JENKINS_HOME_DIR
EOF


# ------------------------------------------------------------
# STEP 35: RELOAD SYSTEMD CONFIGURATION
# ------------------------------------------------------------

# Command: sudo systemctl daemon-reload
#
# WHY:
# Informs systemd that service configuration or override
# files have changed.
#
# WHEN TO USE:
# Run after creating or modifying systemd service files,
# drop-in configurations or unit dependencies.
#
# IMPORTANT:
# daemon-reload does not restart services by itself.

sudo systemctl daemon-reload


# ------------------------------------------------------------
# STEP 36: ENABLE JENKINS AT SYSTEM STARTUP
# ------------------------------------------------------------

# Command: sudo systemctl enable jenkins
#
# WHY:
# Configures Jenkins to start automatically during
# future Ubuntu system boots.
#
# WHEN TO USE:
# Use for services that should start automatically
# after an EC2 restart.
#
# IMPORTANT:
# enable does not immediately start Jenkins.

sudo systemctl enable jenkins


# ------------------------------------------------------------
# STEP 37: START JENKINS SERVICE
# ------------------------------------------------------------

# Command: sudo systemctl start jenkins
#
# WHY:
# Starts Jenkins immediately.
#
# WHEN TO USE:
# Use after installation and configuration when the
# application is ready to run.
#
# IMPORTANT:
# systemd will enforce the configured storage dependency.

sudo systemctl start jenkins


# ------------------------------------------------------------
# STEP 38: VERIFY JENKINS SERVICE STATUS
# ------------------------------------------------------------

# Command: sudo systemctl status jenkins --no-pager
#
# WHY:
# Displays Jenkins service status, recent logs and
# startup information.
#
# WHEN TO USE:
# Use after installation, service startup and
# configuration changes.
#
# EXPECTED:
# Active: active (running)

sudo systemctl status jenkins --no-pager || true

JENKINS_STATUS=$(systemctl is-active jenkins || true)

if [[ "$JENKINS_STATUS" != "active" ]]; then

    echo "ERROR: Jenkins service is not active."

    sudo journalctl -u jenkins -n 50 --no-pager || true

    exit 1

fi


# ------------------------------------------------------------
# STEP 39: VERIFY JENKINS STARTUP CONFIGURATION
# ------------------------------------------------------------

# Command: systemctl is-enabled jenkins
#
# WHY:
# Verifies that Jenkins is configured for automatic startup.
#
# WHEN TO USE:
# Use when verifying systemd service startup configuration.
#
# EXPECTED:
# enabled

JENKINS_ENABLED=$(systemctl is-enabled jenkins)

if [[ "$JENKINS_ENABLED" != "enabled" ]]; then

    echo "ERROR: Jenkins is not enabled at system startup."
    exit 1

fi


# ------------------------------------------------------------
# STEP 40: VERIFY EBS MOUNT AFTER JENKINS STARTUP
# ------------------------------------------------------------

# Commands:
# mountpoint
# findmnt
#
# WHY:
# Confirms Jenkins is running with its home directory
# mounted from the expected EBS filesystem.
#
# WHEN TO USE:
# Use during final installation verification and
# troubleshooting storage-related application failures.

if ! mountpoint -q "$JENKINS_HOME_DIR"; then

    echo "ERROR: Jenkins home is not mounted."
    exit 1

fi

MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then

    echo "ERROR: EBS UUID verification failed."
    exit 1

fi


# ------------------------------------------------------------
# STEP 41: DISPLAY INSTALLED JENKINS VERSION
# ------------------------------------------------------------

# Command: dpkg-query -W -f='${Version}' jenkins
#
# WHY:
# Displays the installed Jenkins package version.
#
# WHEN TO USE:
# Use when verifying installed software versions
# or troubleshooting version-related issues.

JENKINS_VERSION=$(dpkg-query -W -f='${Version}' jenkins)


# ------------------------------------------------------------
# STEP 42: DISPLAY INSTALLED JAVA VERSION
# ------------------------------------------------------------

# Command: java -version
#
# WHY:
# Verifies the installed Java runtime.
#
# WHEN TO USE:
# Use when troubleshooting Java-based applications
# and compatibility problems.

JAVA_VERSION=$(java -version 2>&1 | sed -n '1p')


# ------------------------------------------------------------
# STEP 43: VERIFY JENKINS PORT CONFIGURATION
# ------------------------------------------------------------

# Command: ss -lntp
#
# WHY:
# Displays listening TCP ports and their associated processes.
#
# WHEN TO USE:
# Use when verifying application network listeners
# and troubleshooting port conflicts.
#
# EXPECTED:
# Jenkins should listen on TCP port 8080 by default.
#
# IMPORTANT:
# This checks the local listener, not external network
# accessibility through AWS Security Groups or firewalls.

sudo ss -lntp | grep ":$JENKINS_PORT " || {

    echo "WARNING: Jenkins port $JENKINS_PORT was not found."
    echo "Check Jenkins service configuration and logs."

}


# ============================================================
# JENKINS INSTALLATION COMPLETED SUCCESSFULLY
# ============================================================

echo "============================================================"
echo "JENKINS INSTALLATION COMPLETED SUCCESSFULLY"
echo "============================================================"

echo "Jenkins version : $JENKINS_VERSION"
echo "Java version    : $JAVA_VERSION"
echo "Jenkins status  : $JENKINS_STATUS"
echo "Startup status  : $JENKINS_ENABLED"
echo "EBS identifier  : $EBS_DEVICE_ID"
echo "EBS device      : $EBS_DEVICE"
echo "EBS UUID        : $EBS_UUID"
echo "Jenkins home    : $JENKINS_HOME_DIR"
echo "Filesystem      : $FS_TYPE"
echo "EBS mount       : VERIFIED"
echo "Jenkins port    : $JENKINS_PORT"

echo "============================================================"
