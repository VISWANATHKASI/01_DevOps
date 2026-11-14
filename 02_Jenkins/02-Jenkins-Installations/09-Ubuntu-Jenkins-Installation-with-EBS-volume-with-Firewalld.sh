
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


# ------------------------------------------------------------
# STEP 1: ENABLE BASH STRICT MODE
# ------------------------------------------------------------

set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive


# ------------------------------------------------------------
# STEP 2: DEFINE CONFIGURATION VARIABLES
# ------------------------------------------------------------

# EBS CONFIGURATION

EBS_DEVICE="/dev/nvme1n1"

JENKINS_HOME_DIR="/var/lib/jenkins"

TEMP_MOUNT_DIR="/mnt/jenkins-ebs"

FORMAT_EBS="false"


# JENKINS NETWORK CONFIGURATION

JENKINS_PORT=8080

# Jenkins listens on all network interfaces.
# Access is restricted through firewalld and AWS Security Groups.

JENKINS_LISTEN_ADDRESS="0.0.0.0"


# JENKINS WEB UI ACCESS

JENKINS_ACCESS_CIDR="172.31.0.0/16"


# JENKINS AGENT CONFIGURATION

JENKINS_AGENT_PORT=50000

JENKINS_AGENT_CIDR="172.31.0.0/16"


# ------------------------------------------------------------
# STEP 3: VERIFY EBS DEVICE
# ------------------------------------------------------------

lsblk -f

if [[ ! -b "$EBS_DEVICE" ]]; then
    echo "ERROR: EBS device $EBS_DEVICE does not exist."
    exit 1
fi

EBS_DEVICE=$(readlink -f "$EBS_DEVICE")

echo "Selected EBS device: $EBS_DEVICE"


# ------------------------------------------------------------
# STEP 4: VERIFY EBS IS NOT THE ROOT DISK
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
# STEP 5: CHECK WHETHER EBS IS ALREADY MOUNTED
# ------------------------------------------------------------

EBS_MOUNT_INFO=$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE")

if [[ -n "$(echo "$EBS_MOUNT_INFO" | grep -v '^[[:space:]]*$' || true)" ]]; then

    echo "EBS mount information:"
    echo "$EBS_MOUNT_INFO"

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

sudo apt update


# ------------------------------------------------------------
# STEP 7: INSTALL REQUIRED UTILITIES, JAVA AND FIREWALL
# ------------------------------------------------------------

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

java -version


# ------------------------------------------------------------
# STEP 9: CREATE APT KEYRINGS DIRECTORY
# ------------------------------------------------------------

sudo mkdir -p /etc/apt/keyrings


# ------------------------------------------------------------
# STEP 10: DOWNLOAD JENKINS REPOSITORY SIGNING KEY
# ------------------------------------------------------------

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key


# ------------------------------------------------------------
# STEP 11: ADD JENKINS LTS REPOSITORY
# ------------------------------------------------------------

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | \
    sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null


# ------------------------------------------------------------
# STEP 12: DETECT EBS FILESYSTEM
# ------------------------------------------------------------

FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE" || true)

echo "Detected filesystem: ${FS_TYPE:-NONE}"


# ------------------------------------------------------------
# STEP 13: FORMAT EBS ONLY WHEN EXPLICITLY ALLOWED
# ------------------------------------------------------------

if [[ -z "$FS_TYPE" ]]; then

    if [[ "$FORMAT_EBS" != "true" ]]; then

        echo "ERROR: No filesystem detected on $EBS_DEVICE."
        echo "Set FORMAT_EBS=true only after verifying the volume."
        exit 1

    fi

    DEVICE_COUNT=$(lsblk -nrpo NAME "$EBS_DEVICE" | wc -l)

    if [[ "$DEVICE_COUNT" -ne 1 ]]; then
        echo "ERROR: EBS device contains partitions."
        echo "Refusing automatic formatting."
        exit 1
    fi

    EXISTING_SIGNATURES=$(sudo wipefs -n "$EBS_DEVICE" || true)

    if [[ -n "$EXISTING_SIGNATURES" ]]; then
        echo "ERROR: Existing disk signatures detected."
        echo "$EXISTING_SIGNATURES"
        echo "Refusing automatic formatting."
        exit 1
    fi

    if [[ -n "$(lsblk -nrpo MOUNTPOINTS "$EBS_DEVICE" | tr -d '[:space:]')" ]]; then
        echo "ERROR: EBS device is mounted."
        exit 1
    fi

    echo "Creating ext4 filesystem on $EBS_DEVICE..."

    sudo mkfs.ext4 "$EBS_DEVICE"

    FS_TYPE=$(sudo blkid -o value -s TYPE "$EBS_DEVICE")

