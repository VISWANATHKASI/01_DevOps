#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt update -y
apt upgrade -y
apt install wget git -y
apt install fontconfig openjdk-21-jre -y
mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
apt update -y
apt install -y jenkins
echo "jenkins ALL=(root) NOPASSWD: /usr/bin/systemctl start jenkins, /usr/bin/systemctl stop jenkins, /usr/bin/systemctl restart jenkins, /usr/bin/systemctl status jenkins, /usr/bin/systemctl status jenkins --no-pager, /usr/bin/systemctl enable jenkins, /usr/bin/systemctl disable jenkins" > /etc/sudoers.d/jenkins-service
chmod 440 /etc/sudoers.d/jenkins-service
visudo -cf /etc/sudoers.d/jenkins-service
systemctl daemon-reload
sudo -u jenkins sudo /usr/bin/systemctl start jenkins
sudo -u jenkins sudo /usr/bin/systemctl enable jenkins
sudo -u jenkins sudo /usr/bin/systemctl status jenkins --no-pager


--------------------------------------------------------------------------------------------------

#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# Use 'lsblk' to find the device if /dev/xvdb doesn't exist (Nitro support)
EBS_DEVICE="/dev/nvme1n1"
JENKINS_HOME_DIR="/var/lib/jenkins"

apt update -y && apt upgrade -y
apt install wget git fontconfig openjdk-21-jre -y

# Setup Jenkins Repo
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Prepare the Volume BEFORE Installation
FE_TYPE=$(sudo blkid -o value -s TYPE ${EBS_DEVICE}) || true
if [ -z "$FE_TYPE" ]; then
    echo "Formatting EBS volume ${EBS_DEVICE}..."
    sudo mkfs -t ext4 ${EBS_DEVICE}
fi

sudo mkdir -p ${JENKINS_HOME_DIR}
sudo mount ${EBS_DEVICE} ${JENKINS_HOME_DIR}

# Add to fstab
EBS_UUID=$(sudo blkid -s UUID -o value ${EBS_DEVICE})
if ! grep -q "${EBS_UUID}" /etc/fstab; then
    echo "UUID=${EBS_UUID} ${JENKINS_HOME_DIR} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi

# Now Install Jenkins (It will install directly onto the mounted EBS volume)
apt update -y
apt install -y jenkins

# Ensure permissions are correct for the mount point
sudo chown -R jenkins:jenkins ${JENKINS_HOME_DIR}

echo "jenkins ALL=(root) NOPASSWD: /usr/bin/systemctl start jenkins, /usr/bin/systemctl stop jenkins, /usr/bin/systemctl restart jenkins, /usr/bin/systemctl status jenkins, /usr/bin/systemctl status jenkins --no-pager, /usr/bin/systemctl enable jenkins, /usr/bin/systemctl disable jenkins" > /etc/sudoers.d/jenkins-service
chmod 440 /etc/sudoers.d/jenkins-service
visudo -cf /etc/sudoers.d/jenkins-service
systemctl daemon-reload
sudo -u jenkins sudo /usr/bin/systemctl start jenkins
sudo -u jenkins sudo /usr/bin/systemctl enable jenkins
sudo -u jenkins sudo /usr/bin/systemctl status jenkins --no-pager

--------------------------------------------------------------------------------------------------



#!/bin/bash

# ----------------------------------------------------
# 1. ENFORCE ERROR CHECKING AND DEBUGGING
# ----------------------------------------------------
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

## ----------------------------------------------------
## 2. CONFIGURATION VARIABLES 🌟 PRODUCTION UPDATED 🌟
## ----------------------------------------------------
# Define the port Jenkins will run on (This will now only listen locally)
JENKINS_PORT=8080
# Define the interface Jenkins listens on (CRUCIAL for LB/HTTPS security)
JENKINS_LISTEN_ADDRESS="0.0.0.0"   # 127.0.0.1 --> (localhost) use this range when using load balancer

# Define the network CIDR that is allowed to access the Jenkins Web UI (via Load Balancer or VPN)
# NOTE: If using an external LB, this Firewall rule may become redundant if Jenkins only listens locally.
JENKINS_ACCESS_CIDR="172.31.0.0/16"

