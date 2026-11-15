
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
# Jenkins Port     : 8080
#
# SUPPORTED SCENARIOS
#
# 1. EXISTING JENKINS SERVER
#    - Jenkins is already installed.
#    - Existing Jenkins data is in /var/lib/jenkins.
#    - Script stops Jenkins.
#    - Copies existing data to the empty EBS volume.
#    - Mounts EBS at /var/lib/jenkins.
#    - Starts Jenkins again.
#
# 2. NEW UBUNTU SERVER
#    - Jenkins is not installed.
#    - EBS volume is empty.
#    - Script mounts EBS at /var/lib/jenkins first.
#    - Installs Jenkins afterwards.
#    - Jenkins creates its data directly on EBS.
#
# SAFETY
#
# - Existing EBS data is never automatically overwritten.
# - Existing EBS data causes the script to stop for verification.
# - The script does not automatically format an EBS volume.
# - The EBS volume is identified using its stable by-id path.
#
# ============================================================


# ============================================================
# 01. CONFIGURATION
# ============================================================

# Replace this placeholder with your actual EBS by-id path.
EBS_DEVICE_ID="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_volXXXXXXXX"

# Keep false for an existing volume.
# Set true ONLY when you intentionally want to format a new,
# empty EBS volume.
FORMAT_EBS="false"

# Jenkins home directory.
JENKINS_HOME_DIR="/var/lib/jenkins"

# Temporary mount directory used during migration.
TEMP_MOUNT_DIR="/mnt/jenkins-ebs"

# Jenkins web interface port.
JENKINS_PORT="8080"

# ============================================================
# 02. SCRIPT SAFETY SETTINGS
# ============================================================

# -e  : Stop when a command fails.
# -u  : Stop when an undefined variable is used.
# -o pipefail : Detect failures inside command pipelines.
set -Eeuo pipefail

# Track whether this script mounted the EBS volume temporarily.
TEMP_MOUNTED_BY_SCRIPT="false"

