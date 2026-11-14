
#!/bin/bash

# ============================================================
# JENKINS INSTALLATION SCRIPT WITH SEPARATE EBS VOLUME
# ============================================================
#
# Operating System : Ubuntu 24.04 LTS
# Java Version     : OpenJDK 21
# Jenkins Release  : LTS
# Storage          : Separate AWS EBS Volume
# Filesystem       : ext4
# Jenkins Home     : /var/lib/jenkins
#
# ============================================================


# ------------------------------------------------------------
# STEP 1: ENABLE BASH STRICT MODE
# ------------------------------------------------------------

# Command: set -euxo pipefail
#
# WHY:
# -e : Stop script execution when a command fails.
# -u : Treat undefined variables as errors.
# -x : Display each command before executing it.
# -o pipefail : Detect failures in commands connected using pipes.
#
# WHEN TO USE:
# Use this in automation scripts to identify failures early.
# Especially useful in DevOps scripts and CI/CD pipelines.

set -euxo pipefail


# ------------------------------------------------------------
# STEP 2: SET NON-INTERACTIVE PACKAGE INSTALLATION
# ------------------------------------------------------------

# Command: export DEBIAN_FRONTEND=noninteractive
#
# WHY:
# Prevents Ubuntu package installation from asking interactive
# configuration questions during execution.
#
# WHEN TO USE:
# Useful in automated installations, cloud-init and
# server provisioning scripts.

export DEBIAN_FRONTEND=noninteractive


# ------------------------------------------------------------
# STEP 3: DEFINE EBS AND JENKINS VARIABLES
# ------------------------------------------------------------

# EBS_DEVICE:
# Linux device name of the additional EBS volume.
#
# IMPORTANT:
# The device name can differ depending on the EC2 instance type.
#
# Example:
# /dev/xvdf       : Commonly used EC2 block device mapping.
# /dev/nvme1n1    : Possible Linux device name on Nitro instances.
#
# Run lsblk -f to identify the actual device.
#
# If the EBS volume has a partition, specify the partition
# instead, for example /dev/nvme1n1p1.

EBS_DEVICE="/dev/xvdf"


# JENKINS_HOME_DIR:
# Directory where Jenkins stores all its application data.

JENKINS_HOME_DIR="/var/lib/jenkins"


# TEMP_MOUNT_DIR:
# Temporary location used to prepare the EBS volume
# and migrate existing Jenkins data safely.

TEMP_MOUNT_DIR="/mnt/jenkins-ebs"


# FORMAT_EBS:
# false = Do not format the volume automatically.
# true  = Format the volume as ext4 if it has no filesystem.
#
# IMPORTANT:
# Change to true ONLY after verifying that EBS_DEVICE
# points to the correct, empty EBS volume.
#
# Formatting destroys existing data on the selected device.

FORMAT_EBS="false"


# ------------------------------------------------------------
# STEP 4: VERIFY EBS DEVICE
# ------------------------------------------------------------

# Command: lsblk -f
#
# WHY:
# Displays attached block devices, partitions and filesystems.
#
# WHEN TO USE:
# Use this to identify the additional EBS volume attached
# to your EC2 instance.
#
# Example:
# lsblk -f
#
# After identifying the correct device, update EBS_DEVICE
# in this script.

lsblk -f


# Command: test -b "$EBS_DEVICE"
#
# WHY:
# Checks whether the specified path is a block device.
#
# -b:
# Returns success if the specified file is a block device.
#
# WHEN TO USE:
# Use this before formatting or mounting a disk to ensure
# the specified device actually exists.

if [[ ! -b "$EBS_DEVICE" ]]; then
    echo "ERROR: EBS device $EBS_DEVICE does not exist."
    echo "Run lsblk -f and update EBS_DEVICE."
    exit 1
fi


# ------------------------------------------------------------
# STEP 5: UPDATE UBUNTU PACKAGE INFORMATION
# ------------------------------------------------------------

# Command: apt update
#
# WHY:
# Downloads the latest package information from configured
# Ubuntu repositories.
#
# IMPORTANT:
# This does not upgrade installed applications.
#
# WHEN TO USE:
# Run before installing packages.

sudo apt update