# --- AGENT/SLAVE NETWORK CONFIGURATION ---
# Define the dedicated JNLP port for agents to connect back to the master (Default: 50000)
JENKINS_AGENT_PORT=50000 
# Define the network CIDR for your dedicated Agent/Slave machines (e.g., 10.0.1.0/24)
JENKINS_AGENT_CIDR="172.31.0.0/16" 

# --- EBS CONFIGURATION VARIABLES ---
# Set the device name for your attached EBS volume
EBS_DEVICE="/dev/nvme1n1"
JENKINS_HOME_DIR="/var/lib/jenkins"
JENKINS_LOG_FILE="/var/log/jenkins/jenkins.log"

# --- JENKINS JVM CONFIGURATION (CRITICAL FOR PRODUCTION) ---
# Set the maximum heap size for the Jenkins JVM (e.g., 4GB). Adjust based on your server RAM.
JENKINS_MAX_HEAP="-Xmx2560m"
# Set the initial heap size for the Jenkins JVM.
JENKINS_MIN_HEAP="-Xms1g"
# Recommended GC settings for server performance (G1GC)
JENKINS_GC_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200"
# >> ADDED: Set the JVM file encoding for stable international character support.
JENKINS_CHARSET_OPTS="-Dfile.encoding=UTF-8"

## ----------------------------------------------------
## 3. SYSTEM PREPARATION
## ----------------------------------------------------
echo "--- Starting system updates and essential package installation ---"

# Use 'upgrade' for a complete package refresh and consistency
apt update -y
# apt upgrade -y

# Install essential tools (logrotate is included now)
apt install -y wget git firewalld logrotate

# Install a specific, production-approved LTS Java version (Corretto 17)
apt install -y fontconfig openjdk-21-jre

## ----------------------------------------------------
## 3.5. EBS VOLUME CONFIGURATION (Persistence and Backup) 🌟 UPDATED: USING UUID 🌟
## ----------------------------------------------------
echo "--- Configuring EBS Volume ${EBS_DEVICE} for persistent Jenkins home ${JENKINS_HOME_DIR} ---"

# --- A. Formatting the Volume (UNCOMMENTED FOR FIRST RUN) ---
# Check if the volume is already formatted. If not, format it.
if ! file -sL ${EBS_DEVICE} | grep -q 'ext4'; then
    echo "Formatting EBS volume ${EBS_DEVICE} as ext4..."
    # WARNING: This command WILL DESTROY any existing data on the device!
    sudo mkfs -t ext4 ${EBS_DEVICE}
else
    echo "EBS volume ${EBS_DEVICE} is already formatted."
fi

# --- B. Create Mount Point ---
sudo mkdir -p ${JENKINS_HOME_DIR}

# --- C. Mount the Volume (Temporarily) ---
sudo mount ${EBS_DEVICE} ${JENKINS_HOME_DIR}
echo "Volume mounted. Checking mount status:"
df -h ${JENKINS_HOME_DIR}

# -------------------------------------------------------------------------
# D. Make Mount Persistent (fstab) using UUID for stability
# -------------------------------------------------------------------------
# Find the UUID of the mounted device
EBS_UUID=$(sudo blkid -s UUID -o value ${EBS_DEVICE})

if [ -z "${EBS_UUID}" ]; then
    echo "!!! CRITICAL ERROR: Could not determine UUID for ${EBS_DEVICE}. Aborting."
    exit 1
fi

echo "Detected UUID for EBS volume: ${EBS_UUID}"

# Check if the UUID already exists in fstab before adding it
if ! grep -q ${EBS_UUID} /etc/fstab; then
    # Using 'nofail' ensures the system boots even if the EBS volume isn't attached/available
    echo "UUID=${EBS_UUID} ${JENKINS_HOME_DIR} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    echo "Added EBS mount using UUID to /etc/fstab."
else
    echo "EBS mount (by UUID) already exists in /etc/fstab."
fi