# Print a message with a timestamp.
log() {
    echo
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Stop the script with an error message.
die() {
    echo
    echo "ERROR: $1"
    exit 1
}

# Remove only the temporary mount created by this script.
# The final Jenkins EBS mount must remain mounted.
cleanup() {
    if [[ "$TEMP_MOUNTED_BY_SCRIPT" == "true" ]] &&
       mountpoint -q "$TEMP_MOUNT_DIR"; then

        log "Cleaning up temporary EBS mount."

        umount "$TEMP_MOUNT_DIR" || true
    fi
}

trap cleanup EXIT


# ============================================================
# 03. CHECK ROOT PRIVILEGES
# ============================================================

# WHY:
# The script modifies system directories, installs packages,
# mounts disks and changes file ownership.
#
# WHEN:
# Run this script with root privileges.

if [[ "$EUID" -ne 0 ]]; then
    die "Run this script as root: sudo bash jenkins-ebs-install.sh"
fi


# ============================================================
# 04. CHECK OPERATING SYSTEM
# ============================================================

# WHY:
# This script uses Ubuntu APT package management and the
# Jenkins Debian repository.

source /etc/os-release

if [[ "$ID" != "ubuntu" || "$VERSION_ID" != "24.04" ]]; then
    die "This script is designed for Ubuntu 24.04 LTS."
fi

log "Ubuntu 24.04 LTS detected."


# ============================================================
# 05. VERIFY EBS DEVICE PATH
# ============================================================

# WHY:
# AWS Nitro instances can expose EBS volumes using NVMe names.
# Names such as /dev/nvme1n1 can change after a reboot.
#
# The /dev/disk/by-id path provides a stable device identifier.

if [[ ! -e "$EBS_DEVICE_ID" ]]; then
    die "EBS device path not found: $EBS_DEVICE_ID"
fi

EBS_DEVICE=$(readlink -f "$EBS_DEVICE_ID")

if [[ ! -b "$EBS_DEVICE" ]]; then
    die "The selected EBS path is not a block device."
fi

log "EBS device resolved to: $EBS_DEVICE"


# ============================================================
# 06. PROTECT THE ROOT DISK
# ============================================================

# WHY:
# We must never format or use the operating system's root disk
# as the Jenkins EBS volume.

ROOT_SOURCE=$(findmnt -n -o SOURCE /)
ROOT_DEVICE=$(readlink -f "$ROOT_SOURCE")

if [[ ! -b "$ROOT_DEVICE" ]]; then
    die "Unable to identify the root block device safely."
fi

ROOT_ANCESTORS=$(lsblk -s -nrpo MAJ:MIN "$ROOT_DEVICE")
EBS_MAJ_MIN=$(lsblk -dnro MAJ:MIN "$EBS_DEVICE")

if grep -Fxq "$EBS_MAJ_MIN" <<< "$ROOT_ANCESTORS"; then
    die "The selected EBS device belongs to the root disk. Stopping."
fi

log "Root disk protection check passed."


# ============================================================
# 07. CHECK EBS DEVICE STRUCTURE
# ============================================================

# WHY:
# This script expects an ext4 filesystem directly on the EBS
# volume. It does not automatically handle partitioned volumes.

EBS_TYPE=$(lsblk -dnro TYPE "$EBS_DEVICE")

if [[ "$EBS_TYPE" != "disk" ]]; then
    die "Expected a whole disk device. Found: $EBS_TYPE"
fi

mapfile -t EBS_TREE < <(lsblk -nrpo NAME "$EBS_DEVICE")

if [[ "${#EBS_TREE[@]}" -ne 1 ]]; then
    die "EBS contains partitions or child devices. This script expects a whole-volume filesystem."
fi


# ============================================================
# 08. CHECK EXISTING EBS MOUNTS
# ============================================================

# WHY:
# The EBS volume must not be mounted at an unrelated location.

while IFS= read -r CURRENT_MOUNT; do

    [[ -z "$CURRENT_MOUNT" ]] && continue

    if [[ "$CURRENT_MOUNT" != "$JENKINS_HOME_DIR" ]]; then
        die "EBS is already mounted at $CURRENT_MOUNT"
    fi

done < <(lsblk -nrpo MOUNTPOINT "$EBS_DEVICE")


# ============================================================
# 09. CHECK EBS FILESYSTEM
# ============================================================

# WHY:
# Jenkins data will be stored on an ext4 filesystem.

FS_TYPE=$(blkid -o value -s TYPE "$EBS_DEVICE" || true)

if [[ -z "$FS_TYPE" ]]; then

    log "No filesystem detected on EBS."

    if [[ "$FORMAT_EBS" != "true" ]]; then
        die "EBS has no filesystem. Verify the volume before enabling FORMAT_EBS=true."
    fi

    # WHY:
    # wipefs checks for existing filesystem or partition signatures.
    # Formatting is permitted only when no signatures are detected.

    WIPEFS_OUTPUT=$(wipefs -n "$EBS_DEVICE" || true)

    if [[ -n "$WIPEFS_OUTPUT" ]]; then
        die "Existing disk signatures detected. Refusing to format EBS."
    fi

    log "Creating ext4 filesystem on the confirmed empty EBS volume."

    mkfs.ext4 "$EBS_DEVICE"

    FS_TYPE=$(blkid -o value -s TYPE "$EBS_DEVICE" || true)
fi

if [[ "$FS_TYPE" != "ext4" ]]; then
    die "Expected ext4 filesystem. Found: $FS_TYPE"
fi

EBS_UUID=$(blkid -s UUID -o value "$EBS_DEVICE")

if [[ -z "$EBS_UUID" ]]; then
    die "Unable to retrieve EBS filesystem UUID."
fi

log "EBS filesystem: $FS_TYPE"
log "EBS UUID: $EBS_UUID"


# ============================================================
# 10. DETECT EXISTING JENKINS INSTALLATION
# ============================================================

# WHY:
# We need to know whether Jenkins is already installed so that
# we can stop it before copying its data.

JENKINS_INSTALLED="false"

if dpkg-query -W -f='${Status}' jenkins 2>/dev/null |
   grep -q "install ok installed"; then

    JENKINS_INSTALLED="true"

fi

log "Jenkins already installed: $JENKINS_INSTALLED"


# ============================================================
# 11. STOP EXISTING JENKINS
# ============================================================

# WHY:
# Copying Jenkins data while Jenkins is running can result in
# inconsistent or incomplete application data.
#
# WHEN:
# This is required when Jenkins is already installed.

if [[ "$JENKINS_INSTALLED" == "true" ]]; then

    log "Stopping existing Jenkins service."

    systemctl stop jenkins

    if systemctl is-active --quiet jenkins; then
        die "Jenkins is still running. Cannot safely migrate its data."
    fi

fi


# ============================================================
# 12. CREATE JENKINS HOME DIRECTORY
# ============================================================

# WHY:
# On a fresh server, the Jenkins home directory may not exist.
# Create the mountpoint before mounting EBS.

mkdir -p "$JENKINS_HOME_DIR"


# ============================================================
# 13. CHECK WHETHER EBS IS ALREADY MOUNTED AT JENKINS HOME
# ============================================================

EBS_ALREADY_AT_HOME="false"

if mountpoint -q "$JENKINS_HOME_DIR"; then

    CURRENT_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

    if [[ "$CURRENT_UUID" != "$EBS_UUID" ]]; then
        die "$JENKINS_HOME_DIR is mounted from a different filesystem."
    fi

    EBS_ALREADY_AT_HOME="true"

    log "Correct EBS volume is already mounted at Jenkins home."

fi


# ============================================================
# 14. CHECK TEMPORARY MOUNT DIRECTORY
# ============================================================

# WHY:
# We temporarily mount EBS to inspect its contents and migrate
# existing Jenkins data before mounting it at Jenkins home.

mkdir -p "$TEMP_MOUNT_DIR"

if mountpoint -q "$TEMP_MOUNT_DIR"; then
    die "Temporary mount directory is already in use."
fi


# ============================================================
# 15. DEFINE DATA CHECK FUNCTION
# ============================================================

# WHY:
# An ext4 filesystem normally contains lost+found.
# We ignore that directory when checking whether EBS has data.

has_data() {

    find "$1" \
        -mindepth 1 \
        -maxdepth 1 \
        ! -name "lost+found" \
        -print -quit |
        grep -q .

}


# ============================================================
# 16. INSPECT AND MIGRATE DATA
# ============================================================

# If EBS is already mounted at Jenkins home, do not migrate
# anything. It is already the active Jenkins storage location.

if [[ "$EBS_ALREADY_AT_HOME" == "false" ]]; then

    log "Temporarily mounting EBS for inspection."

    mount "$EBS_DEVICE" "$TEMP_MOUNT_DIR"

    TEMP_MOUNTED_BY_SCRIPT="true"

    # Check whether Jenkins home currently contains data.
    SOURCE_HAS_DATA="false"

    if has_data "$JENKINS_HOME_DIR"; then
        SOURCE_HAS_DATA="true"
    fi

    # Check whether EBS already contains data.
    DESTINATION_HAS_DATA="false"

    if has_data "$TEMP_MOUNT_DIR"; then
        DESTINATION_HAS_DATA="true"
    fi


    # --------------------------------------------------------
    # 16.1 REFUSE AUTOMATIC MERGE OF EXISTING EBS DATA
    # --------------------------------------------------------

    # WHY:
    # Existing EBS data could belong to another Jenkins server.
    # Automatically merging two Jenkins homes is unsafe.

    if [[ "$DESTINATION_HAS_DATA" == "true" ]]; then

        die "EBS already contains data. Verify its contents and ownership before using this script."

    fi


    # --------------------------------------------------------
    # 16.2 MIGRATE EXISTING JENKINS DATA
    # --------------------------------------------------------

    if [[ "$SOURCE_HAS_DATA" == "true" ]]; then

        log "Existing Jenkins data detected. Starting migration to EBS."

        # WHY:
        # rsync -a preserves permissions, timestamps and symbolic links.
        # -H preserves hard links.
        # -A preserves ACLs.
        # -X preserves extended attributes.
        # --numeric-ids preserves numeric user and group IDs.

        rsync -aHAX --numeric-ids --info=progress2 \
            "$JENKINS_HOME_DIR/" \
            "$TEMP_MOUNT_DIR/"

        log "Existing Jenkins data copied to EBS."

    else

        log "No existing Jenkins data found. Fresh installation path selected."

    fi


    # --------------------------------------------------------
    # 16.3 UNMOUNT TEMPORARY EBS MOUNT
    # --------------------------------------------------------

    # WHY:
    # EBS must be unmounted from the temporary directory before
    # it can be mounted at /var/lib/jenkins.

    umount "$TEMP_MOUNT_DIR"

    TEMP_MOUNTED_BY_SCRIPT="false"

fi


# ============================================================
# 17. CONFIGURE /ETC/FSTAB
# ============================================================

# WHY:
# /etc/fstab makes the EBS volume mount automatically after
# an EC2 reboot.
#
# UUID is used instead of /dev/nvme1n1 because device names
# can change after reboot.

FSTAB_ENTRY="UUID=$EBS_UUID $JENKINS_HOME_DIR ext4 defaults,nofail,x-systemd.device-timeout=30 0 2"

# Check whether the correct entry already exists.
# Refuse duplicate or conflicting entries.

set +e

awk -v device="UUID=$EBS_UUID" -v target="$JENKINS_HOME_DIR" '
BEGIN {
    good=0
    conflict=0
}

$1 ~ /^#/ || NF < 3 {
    next
}