# ------------------------------------------------------------
# STEP 6: INSTALL REQUIRED UTILITIES AND JAVA
# ------------------------------------------------------------

# Command:
# apt install -y wget git fontconfig openjdk-21-jre rsync
#
# WHY:
#
# wget:
# Downloads files from URLs.
#
# git:
# Allows Jenkins to retrieve source code from repositories.
#
# fontconfig:
# Provides font configuration support required by Jenkins.
#
# openjdk-21-jre:
# Provides Java 21 runtime required to execute Jenkins.
#
# rsync:
# Copies existing Jenkins data to the new EBS volume
# while preserving file permissions and ownership.
#
# -y:
# Automatically confirms installation prompts.
#
# WHEN TO USE:
# Install these dependencies when preparing an Ubuntu
# server for Jenkins installation.

sudo apt install -y wget git fontconfig openjdk-21-jre rsync


# ------------------------------------------------------------
# STEP 7: VERIFY JAVA INSTALLATION
# ------------------------------------------------------------

# Command: java -version
#
# WHY:
# Displays the installed Java version.
#
# Jenkins requires a supported Java runtime.
#
# EXPECTED:
# OpenJDK 21.

java -version


# ------------------------------------------------------------
# STEP 8: CREATE APT KEYRINGS DIRECTORY
# ------------------------------------------------------------

# Command: mkdir -p /etc/apt/keyrings
#
# WHY:
# Creates the directory used to store repository signing keys.
#
# -p:
# Creates parent directories if necessary.
# Does not fail if the directory already exists.
#
# WHEN TO USE:
# When adding third-party APT repositories.

sudo mkdir -p /etc/apt/keyrings


# ------------------------------------------------------------
# STEP 9: DOWNLOAD JENKINS REPOSITORY SIGNING KEY
# ------------------------------------------------------------

# Command: wget -O FILE URL
#
# WHY:
# Downloads the official Jenkins repository signing key.
#
# -O:
# Saves the downloaded file using the specified filename.
#
# WHEN TO USE:
# When adding a third-party repository that uses
# package signature verification.

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key


# ------------------------------------------------------------
# STEP 10: ADD JENKINS LTS APT REPOSITORY
# ------------------------------------------------------------

# Command:
# echo "deb [signed-by=...]" URL binary/ | sudo tee FILE
#
# WHY:
# Adds the official Jenkins LTS repository to Ubuntu.
#
# signed-by:
# Specifies the signing key used by APT to verify packages.
#
# tee:
# Writes repository configuration into a protected file.
#
# WHEN TO USE:
# When installing software from third-party repositories.

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null


# ------------------------------------------------------------
# STEP 11: DETECT EBS FILESYSTEM
# ------------------------------------------------------------

# Command:
# blkid -o value -s TYPE "$EBS_DEVICE"
#
# WHY:
# Identifies the filesystem type already present on the
# EBS volume.
#
# Examples:
# ext4
# xfs
#
# If the volume has no filesystem, blkid returns no value.
#
# WHEN TO USE:
# Before formatting or mounting a storage device.
#
# IMPORTANT:
# Never format a volume containing existing data.

FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE" || true)


# ------------------------------------------------------------
# STEP 12: FORMAT EBS VOLUME IF REQUIRED
# ------------------------------------------------------------

# Command: mkfs.ext4 "$EBS_DEVICE"
#
# WHY:
# Creates an ext4 filesystem on the EBS volume.
#
# A newly created EBS volume normally does not contain
# a filesystem.
#
# WHEN TO USE:
# Only when preparing a new, empty EBS volume.
#
# IMPORTANT:
# Formatting destroys existing data.
# FORMAT_EBS must be explicitly set to true.
#
# If a filesystem already exists, it will not be formatted.

if [[ -z "$FS_TYPE" ]]; then

    if [[ "$FORMAT_EBS" != "true" ]]; then
        echo "ERROR: No filesystem detected on $EBS_DEVICE."
        echo "Verify the device and set FORMAT_EBS=true"
        echo "only if this is a new, empty EBS volume."
        exit 1
    fi

    echo "Creating ext4 filesystem on $EBS_DEVICE..."

    sudo mkfs.ext4 "$EBS_DEVICE"

    FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE")