# Ensure everything is correctly mounted according to fstab
sudo mount -a

# FINAL CHECK: Ensure the mount is in place before continuing
if ! mountpoint -q ${JENKINS_HOME_DIR}; then
    echo "!!! CRITICAL ERROR: EBS volume failed to mount at ${JENKINS_HOME_DIR}. Aborting."
    exit 1
fi

echo "--- EBS Volume configuration complete. ---"

## ----------------------------------------------------
## 4. JENKINS INSTALLATION
## ----------------------------------------------------
echo "--- Installing Jenkins from official stable repository ---"

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
  
apt update -y
# Install Jenkins
apt install -y jenkins

# --- IMPORTANT EBS STEP: Set permissions on the mounted volume ---
sudo chown -R jenkins:jenkins ${JENKINS_HOME_DIR}
echo "Set ownership of ${JENKINS_HOME_DIR} to jenkins:jenkins."

# >> ADDED: Set restrictive permissions for security
sudo chmod 700 ${JENKINS_HOME_DIR}
echo "Set restrictive permissions (700) on ${JENKINS_HOME_DIR}."

# Daemon-reload is crucial after repo changes
systemctl daemon-reload

## ----------------------------------------------------
## 5. SECURITY CONFIGURATION (FIREWALL) 🌟 CHECKED 🌟
## ----------------------------------------------------
echo "--- Configuring firewall to allow restricted access for UI and Agents ---"
systemctl enable --now firewalld

# 1. Create a specific zone for Jenkins access
sudo firewall-cmd --new-zone=jenkins-access --permanent
sudo firewall-cmd --permanent --zone=jenkins-access --set-target=ACCEPT

# ------------------------------------------------------------
# 2. CONFIGURE JENKINS WEB UI ACCESS
# ------------------------------------------------------------
echo "--- Configuring Jenkins Web UI access on port ${JENKINS_PORT} from ${JENKINS_ACCESS_CIDR} ---"
sudo firewall-cmd --zone=jenkins-access --add-port=${JENKINS_PORT}/tcp --permanent
sudo firewall-cmd --zone=jenkins-access --add-source=${JENKINS_ACCESS_CIDR} --permanent

# ------------------------------------------------------------
# 3. CONFIGURE AGENT/SLAVE REMOTING ACCESS
# ------------------------------------------------------------
echo "--- Configuring Jenkins Agent/Remoting access on port ${JENKINS_AGENT_PORT} from ${JENKINS_AGENT_CIDR} ---"
# Add the dedicated JNLP/Remoting TCP port
sudo firewall-cmd --zone=jenkins-access --add-port=${JENKINS_AGENT_PORT}/tcp --permanent
# Add the restricted source address (CIDR) for the agents
sudo firewall-cmd --zone=jenkins-access --add-source=${JENKINS_AGENT_CIDR} --permanent

# To add access to another subnet CIDR
#sudo firewall-cmd --zone=jenkins-access --add-source=172.31.20.0/24 --permanent
#sudo firewall-cmd --reload


# 4. Apply the changes
sudo firewall-cmd --reload

echo "--- Firewall configured: UI (${JENKINS_PORT}) is restricted to ${JENKINS_ACCESS_CIDR}. ---"
echo "--- Firewall configured: Agents (${JENKINS_AGENT_PORT}) are restricted to ${JENKINS_AGENT_CIDR}. ---"

## ----------------------------------------------------
## 6. TEMP DIRECTORY CONFIGURATION (Jenkins Stability)
## ----------------------------------------------------
echo "--- Configuring /tmp directory binding for Jenkins stability ---"

sudo mkdir -p /var/jenkins_tmp
# Ensure temporary directory has correct permissions
sudo chmod 1777 /var/jenkins_tmp
sudo mount --bind /var/jenkins_tmp /tmp

# Make the binding persistent across reboots (IDEMPOTENT CHECK ADDED)
if ! grep -q '/var/jenkins_tmp' /etc/fstab; then
    echo '/var/jenkins_tmp /tmp none bind 0 0' | sudo tee -a /etc/fstab
    echo "Added /tmp binding to /etc/fstab."
