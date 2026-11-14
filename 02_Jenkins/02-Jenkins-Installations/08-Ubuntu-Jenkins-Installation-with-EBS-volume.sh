
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

set -euxo pipefail


# ------------------------------------------------------------
# STEP 2: NON-INTERACTIVE PACKAGE INSTALLATION
# ------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive


# ------------------------------------------------------------
# STEP 3: DEFINE VARIABLES
# ------------------------------------------------------------

EBS_DEVICE="/dev/xvdf"

JENKINS_HOME_DIR="/var/lib/jenkins"

TEMP_MOUNT_DIR="/mnt/jenkins-ebs"

# false = Never automatically format.
# true  = Format only if no filesystem or disk signatures exist.

FORMAT_EBS="false"


# ------------------------------------------------------------
# STEP 4: VERIFY EBS DEVICE
# ------------------------------------------------------------

lsblk -f

if [[ ! -b "$EBS_DEVICE" ]]; then
    echo "ERROR: EBS device $EBS_DEVICE does not exist."
    exit 1
fi

EBS_DEVICE=$(readlink -f "$EBS_DEVICE")

echo "Selected EBS device: $EBS_DEVICE"


# ------------------------------------------------------------
# STEP 5: VERIFY EBS IS NOT THE ROOT DISK
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# STEP 6: CHECK WHETHER EBS IS ALREADY MOUNTED
# ------------------------------------------------------------

EBS_MOUNT_INFO=$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE")

if [[ -n "$(echo "$EBS_MOUNT_INFO" | grep -v '^[[:space:]]*$' || true)" ]]; then

    echo "EBS mount information:"
    echo "$EBS_MOUNT_INFO"

    # Existing mount at Jenkins home is allowed.
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
# STEP 7: UPDATE UBUNTU PACKAGE INFORMATION
# ------------------------------------------------------------

sudo apt update


# ------------------------------------------------------------
# STEP 8: INSTALL REQUIRED UTILITIES AND JAVA
# ------------------------------------------------------------

sudo apt install -y \
    wget \
    git \
    fontconfig \
    openjdk-21-jre \
    rsync \
    e2fsprogs


# ------------------------------------------------------------
# STEP 9: VERIFY JAVA
# ------------------------------------------------------------

java -version


# ------------------------------------------------------------
# STEP 10: CREATE APT KEYRINGS DIRECTORY
# ------------------------------------------------------------

sudo mkdir -p /etc/apt/keyrings


# ------------------------------------------------------------
# STEP 11: DOWNLOAD JENKINS REPOSITORY SIGNING KEY
# ------------------------------------------------------------

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key


# ------------------------------------------------------------
# STEP 12: ADD JENKINS LTS REPOSITORY
# ------------------------------------------------------------

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | \
    sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null


# ------------------------------------------------------------
# STEP 13: DETECT EBS FILESYSTEM
# ------------------------------------------------------------

FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE" || true)

echo "Detected filesystem: ${FS_TYPE:-NONE}"