fi


# ------------------------------------------------------------
# STEP 14: VERIFY FILESYSTEM TYPE
# ------------------------------------------------------------

if [[ "$FS_TYPE" != "ext4" ]]; then

    echo "ERROR: Expected ext4 filesystem."
    echo "Detected filesystem: $FS_TYPE"

    exit 1

fi


# ------------------------------------------------------------
# STEP 15: GET EBS UUID
# ------------------------------------------------------------

EBS_UUID=$(sudo blkid -s UUID -o value "$EBS_DEVICE")

if [[ -z "$EBS_UUID" ]]; then
    echo "ERROR: Unable to retrieve EBS UUID."
    exit 1
fi

echo "EBS UUID: $EBS_UUID"


# ------------------------------------------------------------
# STEP 16: STOP EXISTING JENKINS SERVICE
# ------------------------------------------------------------

if systemctl list-unit-files jenkins.service --no-legend |
    grep -q '^jenkins.service'; then

    sudo systemctl stop jenkins || true

fi


# ------------------------------------------------------------
# STEP 17: PREPARE TEMPORARY MOUNT DIRECTORY
# ------------------------------------------------------------

sudo mkdir -p "$TEMP_MOUNT_DIR"

if mountpoint -q "$TEMP_MOUNT_DIR"; then
    echo "ERROR: Temporary mount directory is already mounted."
    exit 1
fi


# ------------------------------------------------------------
# STEP 18: MOUNT EBS TEMPORARILY AND VERIFY
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
    # STEP 19: DETECT SOURCE AND DESTINATION DATA
    # --------------------------------------------------------

    SOURCE_HAS_DATA=false
    DESTINATION_HAS_DATA=false

    if [[ -d "$JENKINS_HOME_DIR" ]] &&
       [[ -n "$(sudo find "$JENKINS_HOME_DIR" \
           -mindepth 1 -maxdepth 1 -print -quit)" ]]; then

        SOURCE_HAS_DATA=true

    fi


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

    sudo umount "$TEMP_MOUNT_DIR"


    # --------------------------------------------------------
    # STEP 23: MOUNT EBS AT JENKINS HOME
    # --------------------------------------------------------

    sudo mkdir -p "$JENKINS_HOME_DIR"

    sudo mount "$EBS_DEVICE" "$JENKINS_HOME_DIR"

fi


# ------------------------------------------------------------
# STEP 24: CONFIGURE AUTOMATIC EBS MOUNT AT BOOT
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
    exit 1

elif [[ "$FSTAB_CHECK" == "MISSING" ]]; then

    echo "UUID=$EBS_UUID $JENKINS_HOME_DIR ext4 defaults,nofail 0 2" | \
        sudo tee -a /etc/fstab

fi


# ------------------------------------------------------------
# STEP 25: VERIFY EBS MOUNT
# ------------------------------------------------------------

sudo findmnt "$JENKINS_HOME_DIR"

MOUNTED_UUID=$(findmnt -n -o UUID --target "$JENKINS_HOME_DIR")

if [[ "$MOUNTED_UUID" != "$EBS_UUID" ]]; then

    echo "ERROR: Jenkins home is mounted from an unexpected volume."
    exit 1

fi

echo "EBS mount verified successfully."


# ------------------------------------------------------------
# STEP 26: INSTALL JENKINS
# ------------------------------------------------------------

sudo apt update

sudo apt install -y jenkins


# ------------------------------------------------------------
# STEP 27: SET JENKINS HOME OWNERSHIP AND PERMISSIONS
# ------------------------------------------------------------

