#!/bin/bash

# ============================================================
# JENKINS INSTALLATION SCRIPT
# Operating System : Ubuntu 24.04 LTS
# Java Version     : OpenJDK 21
# Jenkins Release  : LTS
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
# Especially useful in DevOps scripts, CI/CD pipelines and
# server provisioning.

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
# Useful when installing packages through automated scripts,
# cloud-init, Jenkins pipelines and server provisioning tools.

export DEBIAN_FRONTEND=noninteractive


# ------------------------------------------------------------
# STEP 3: UPDATE UBUNTU PACKAGE INFORMATION
# ------------------------------------------------------------

# Command: sudo apt update
#
# WHY:
# Downloads the latest package information from configured
# Ubuntu repositories.
#
# IMPORTANT:
# This command does not upgrade installed applications.
# It only refreshes the package index.
#
# WHEN TO USE:
# Run before installing packages to ensure APT knows about
# the latest available package versions.

sudo apt update


# ------------------------------------------------------------
# STEP 4: INSTALL REQUIRED UTILITIES AND JAVA
# ------------------------------------------------------------

# Command: sudo apt install -y wget git fontconfig openjdk-21-jre
#
# WHY:
#
# wget:
# Downloads files from URLs.
# We use it to download the Jenkins repository signing key.
#
# git:
# Version control system used to manage source code.
# Jenkins uses Git to retrieve application source code from
# repositories such as GitHub and GitLab.
#
# fontconfig:
# Provides font configuration support required by Jenkins.
#
# openjdk-21-jre:
# Provides the Java 21 runtime required to execute Jenkins.
#
# -y:
# Automatically confirms package installation prompts.
#
# WHEN TO USE:
# Install these dependencies when preparing an Ubuntu server
# for Jenkins installation.
#
# NOTE:
# Java 21 is already installed on this EC2 instance.
# APT will keep the installed version if it is already current.

sudo apt install -y wget git fontconfig openjdk-21-jre


# ------------------------------------------------------------
# STEP 5: VERIFY JAVA INSTALLATION
# ------------------------------------------------------------

# Command: java -version
#
# WHY:
# Displays the installed Java version.
#
# Jenkins requires a supported Java runtime to start.
# We verify Java before installing Jenkins so that
# Java-related issues can be identified early.
#
# WHEN TO USE:
# Use this command when installing or troubleshooting
# Java-based applications such as Jenkins.

java -version


# ------------------------------------------------------------
# STEP 6: CREATE APT KEYRINGS DIRECTORY
# ------------------------------------------------------------

# Command: sudo mkdir -p /etc/apt/keyrings
#
# WHY:
# Creates the directory where APT repository signing keys
# are stored.
#
# mkdir:
# Creates a directory.
#
# -p:
# Creates parent directories if necessary.
# Does not report an error if the directory already exists.
#
# /etc/apt/keyrings:
# Standard location for repository-specific signing keys.
#
# WHEN TO USE:
# Use this when adding third-party APT repositories
# that require their own signing keys.

sudo mkdir -p /etc/apt/keyrings


# ------------------------------------------------------------
# STEP 7: DOWNLOAD JENKINS REPOSITORY SIGNING KEY
# ------------------------------------------------------------

# Command: sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc URL
#
# WHY:
# Downloads the official Jenkins repository signing key.
#
# wget:
# Downloads a file from a specified URL.
#
# -O:
# Saves the downloaded file using the specified filename.
#
# The signing key allows APT to verify packages downloaded
# from the Jenkins repository.
#
# WHEN TO USE:
# Whenever adding a third-party repository that uses
# package signature verification.

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key


# ------------------------------------------------------------
# STEP 8: ADD JENKINS LTS APT REPOSITORY
# ------------------------------------------------------------