else
    echo "/tmp binding already exists in /etc/fstab."
fi

# Mask the tmp.mount service to prevent conflicts with our fstab entry
sudo systemctl mask tmp.mount
df -h /tmp

## ----------------------------------------------------
## 7. SYSTEM LIMITS & JVM CONFIGURATION (Production Readiness) 🌟 UPDATED 🌟
## ----------------------------------------------------
echo "--- Setting Jenkins system limits (LimitNOFILE), JVM Heap Size, and Listen Address ---"

# Create a systemd drop-in file to set limits, JVM options, and Jenkins command line arguments
sudo mkdir -p /etc/systemd/system/jenkins.service.d

# Use a multi-line string to create the drop-in configuration file
cat <<EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf
[Service]
# 1. Increase the maximum number of file descriptors
LimitNOFILE=65536

# 2. Set the JVM memory limits, Garbage Collector, and Character Set options
Environment="JAVA_OPTS=${JENKINS_MIN_HEAP} ${JENKINS_MAX_HEAP} ${JENKINS_GC_OPTS} ${JENKINS_CHARSET_OPTS}"

# 3. CRUCIAL: Bind Jenkins to the local loopback interface only.
# This forces all external HTTP access to go through the Load Balancer/Reverse Proxy.
Environment="JENKINS_ARGS=--httpListenAddress=${JENKINS_LISTEN_ADDRESS} --httpPort=${JENKINS_PORT}"
EOF

echo "Applied JVM Options: ${JENKINS_MIN_HEAP} ${JENKINS_MAX_HEAP} ${JENKINS_CHARSET_OPTS}. Listen Address: ${JENKINS_LISTEN_ADDRESS}:${JENKINS_PORT}"

# Reload systemd configuration to pick up the new limit
systemctl daemon-reload

## ----------------------------------------------------
## 7.5. LOG ROTATION CONFIGURATION (Logrotate) 🌟 NEW SECTION 🌟
## ----------------------------------------------------
echo "--- Configuring Jenkins log rotation using logrotate ---"

# CONFIGURE LOGROTATE
echo "Configuring logrotate for ${JENKINS_LOG_FILE}..."
cat <<EOF | sudo tee /etc/logrotate.d/jenkins
${JENKINS_LOG_FILE} {
    # Rotate the log file weekly
    weekly
    
    # Keep 5 weeks of rotated logs
    rotate 5
    
    # Do not rotate if the file is empty
    notifempty
    
    # Compress the rotated files immediately
    compress
    
    # Delay compression of the previous log file to next rotation cycle
    delaycompress
    
    # Create the new log file with specific permissions after rotation
    create 0644 jenkins jenkins
    
    # Signal Jenkins to gracefully reopen the log file after rotation to prevent data loss
    postrotate
        if systemctl status jenkins > /dev/null 2>&1 ; then
            sudo kill -USR1 \$(cat /var/run/jenkins.pid)
        fi
    endscript
}
EOF
echo "Logrotate configuration saved to /etc/logrotate.d/jenkins."

## ----------------------------------------------------
## 8. SERVICE MANAGEMENT AND FINAL CHECK 🌟 UPDATED 🌟
## ----------------------------------------------------
echo "--- Enabling and starting Jenkins service ---"

systemctl enable jenkins
systemctl start jenkins

# Check the status and exit code
systemctl status jenkins --no-pager || { echo "--- Jenkins failed to start. Review logs in ${JENKINS_LOG_FILE}. ---"; exit 1; }

echo "--- Jenkins installation complete! ---"
echo "NOTE: Jenkins Web UI is now only listening on ${JENKINS_LISTEN_ADDRESS}:${JENKINS_PORT}."
echo "Access must be done via your Load Balancer for HTTPS/SSL termination."
echo "Agents will connect on port ${JENKINS_AGENT_PORT} from ${JENKINS_AGENT_CIDR}."
echo "Retrieve the initial admin password with: sudo cat ${JENKINS_HOME_DIR}/secrets/initialAdminPassword"







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