fi


# ------------------------------------------------------------
# STEP 13: VERIFY FILESYSTEM TYPE
# ------------------------------------------------------------

# WHY:
# This script uses ext4 in the mount configuration.
#
# If another filesystem already exists, stop instead of
# incorrectly mounting it as ext4.

if [[ "$FS_TYPE" != "ext4" ]]; then
    echo "ERROR: Expected ext4 filesystem."
    echo "Detected filesystem: $FS_TYPE"
    exit 1
fi


# ------------------------------------------------------------
# STEP 14: GET EBS VOLUME UUID
# ------------------------------------------------------------

# Command: blkid -s UUID -o value "$EBS_DEVICE"
#
# WHY:
# Retrieves the unique filesystem identifier.
#
# UUID:
# Universally Unique Identifier.
#
# WHEN TO USE:
# Use UUID in /etc/fstab instead of relying on device names.
#
# WHY UUID?
# Device names such as /dev/xvdf or /dev/nvme1n1
# can change after reboot or instance changes.
#
# UUID provides a more reliable way to identify the filesystem.

EBS_UUID=$(sudo blkid -s UUID -o value "$EBS_DEVICE")

if [[ -z "$EBS_UUID" ]]; then
    echo "ERROR: Unable to retrieve EBS filesystem UUID."
    exit 1
fi


# ------------------------------------------------------------
# STEP 15: STOP EXISTING JENKINS SERVICE IF INSTALLED
# ------------------------------------------------------------

# Command: systemctl stop jenkins
#
# WHY:
# If Jenkins is already installed, stop it before copying
# its data to the EBS volume.
#
# This prevents files from changing during migration.
#
# WHEN TO USE:
# Before migrating Jenkins home data or changing storage.

if systemctl list-unit-files jenkins.service --no-legend |
   grep -q '^jenkins.service'; then

    sudo systemctl stop jenkins || true

fi


# ------------------------------------------------------------
# STEP 16: PREPARE TEMPORARY EBS MOUNT
# ------------------------------------------------------------

# Command: mkdir -p "$TEMP_MOUNT_DIR"
#
# WHY:
# Creates a temporary directory where the EBS volume
# will be mounted before moving Jenkins data.
#
# WHEN TO USE:
# When preparing a new storage device or migrating data.

sudo mkdir -p "$TEMP_MOUNT_DIR"


# ------------------------------------------------------------
# STEP 17: MOUNT EBS TEMPORARILY AND MIGRATE JENKINS DATA
# ------------------------------------------------------------

# WHY:
# If Jenkins already exists on the root volume,
# mounting an empty EBS volume directly over /var/lib/jenkins
# would hide the existing data.
#
# Therefore:
# 1. Mount EBS temporarily.
# 2. Check whether existing Jenkins data is present.
# 3. Copy existing data to EBS using rsync.
# 4. Unmount the temporary location.
#
# rsync -aHAX --numeric-ids:
#
# -a : Archive mode; preserves permissions, ownership,
#      timestamps and directory structure.
# -H : Preserves hard links.
# -A : Preserves ACLs.
# -X : Preserves extended attributes.
# --numeric-ids : Preserves numeric user and group IDs.
#
# WHEN TO USE:
# When migrating application data between storage volumes.

if mountpoint -q "$JENKINS_HOME_DIR"; then

    CURRENT_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

    if [[ "$CURRENT_UUID" != "$EBS_UUID" ]]; then
        echo "ERROR: Jenkins home is already mounted from another volume."
        exit 1
    fi

    echo "Correct EBS volume is already mounted."