# Command: echo "deb [signed-by=...]" URL binary/ | sudo tee FILE
#
# WHY:
# Adds the official Jenkins LTS repository to Ubuntu.
#
# echo:
# Prints the repository configuration.
#
# deb:
# Identifies a binary package repository.
#
# signed-by:
# Specifies the signing key APT should use to verify
# packages from this repository.
#
# tee:
# Writes the repository configuration into a file.
#
# /etc/apt/sources.list.d/jenkins.list:
# Stores the Jenkins repository configuration.
#
# > /dev/null:
# Suppresses the normal output from tee.
#
# WHEN TO USE:
# Use this when installing software from an official
# third-party APT repository instead of Ubuntu's default
# package repositories.

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null


# ------------------------------------------------------------
# STEP 9: REFRESH PACKAGE INFORMATION
# ------------------------------------------------------------

# Command: sudo apt update
#
# WHY:
# We added a new Jenkins repository in Step 8.
#
# Ubuntu must download the package information from this
# newly configured repository before it can find Jenkins.
#
# WHEN TO USE:
# Run apt update whenever you add or modify an APT repository.

sudo apt update


# ------------------------------------------------------------
# STEP 10: INSTALL JENKINS
# ------------------------------------------------------------

# Command: sudo apt install -y jenkins
#
# WHY:
# Installs Jenkins from the official Jenkins LTS repository.
#
# APT automatically handles the required package dependencies.
#
# -y:
# Automatically confirms installation prompts.
#
# WHEN TO USE:
# Use this command when installing Jenkins on Ubuntu.
#
# After installation, Jenkins is registered as a systemd
# service and can be managed using systemctl.

sudo apt install -y jenkins


# ------------------------------------------------------------
# STEP 11: ENABLE JENKINS AT SYSTEM STARTUP
# ------------------------------------------------------------

# Command: sudo systemctl enable jenkins
#
# WHY:
# Configures Jenkins to start automatically whenever
# the Ubuntu server boots.
#
# systemctl:
# Command-line utility used to manage systemd services.
#
# enable:
# Configures a service to start automatically during boot.
#
# WHEN TO USE:
# Use this for services that should automatically start
# after a server restart.
#
# Examples:
# Jenkins, Docker, Nginx and other system services.

sudo systemctl enable jenkins


# ------------------------------------------------------------
# STEP 12: START JENKINS SERVICE
# ------------------------------------------------------------

# Command: sudo systemctl start jenkins
#
# WHY:
# Starts the Jenkins service immediately.
#
# IMPORTANT:
# enable and start perform different operations.
#
# enable:
# Starts Jenkins automatically after future reboots.
#
# start:
# Starts Jenkins right now.
#
# WHEN TO USE:
# Use start when you install a service or need to start
# a service that is currently stopped.

sudo systemctl start jenkins


# ------------------------------------------------------------
# STEP 13: VERIFY JENKINS SERVICE STATUS
# ------------------------------------------------------------

# Command: sudo systemctl status jenkins --no-pager
#
# WHY:
# Displays the current Jenkins service status.
#
# Look for:
# Active: active (running)
#
# --no-pager:
# Displays output directly in the terminal instead of
# opening an interactive pager.
#
# WHEN TO USE:
# Use this command after installation, service startup,
# configuration changes and troubleshooting.

sudo systemctl status jenkins --no-pager


# ------------------------------------------------------------
# STEP 14: DISPLAY INSTALLED JENKINS VERSION
# ------------------------------------------------------------

# Command: dpkg-query -W -f='${Version}\n' jenkins
#
# WHY:
# Displays the Jenkins package version installed on Ubuntu.
#
# dpkg-query:
# Queries information about installed Debian packages.
#
# -W:
# Displays package information.
#
# -f:
# Specifies the output format.
#
# ${Version}:
# Displays the installed package version.
#
# WHEN TO USE:
# Use this to verify installed software versions and
# troubleshoot version-related issues.

dpkg-query -W -f='${Version}\n' jenkins


# ============================================================
# JENKINS INSTALLATION SCRIPT COMPLETED
# ============================================================

echo "============================================================"
echo "Jenkins installation script completed successfully."
echo "============================================================"