{
    if ($1 == device && $2 == target && $3 == "ext4") {
        good++
    }
    else if ($1 == device || $2 == target) {
        conflict++
    }
}

END {
    if (good == 1 && conflict == 0) {
        exit 0
    }
    else if (good == 0 && conflict == 0) {
        exit 1
    }
    else {
        exit 2
    }
}
' /etc/fstab

FSTAB_STATUS=$?

set -e

if [[ "$FSTAB_STATUS" -eq 0 ]]; then

    log "Correct EBS entry already exists in /etc/fstab."

elif [[ "$FSTAB_STATUS" -eq 1 ]]; then

    log "Adding EBS entry to /etc/fstab."

    echo "$FSTAB_ENTRY" >> /etc/fstab

else

    die "Conflicting or duplicate EBS entries found in /etc/fstab."

fi


# ============================================================
# 18. VALIDATE FSTAB CONFIGURATION
# ============================================================

# WHY:
# Invalid /etc/fstab entries can cause mount failures during boot.
# Validate the configuration before proceeding.

findmnt --verify --tab-file /etc/fstab

log "/etc/fstab validation completed."


# ============================================================
# 19. MOUNT EBS AT JENKINS HOME
# ============================================================

# WHY:
# This makes the EBS filesystem available at the standard
# Jenkins home directory.