sudo chown -R jenkins:jenkins "$JENKINS_HOME_DIR"

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

sudo systemctl enable --now firewalld

sudo firewall-cmd --state


# ------------------------------------------------------------
# 28.2: DETECT ACTIVE NETWORK ZONE
# ------------------------------------------------------------

DEFAULT_INTERFACE=$(ip -o route show default | awk '{print $5; exit}')

if [[ -z "$DEFAULT_INTERFACE" ]]; then
    echo "ERROR: Unable to detect default network interface."
    exit 1
fi

ACTIVE_ZONE=$(sudo firewall-cmd \
    --get-zone-of-interface="$DEFAULT_INTERFACE" 2>/dev/null || true)

if [[ -z "$ACTIVE_ZONE" || "$ACTIVE_ZONE" == "no zone" ]]; then
    ACTIVE_ZONE=$(sudo firewall-cmd --get-default-zone)
fi

echo "Network interface : $DEFAULT_INTERFACE"
echo "Firewall zone     : $ACTIVE_ZONE"


# ------------------------------------------------------------
# 28.3: CONFIGURE JENKINS WEB UI ACCESS
# ------------------------------------------------------------

echo "Allowing Jenkins UI access..."

JENKINS_UI_RULE="rule family=\"ipv4\" source address=\"${JENKINS_ACCESS_CIDR}\" port port=\"${JENKINS_PORT}\" protocol=\"tcp\" accept"

sudo firewall-cmd \
    --permanent \
    --zone="$ACTIVE_ZONE" \
    --add-rich-rule="$JENKINS_UI_RULE"


# ------------------------------------------------------------
# 28.4: CONFIGURE JENKINS AGENT ACCESS
# ------------------------------------------------------------

echo "Allowing Jenkins Agent access..."

JENKINS_AGENT_RULE="rule family=\"ipv4\" source address=\"${JENKINS_AGENT_CIDR}\" port port=\"${JENKINS_AGENT_PORT}\" protocol=\"tcp\" accept"

sudo firewall-cmd \
    --permanent \
    --zone="$ACTIVE_ZONE" \
    --add-rich-rule="$JENKINS_AGENT_RULE"


# ------------------------------------------------------------
# 28.5: RELOAD FIREWALL
# ------------------------------------------------------------

sudo firewall-cmd --reload


# ------------------------------------------------------------
# 28.6: VERIFY FIREWALL RULES
# ------------------------------------------------------------

sudo firewall-cmd --zone="$ACTIVE_ZONE" --list-all

sudo firewall-cmd \
    --zone="$ACTIVE_ZONE" \
    --query-rich-rule="$JENKINS_UI_RULE"

sudo firewall-cmd \
    --zone="$ACTIVE_ZONE" \
    --query-rich-rule="$JENKINS_AGENT_RULE"

echo "Jenkins firewall configuration completed."


# ------------------------------------------------------------
# STEP 29: ENABLE AND START JENKINS
# ------------------------------------------------------------

sudo systemctl daemon-reload

sudo systemctl enable jenkins

sudo systemctl start jenkins


# ------------------------------------------------------------
# STEP 30: VERIFY JENKINS SERVICE
# ------------------------------------------------------------

sudo systemctl status jenkins --no-pager

JENKINS_STATUS=$(systemctl is-active jenkins)

if [[ "$JENKINS_STATUS" != "active" ]]; then
    echo "ERROR: Jenkins service is not active."
    exit 1
fi


# ------------------------------------------------------------
# STEP 31: VERIFY EBS MOUNT
# ------------------------------------------------------------

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
# STEP 32: VERIFY JENKINS PORT
# ------------------------------------------------------------

if ! sudo ss -lntp | grep -q ":${JENKINS_PORT} "; then
    echo "ERROR: Jenkins port $JENKINS_PORT is not listening."
    exit 1
fi


# ------------------------------------------------------------
# STEP 33: COLLECT INSTALLATION INFORMATION
# ------------------------------------------------------------

JENKINS_VERSION=$(dpkg-query -W -f='${Version}' jenkins)

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