else

    sudo mount "$EBS_DEVICE" "$TEMP_MOUNT_DIR"

    SOURCE_HAS_DATA=false
    DESTINATION_HAS_DATA=false

    if [[ -d "$JENKINS_HOME_DIR" ]] &&
       [[ -n "$(sudo find "$JENKINS_HOME_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        SOURCE_HAS_DATA=true
    fi

    if [[ -n "$(sudo find "$TEMP_MOUNT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        DESTINATION_HAS_DATA=true
    fi

    if [[ "$SOURCE_HAS_DATA" == "true" ]] &&
       [[ "$DESTINATION_HAS_DATA" == "true" ]]; then

        echo "ERROR: Both Jenkins home and EBS contain data."
        echo "Manual verification is required before migration."

        sudo umount "$TEMP_MOUNT_DIR"
        exit 1

    fi

    if [[ "$SOURCE_HAS_DATA" == "true" ]] &&
       [[ "$DESTINATION_HAS_DATA" == "false" ]]; then

        echo "Migrating existing Jenkins data to EBS..."

        sudo rsync -aHAX --numeric-ids \
          "$JENKINS_HOME_DIR/" "$TEMP_MOUNT_DIR/"

    fi

    sudo umount "$TEMP_MOUNT_DIR"

    # --------------------------------------------------------
    # STEP 18: MOUNT EBS AT JENKINS HOME DIRECTORY
    # --------------------------------------------------------

    # Command:
    # mount "$EBS_DEVICE" "$JENKINS_HOME_DIR"
    #
    # WHY:
    # Mounts the separate EBS volume directly at the Jenkins
    # home directory.
    #
    # From now on, Jenkins data will be stored on EBS.
    #
    # WHEN TO USE:
    # When configuring persistent application storage.

    sudo mkdir -p "$JENKINS_HOME_DIR"

    sudo mount "$EBS_DEVICE" "$JENKINS_HOME_DIR"

fi


# ------------------------------------------------------------
# STEP 19: CONFIGURE AUTOMATIC EBS MOUNT AT BOOT
# ------------------------------------------------------------

# File: /etc/fstab
#
# WHY:
# Ubuntu reads /etc/fstab during startup to identify
# filesystems that should be mounted automatically.
#
# UUID:
# Identifies the EBS filesystem.
#
# /var/lib/jenkins:
# Jenkins home directory.
#
# ext4:
# Filesystem type.
#
# defaults:
# Uses standard mount options.
#
# nofail:
# Allows the system to continue booting if the volume
# is unavailable.
#
# 0:
# Disables dump backup.
#
# 2:
# Filesystem check order.
#
# WHEN TO USE:
# Whenever a separate disk must be mounted automatically
# after a server reboot.

if ! grep -qE "^[[:space:]]*UUID=${EBS_UUID}[[:space:]]+${JENKINS_HOME_DIR}[[:space:]]" /etc/fstab; then

    if grep -qE "[[:space:]]${JENKINS_HOME_DIR}[[:space:]]" /etc/fstab; then
        echo "ERROR: An existing fstab entry uses $JENKINS_HOME_DIR."
        echo "Inspect /etc/fstab before continuing."
        exit 1
    fi

    echo "UUID=${EBS_UUID} ${JENKINS_HOME_DIR} ext4 defaults,nofail 0 2" | \
      sudo tee -a /etc/fstab

fi


# ------------------------------------------------------------
# STEP 20: VERIFY EBS MOUNT
# ------------------------------------------------------------

# Command: findmnt "$JENKINS_HOME_DIR"
#
# WHY:
# Displays the filesystem mounted at Jenkins home.
#
# WHEN TO USE:
# After mounting a disk or troubleshooting storage issues.

sudo findmnt "$JENKINS_HOME_DIR"


# ------------------------------------------------------------
# STEP 21: REFRESH PACKAGE INFORMATION
# ------------------------------------------------------------

# Command: apt update
#
# WHY:
# Refreshes package information after adding the Jenkins
# repository.
#
# WHEN TO USE:
# After adding or modifying APT repositories.

sudo apt update


# ------------------------------------------------------------
# STEP 22: INSTALL JENKINS
# ------------------------------------------------------------

# Command: apt install -y jenkins
#
# WHY:
# Installs Jenkins from the official Jenkins LTS repository.
#
# IMPORTANT:
# EBS is already mounted at /var/lib/jenkins.
#
# Therefore, Jenkins will use the separate EBS volume
# for its home directory when it starts.
#
# WHEN TO USE:
# When installing Jenkins on Ubuntu.

sudo apt install -y jenkins


# ------------------------------------------------------------
# STEP 23: SET JENKINS DIRECTORY OWNERSHIP
# ------------------------------------------------------------

# Command: chown -R jenkins:jenkins /var/lib/jenkins
#
# WHY:
# Jenkins runs under the dedicated Linux user named jenkins.
#
# The Jenkins user must have permission to read and write
# its home directory.
#
# chown:
# Changes file ownership.
#
# -R:
# Applies ownership changes recursively.
#
# jenkins:jenkins:
# Sets both owner and group to jenkins.
#
# WHEN TO USE:
# After migrating Jenkins data or changing Jenkins storage.

sudo chown -R jenkins:jenkins "$JENKINS_HOME_DIR"


# ------------------------------------------------------------
# STEP 24: RELOAD SYSTEMD CONFIGURATION
# ------------------------------------------------------------

# Command: systemctl daemon-reload
#
# WHY:
# Reloads systemd unit configuration.
#
# Useful after changing service or mount configuration.
#
# WHEN TO USE:
# After modifying systemd service files or mount settings.

sudo systemctl daemon-reload


# ------------------------------------------------------------
# STEP 25: ENABLE JENKINS AT SYSTEM STARTUP
# ------------------------------------------------------------

# Command: systemctl enable jenkins
#
# WHY:
# Configures Jenkins to start automatically after
# EC2 instance reboot.
#
# WHEN TO USE:
# For services that must automatically start at boot.

sudo systemctl enable jenkins


# ------------------------------------------------------------
# STEP 26: START JENKINS SERVICE
# ------------------------------------------------------------

# Command: systemctl start jenkins
#
# WHY:
# Starts Jenkins immediately.
#
# WHEN TO USE:
# After installation or when a service needs to be started.

sudo systemctl start jenkins


# ------------------------------------------------------------
# STEP 27: VERIFY JENKINS SERVICE STATUS
# ------------------------------------------------------------

# Command: systemctl status jenkins --no-pager
#
# WHY:
# Checks whether Jenkins is running successfully.
#
# EXPECTED:
# Active: active (running)

sudo systemctl status jenkins --no-pager


# ------------------------------------------------------------
# STEP 28: VERIFY JENKINS SERVICE IS ACTIVE
# ------------------------------------------------------------

# Command: systemctl is-active jenkins
#
# WHY:
# Returns the current Jenkins service state.
#
# EXPECTED OUTPUT:
# active

sudo systemctl is-active jenkins


# ------------------------------------------------------------
# STEP 29: VERIFY EBS IS MOUNTED
# ------------------------------------------------------------

# Command: mountpoint -q /var/lib/jenkins
#
# WHY:
# Verifies that Jenkins home is an actual mount point.
#
# This helps ensure Jenkins is using the separate EBS
# volume rather than the EC2 root filesystem.
#
# WHEN TO USE:
# After mounting EBS and during storage troubleshooting.

if ! mountpoint -q "$JENKINS_HOME_DIR"; then
    echo "ERROR: Jenkins home is not mounted on EBS."
    exit 1
fi

MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then
    echo "ERROR: Jenkins home is mounted from an unexpected volume."
    exit 1
fi


# ------------------------------------------------------------
# STEP 30: DISPLAY INSTALLED JENKINS VERSION
# ------------------------------------------------------------

# Command: dpkg-query -W -f='${Version}\n' jenkins
#
# WHY:
# Displays the installed Jenkins package version.
#
# WHEN TO USE:
# To verify software versions after installation.

JENKINS_VERSION=$(dpkg-query -W -f='${Version}' jenkins)


# ============================================================
# JENKINS INSTALLATION COMPLETED SUCCESSFULLY
# ============================================================

echo "============================================================"
echo "Jenkins installation completed successfully."
echo "============================================================"
echo "Jenkins version : $JENKINS_VERSION"
echo "Java version    : $(java -version 2>&1 | head -n 1)"
echo "Jenkins status  : $(systemctl is-active jenkins)"
echo "EBS device      : $EBS_DEVICE"
echo "EBS UUID        : $EBS_UUID"
echo "Jenkins home    : $JENKINS_HOME_DIR"
echo "Filesystem      : $FS_TYPE"
echo "EBS mount       : VERIFIED"
echo "Jenkins port    : 8080"
echo "============================================================"