if [[ "$EBS_ALREADY_AT_HOME" == "false" ]]; then

    log "Mounting EBS at $JENKINS_HOME_DIR."

    mount "$JENKINS_HOME_DIR"

fi

MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then
    die "EBS mount verification failed."
fi

log "EBS successfully mounted at Jenkins home."


# ============================================================
# 20. INSTALL REQUIRED LINUX PACKAGES
# ============================================================

# WHY:
# wget and curl download repository files.
# git is commonly required by Jenkins jobs.
# fontconfig and Java support Jenkins runtime requirements.
# rsync is used for data migration.
# e2fsprogs provides filesystem utilities.
# util-linux provides mount and disk utilities.

log "Updating Ubuntu package information."

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
    wget \
    curl \
    git \
    fontconfig \
    openjdk-21-jre \
    rsync \
    e2fsprogs \
    util-linux


# ============================================================
# 21. VERIFY JAVA INSTALLATION
# ============================================================

# WHY:
# Jenkins requires a supported Java runtime.
# This installation uses OpenJDK 21.

java -version

log "Java installation verified."


# ============================================================
# 22. ADD JENKINS GPG SIGNING KEY
# ============================================================

# WHY:
# APT uses the Jenkins signing key to verify packages downloaded
# from the official Jenkins repository.

wget -qO /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

chmod 644 /usr/share/keyrings/jenkins-keyring.asc


# ============================================================
# 23. ADD JENKINS LTS REPOSITORY
# ============================================================

# WHY:
# The official Jenkins repository provides Jenkins LTS packages.

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list


# ============================================================
# 24. UPDATE PACKAGE INFORMATION
# ============================================================

# WHY:
# APT must refresh its package index after adding the Jenkins
# repository so it can locate the Jenkins package.

apt-get update


# ============================================================
# 25. INSTALL JENKINS
# ============================================================

# WHY:
# On a fresh server, Jenkins is installed now.
#
# IMPORTANT:
# EBS was mounted at /var/lib/jenkins before this installation.
# Therefore, Jenkins creates its home directory on EBS.

log "Installing Jenkins LTS."

apt-get install -y jenkins


# ============================================================
# 26. STOP JENKINS BEFORE OWNERSHIP CONFIGURATION
# ============================================================

# WHY:
# Package installation may automatically start Jenkins.
# Stop it before changing ownership and permissions.

systemctl stop jenkins

if systemctl is-active --quiet jenkins; then
    die "Jenkins is still running. Cannot safely configure ownership."
fi


# ============================================================
# 27. VERIFY JENKINS USER
# ============================================================

# WHY:
# The Jenkins service runs using the jenkins Linux account.
# Its home directory must be accessible to this account.