# ------------------------------------------------------------
# STEP 14: FORMAT EBS ONLY WHEN EXPLICITLY ALLOWED
# ------------------------------------------------------------

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

    # Check that the device has no existing signatures.
    EXISTING_SIGNATURES=$(sudo wipefs -n "$EBS_DEVICE" || true)

    if [[ -n "$EXISTING_SIGNATURES" ]]; then
        echo "ERROR: Existing disk signatures detected."
        echo "$EXISTING_SIGNATURES"
        echo "Refusing automatic formatting."
        exit 1
    fi

    # Check again that the device is not mounted.
    if [[ -n "$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE" | tr -d '[:space:]')" ]]; then
        echo "ERROR: EBS device is mounted."
        exit 1
    fi

    echo "Creating ext4 filesystem on $EBS_DEVICE..."

    sudo mkfs.ext4 "$EBS_DEVICE"

    FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE")

fi


# ------------------------------------------------------------
# STEP 15: VERIFY FILESYSTEM TYPE
# ------------------------------------------------------------

if [[ "$FS_TYPE" != "ext4" ]]; then

    echo "ERROR: Expected ext4 filesystem."
    echo "Detected filesystem: $FS_TYPE"

    exit 1

fi


# ------------------------------------------------------------
# STEP 16: GET EBS UUID
# ------------------------------------------------------------

EBS_UUID=$(sudo blkid -s UUID -o value "$EBS_DEVICE")

if [[ -z "$EBS_UUID" ]]; then
    echo "ERROR: Unable to retrieve EBS UUID."
    exit 1
fi

echo "EBS UUID: $EBS_UUID"


# ------------------------------------------------------------
# STEP 17: STOP EXISTING JENKINS SERVICE
# ------------------------------------------------------------

if systemctl list-unit-files jenkins.service --no-legend |
    grep -q '^jenkins.service'; then

    sudo systemctl stop jenkins || true

fi


# ------------------------------------------------------------
# STEP 18: PREPARE TEMPORARY MOUNT DIRECTORY
# ------------------------------------------------------------

sudo mkdir -p "$TEMP_MOUNT_DIR"

if mountpoint -q "$TEMP_MOUNT_DIR"; then
    echo "ERROR: Temporary mount directory is already mounted."
    exit 1
fi


# ------------------------------------------------------------
# STEP 19: MOUNT EBS TEMPORARILY AND VERIFY
# ------------------------------------------------------------

if mountpoint -q "$JENKINS_HOME_DIR"; then

    CURRENT_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

    if [[ "$CURRENT_UUID" != "$EBS_UUID" ]]; then
        echo "ERROR: Jenkins home is mounted from another volume."
        exit 1
    fi

    echo "Correct EBS volume is already mounted at Jenkins home."

else

    sudo mount "$EBS_DEVICE" "$TEMP_MOUNT_DIR"

    TEMP_UUID=$(findmnt -n -o UUID --target "$TEMP_MOUNT_DIR")

    if [[ "$TEMP_UUID" != "$EBS_UUID" ]]; then
        echo "ERROR: Temporary mount UUID verification failed."
        sudo umount "$TEMP_MOUNT_DIR"
        exit 1
    fi


    # --------------------------------------------------------
    # STEP 20: DETECT SOURCE AND DESTINATION DATA
    # --------------------------------------------------------

    SOURCE_HAS_DATA=false
    DESTINATION_HAS_DATA=false

    # Check existing Jenkins home.
    if [[ -d "$JENKINS_HOME_DIR" ]] &&
       [[ -n "$(sudo find "$JENKINS_HOME_DIR" \
           -mindepth 1 -maxdepth 1 -print -quit)" ]]; then

        SOURCE_HAS_DATA=true

    fi


    # Check EBS destination.
    # Ignore empty lost+found directory.
    # Do not ignore recovered files inside lost+found.

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
    # STEP 21: PREVENT DATA OVERWRITE
    # --------------------------------------------------------

    if [[ "$SOURCE_HAS_DATA" == "true" ]] &&
       [[ "$DESTINATION_HAS_DATA" == "true" ]]; then

        echo "ERROR: Both Jenkins home and EBS contain data."
        echo "Manual verification is required before migration."

        sudo umount "$TEMP_MOUNT_DIR"

        exit 1

    fi


    # --------------------------------------------------------
    # STEP 22: MIGRATE EXISTING JENKINS DATA
    # --------------------------------------------------------

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
    # STEP 23: UNMOUNT TEMPORARY EBS MOUNT
    # --------------------------------------------------------

    sudo umount "$TEMP_MOUNT_DIR"


    # --------------------------------------------------------
    # STEP 24: MOUNT EBS AT JENKINS HOME
    # --------------------------------------------------------

    sudo mkdir -p "$JENKINS_HOME_DIR"

    sudo mount "$EBS_DEVICE" "$JENKINS_HOME_DIR"

fi


# ------------------------------------------------------------
# STEP 25: CONFIGURE AUTOMATIC EBS MOUNT AT BOOT
# ------------------------------------------------------------

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

    echo "UUID=$EBS_UUID $JENKINS_HOME_DIR ext4 defaults,nofail 0 2" | \
        sudo tee -a /etc/fstab

fi


# ------------------------------------------------------------
# STEP 26: VERIFY EBS MOUNT
# ------------------------------------------------------------

sudo findmnt "$JENKINS_HOME_DIR"

MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then

    echo "ERROR: Jenkins home is mounted from an unexpected volume."
    exit 1

fi

echo "EBS mount verified successfully."


# ------------------------------------------------------------
# STEP 27: REFRESH PACKAGE INFORMATION
# ------------------------------------------------------------

sudo apt update


# ------------------------------------------------------------
# STEP 28: INSTALL JENKINS
# ------------------------------------------------------------

sudo apt install -y jenkins


# ------------------------------------------------------------
# STEP 29: SET OWNERSHIP AND START JENKINS
# ------------------------------------------------------------

sudo chown -R jenkins:jenkins "$JENKINS_HOME_DIR"

sudo systemctl daemon-reload

sudo systemctl enable jenkins

sudo systemctl start jenkins


# ------------------------------------------------------------
# STEP 30: VERIFY JENKINS AND EBS
# ------------------------------------------------------------

sudo systemctl status jenkins --no-pager

JENKINS_STATUS=$(systemctl is-active jenkins)

if [[ "$JENKINS_STATUS" != "active" ]]; then
    echo "ERROR: Jenkins service is not active."
    exit 1
fi

if ! mountpoint -q "$JENKINS_HOME_DIR"; then
    echo "ERROR: Jenkins home is not mounted."
    exit 1
fi

MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then
    echo "ERROR: EBS UUID verification failed."
    exit 1
fi

JENKINS_VERSION=$(dpkg-query -W -f='${Version}' jenkins)

JAVA_VERSION=$(java -version 2>&1 | head -n 1)


# ============================================================
# JENKINS INSTALLATION COMPLETED SUCCESSFULLY
# ============================================================

echo "============================================================"
echo "Jenkins installation completed successfully."
echo "============================================================"

echo "Jenkins version : $JENKINS_VERSION"
echo "Java version    : $JAVA_VERSION"
echo "Jenkins status  : $JENKINS_STATUS"
echo "EBS device      : $EBS_DEVICE"
echo "EBS UUID        : $EBS_UUID"
echo "Jenkins home    : $JENKINS_HOME_DIR"
echo "Filesystem      : $FS_TYPE"
echo "EBS mount       : VERIFIED"
echo "Jenkins port    : 8080"

echo "============================================================"
