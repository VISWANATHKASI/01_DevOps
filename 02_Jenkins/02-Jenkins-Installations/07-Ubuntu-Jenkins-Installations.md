#!/bin/bash

set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

# Step 1: Update Ubuntu package information
sudo apt update

# Step 2: Install required utilities
sudo apt install -y wget git fontconfig openjdk-21-jre -y

# Step 3: Verify Java installation
java -version

# Step 4: Create APT keyrings directory
sudo mkdir -p /etc/apt/keyrings

# Step 5: Download Jenkins repository signing key
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

# Step 6: Add Jenkins LTS repository
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Step 7: Update package information
sudo apt update

# Step 8: Install Jenkins
sudo apt install -y jenkins

# Step 9: Enable Jenkins at system startup
sudo systemctl enable jenkins

# Step 10: Start Jenkins
sudo systemctl start jenkins

# Step 11: Verify Jenkins service
sudo systemctl status jenkins --no-pager

# Step 12: Display installed Jenkins version
dpkg-query -W -f='${Version}\n' jenkins