if ! id jenkins >/dev/null 2>&1; then
    die "Jenkins Linux user was not created."
fi


# ============================================================
# 28. SET JENKINS HOME OWNERSHIP
# ============================================================

# WHY:
# Files copied from an existing server may have ownership that
# does not match the Jenkins service account.
#
# lost+found is intentionally excluded because it is an
# ext4 filesystem maintenance directory.

chown jenkins:jenkins "$JENKINS_HOME_DIR"

find "$JENKINS_HOME_DIR" \
    -mindepth 1 \
    -maxdepth 1 \
    ! -name "lost+found" \
    -exec chown -R jenkins:jenkins {} +


# ============================================================
# 29. CONFIGURE SYSTEMD MOUNT DEPENDENCY
# ============================================================

# WHY:
# Jenkins must not start before its EBS-backed home directory
# is available.
#
# RequiresMountsFor adds the required mount dependency to
# the Jenkins systemd service.

mkdir -p /etc/systemd/system/jenkins.service.d

cat > /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Unit]
RequiresMountsFor=$JENKINS_HOME_DIR
EOF


# ============================================================
# 30. RELOAD SYSTEMD CONFIGURATION
# ============================================================

# WHY:
# systemd must reload its configuration after creating or
# changing the Jenkins service override.

systemctl daemon-reload


# ============================================================
# 31. ENABLE JENKINS AT BOOT
# ============================================================

# WHY:
# Jenkins should start automatically when the EC2 instance
# boots.

systemctl enable jenkins


# ============================================================
# 32. START JENKINS
# ============================================================

# WHY:
# Restart Jenkins after the EBS mount, ownership and systemd
# dependency have been configured.

systemctl restart jenkins


# ============================================================
# 33. VERIFY JENKINS SERVICE
# ============================================================

# WHY:
# Confirm that Jenkins started successfully.

if ! systemctl is-active --quiet jenkins; then

    systemctl status jenkins --no-pager -l || true

    die "Jenkins service is not active."

fi

systemctl status jenkins --no-pager -l


# ============================================================
# 34. VERIFY JENKINS ENABLED STATUS
# ============================================================

# WHY:
# Confirm that Jenkins is configured to start automatically
# after a server reboot.

systemctl is-enabled jenkins


# ============================================================
# 35. VERIFY EBS MOUNT
# ============================================================

# WHY:
# Confirm that Jenkins home is actually using the intended
# EBS filesystem, not the EC2 root disk.

findmnt --target "$JENKINS_HOME_DIR"

FINAL_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

if [[ "$FINAL_UUID" != "$EBS_UUID" ]]; then
    die "Final EBS UUID verification failed."
fi


# ============================================================
# 36. VERIFY JENKINS PACKAGE VERSION
# ============================================================

# WHY:
# Display the installed Jenkins package version.

dpkg-query -W -f='Jenkins version: ${Version}\n' jenkins


# ============================================================
# 37. VERIFY JENKINS PORT
# ============================================================

# WHY:
# Jenkins normally listens on TCP port 8080.
# This checks whether a process is listening on that port.

if ss -lntH "sport = :$JENKINS_PORT" | grep -q .; then

    log "A process is listening on port $JENKINS_PORT."

else

    log "WARNING: Nothing is listening on port $JENKINS_PORT yet."
    log "Check Jenkins logs and service status."

fi


# ============================================================
# 38. FINAL SUMMARY
# ============================================================

echo
echo "============================================================"
echo " JENKINS INSTALLATION COMPLETED"
echo "============================================================"
echo
echo "Operating System : Ubuntu 24.04 LTS"
echo "Java             : OpenJDK 21"
echo "Jenkins          : $(dpkg-query -W -f='${Version}' jenkins)"
echo "Jenkins Home     : $JENKINS_HOME_DIR"
echo "EBS Device       : $EBS_DEVICE"
echo "EBS UUID         : $EBS_UUID"
echo "Filesystem       : $FS_TYPE"
echo "Jenkins Port     : $JENKINS_PORT"
echo
echo "Jenkins Service  : $(systemctl is-active jenkins)"
echo "Enabled at Boot  : $(systemctl is-enabled jenkins)"
echo
echo "EBS Mount:"
findmnt --target "$JENKINS_HOME_DIR"
echo
echo "============================================================"
echo " IMPORTANT: Verify Jenkins access through port 8080."
echo "============================================================"

