
# 06. Linux Server Preparation for Jenkins (Ubuntu)

## 6.1 Introduction

Before installing Jenkins, we need to prepare a Linux server.

We will use an Ubuntu Server running on AWS EC2 to install and configure Jenkins.

Jenkins is a Java-based application. Therefore, we need to prepare the server with the required packages, Java runtime, network connectivity, storage, and permissions.

### Learning Objectives

By the end of this lesson, you will understand:

- How to connect to an Ubuntu EC2 instance using SSH.
- How to identify the Ubuntu version.
- How to check CPU, memory, and disk space.
- How to update Ubuntu packages.
- How to install Java 21.
- How to verify Java installation.
- How to understand Jenkins network requirements.
- How to check Ubuntu firewall configuration.
- How to understand Linux services using systemd.
- How to verify whether the server is ready for Jenkins installation.

---

## 6.2 Step 1 - Connect to the Ubuntu Server

We will connect to our Ubuntu EC2 instance using SSH.

### What is SSH?

SSH stands for Secure Shell.

It is a network protocol used to securely connect to remote Linux servers.

Using SSH, we can execute commands on a remote server from our local machine.

### Connect from Windows PowerShell

Open Windows PowerShell and execute:

```bash
ssh -i "your-key.pem" ubuntu@YOUR_PUBLIC_IP
```

Replace:

- `your-key.pem` with your EC2 private key file.
- `YOUR_PUBLIC_IP` with your EC2 public IP address.

### Example

```bash
ssh -i "jenkins-key.pem" ubuntu@YOUR_PUBLIC_IP
```

### Command Explanation

| Component | Purpose |
|---|---|
| `ssh` | Establishes a secure remote connection. |
| `-i` | Specifies the private key file. |
| `jenkins-key.pem` | EC2 private key file. |
| `ubuntu` | Default Ubuntu EC2 username. |
| Public IP | Address of the EC2 instance. |

After successful authentication, you should see the Ubuntu terminal.

Example:

```text
ubuntu@ip-172-31-xx-xx:~$
```

Now we can execute Linux commands directly on the EC2 instance.

---

## 6.3 Step 2 - Identify the Ubuntu Version

Before installing any software, we should identify the operating system and its version.

Execute:

```bash
cat /etc/os-release
```

### Why do we use this command?

Different Linux distributions use different package managers and installation procedures.

For example:

- Ubuntu uses APT.
- Red Hat Enterprise Linux uses DNF.
- Amazon Linux 2023 uses DNF.

Therefore, we should identify the operating system before executing installation commands.

### Example Output

```text
PRETTY_NAME="Ubuntu 24.04 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04 LTS"
ID=ubuntu
ID_LIKE=debian
```

Your actual Ubuntu version may differ.

### Additional Commands

Check the Linux kernel version:

```bash
uname -r
```

Check the system architecture:

```bash
uname -m
```

Check the hostname:

```bash
hostname
```

### Command Explanation

| Command | Purpose |
|---|---|
| `cat /etc/os-release` | Displays operating system details. |
| `uname -r` | Displays Linux kernel version. |
| `uname -m` | Displays CPU architecture. |
| `hostname` | Displays server hostname. |

For our Jenkins practice environment, we will use a 64-bit Ubuntu server.

---

## 6.4 Step 3 - Check Server Resources

Before installing Jenkins, we need to understand the available server resources.

Jenkins requires CPU, memory, and disk space to execute jobs and manage builds.

### 6.4.1 Check CPU Information

Execute:

```bash
lscpu
```

### Why do we use this command?

`lscpu` displays information about the processor.

It provides details such as:

- CPU architecture.
- Number of CPUs.
- CPU cores.
- CPU model.
- Virtualization information.

This helps us understand the processing capacity of our EC2 instance.

### 6.4.2 Check Memory

Execute:

```bash
free -h
```

### Why do we use this command?

It displays the available system memory.

The `-h` option means human-readable.

Instead of displaying memory in raw bytes, it displays values in KB, MB, or GB.

### 6.4.3 Check Disk Space

Execute:

```bash
df -h
```

### Why do we use this command?

It displays available disk space for mounted filesystems.

Jenkins stores:

- Build history.
- Console logs.
- Workspace files.
- Plugins.
- Job configurations.
- Build artifacts.

If disk space becomes full, Jenkins builds may fail.

### 6.4.4 Check Current Directory

Execute:

```bash
pwd
```

### Why do we use this command?

`pwd` stands for Print Working Directory.

It displays the current directory in which we are executing commands.

Example:

```text
/home/ubuntu
```

### Recommended Learning Environment

For our Jenkins practice environment, we will target:

| Resource | Recommended Configuration |
|---|---|
| CPU | 2 vCPUs |
| RAM | 4 GB |
| Storage | 20 GB or more |
| Architecture | 64-bit |
| Java | Java 21 |
| Jenkins | LTS |

These are practical learning targets, not mandatory minimum requirements.

---

## 6.5 Step 4 - Update Ubuntu Packages

Before installing Jenkins and Java, we should update the operating system packages.

### Why should we update Ubuntu?

An operating system may contain older package information and outdated installed packages.

Updating package information and available software helps prepare the server with current packages and security fixes.

### Step 1 - Update Package Information

Execute:

```bash
sudo apt update
```

### Why do we use this command?

Ubuntu uses APT as its package management tool.

The `apt update` command downloads the latest package information from configured repositories.

It does not upgrade installed packages.

### Command Explanation

| Component | Purpose |
|---|---|
| `sudo` | Executes the command with administrator privileges. |
| `apt` | Ubuntu package management tool. |
| `update` | Refreshes package information. |

### Step 2 - Upgrade Installed Packages

Execute:

```bash
sudo apt upgrade -y
```

### Why do we use this command?

It upgrades installed packages where possible.

Command explanation:

- `sudo` - Executes with administrator privileges.
- `apt` - Package management tool.
- `upgrade` - Upgrades installed packages.
- `-y` - Automatically answers yes to confirmation prompts.

### Important Difference

```bash
sudo apt update
```

Refreshes package information.

```bash
sudo apt upgrade -y
```

Upgrades installed packages.

Both commands perform different tasks.

---

## 6.6 Step 5 - Understand Java Requirements

### What is Java?

Java is a programming language and runtime platform.

Jenkins is a Java-based application and requires a supported Java runtime to execute.

Without a compatible Java runtime, Jenkins cannot start.

### Which Java Version Should We Install?

For this training, we will use:

```text
Java 21
```

Java 21 is a supported Jenkins runtime version.

Modern Jenkins releases also support Java 25. However, we will standardize on Java 21 for our learning environment.

### Important Difference Between JDK and JRE

**JDK - Java Development Kit**

JDK includes development tools such as:

- Java compiler.
- Java debugger.
- Java development utilities.
- Java runtime components.

**JRE - Java Runtime Environment**

The runtime environment provides the components required to execute Java applications.

For Jenkins installation, we need a compatible Java runtime.

### Important DevOps Concept

Java used to run Jenkins is not necessarily the same Java version used to build Java applications.

For example:

- Jenkins controller can run using Java 21.
- Jenkins pipeline can build an application using another compatible JDK configured separately.

We will learn how to configure build tools in upcoming Jenkins lessons.

---

## 6.7 Step 6 - Install Java 21 on Ubuntu

Now we will install Java 21 on our Ubuntu server.

### Step 1 - Refresh Package Information

Execute:

```bash
sudo apt update
```

### Why do we use this command?

It refreshes package information so Ubuntu can identify the latest available package versions.

### Step 2 - Install Java 21 and Fontconfig

Execute:

```bash
sudo apt install fontconfig openjdk-21-jre -y
```

### Why do we install these packages?

**fontconfig**

Provides font configuration and management libraries required by Jenkins on Linux.

**openjdk-21-jre**

Installs the Java 21 Runtime Environment.

**-y**

Automatically confirms the installation.

### Step 3 - Verify Java Installation

Execute:

```bash
java -version
```

Expected output should indicate Java 21.

Example:

```text
openjdk version "21.x.x"
OpenJDK Runtime Environment
OpenJDK 64-Bit Server VM
```

The exact version and build information will vary.

### Step 4 - Check Java Executable Location

Execute:

```bash
which java
```

### Why do we use this command?

It displays the location of the Java executable.

Example:

```text
/usr/bin/java
```

### Step 5 - Check Java Runtime Directory

Execute:

```bash
java -XshowSettings:properties -version 2>&1 | grep 'java.home'
```

### Why do we use this command?

It displays Java runtime properties.

The `java.home` property identifies the Java runtime directory.

### Step 6 - Check JAVA_HOME

Execute:

```bash
echo $JAVA_HOME
```

This displays the `JAVA_HOME` environment variable if it is configured in the current shell.

It may be empty. That does not automatically mean Java is incorrectly installed.

We will configure environment variables when required by our tools and build environments.

---

## 6.8 Step 7 - Understand Ubuntu Package Management

Before proceeding, we should understand a few important Ubuntu package management commands.

### Check Whether a Package Is Installed

```bash
dpkg -l | grep openjdk
```

### Explanation

- `dpkg` - Debian package management tool.
- `-l` - Lists installed packages.
- `grep` - Searches for matching text.
- `openjdk` - Package name pattern.

### Search for Available Java Packages

```bash
apt search openjdk-21
```

### Why do we use this command?

It searches configured repositories for packages matching the specified name.

### Check Package Details

```bash
apt show openjdk-21-jre
```

### Why do we use this command?

It displays package information, such as:

- Package version.
- Dependencies.
- Description.
- Package size.

These commands help us understand package management in Ubuntu.

---

## 6.9 Step 8 - Understand Jenkins Network Requirements

Jenkins uses port `8080` by default for its web interface.

After installing Jenkins, we will access it through a web browser.

Example:

```text
http://YOUR_SERVER_PUBLIC_IP:8080
```

### What is a Port?

A port is a logical communication endpoint used by applications to receive network traffic.

For example:

| Port | Purpose |
|---|---|
| 22 | SSH |
| 8080 | Jenkins web interface |
| 80 | HTTP |
| 443 | HTTPS |

### AWS Security Group Configuration

Because we are practising Jenkins on AWS EC2, we need to understand Security Groups.

A Security Group acts as a virtual firewall for an EC2 instance.

It controls incoming and outgoing network traffic.

For our Jenkins practice environment, configure these inbound rules:

| Type | Protocol | Port | Source |
|---|---|---|---|
| SSH | TCP | 22 | Your public IP |
| Custom TCP | TCP | 8080 | Your public IP |

### Why Should We Restrict Port 8080?

Jenkins is an administration and automation platform.

Exposing it to the entire internet unnecessarily can create security risks.

For learning purposes, allow access only from your own public IP address.

In production, Jenkins should normally be protected through HTTPS, suitable access controls, and an appropriate reverse proxy or load balancer.

### Important

Opening port 8080 in an AWS Security Group does not automatically configure the Ubuntu firewall.

AWS Security Groups and operating system firewalls are separate security layers.

Both must allow the required traffic.

---

## 6.10 Step 9 - Understand Ubuntu Firewall (UFW)

Ubuntu commonly uses UFW as its firewall management tool.

UFW stands for Uncomplicated Firewall.

### Step 1 - Check Firewall Status

Execute:

```bash
sudo ufw status
```

Possible output:

```text
Status: inactive
```

Or:

```text
Status: active
```

### Step 2 - Allow Jenkins Port

If UFW is active and Jenkins access is required, execute:

```bash
sudo ufw allow 8080/tcp
```

### Why do we use this command?

It allows incoming TCP traffic on port 8080 through UFW.

### Step 3 - Verify Firewall Rules

Execute:

```bash
sudo ufw status
```

Expected output should include:

```text
8080/tcp ALLOW
```

### Important Security Note

Do not enable UFW remotely without first allowing SSH traffic.

Otherwise, you may lose your SSH connection.

If you need to enable UFW, first configure SSH access:

```bash
sudo ufw allow 22/tcp
```

Then:

```bash
sudo ufw enable
```

For our current practice environment, do not change the firewall state unnecessarily.

---

## 6.11 Step 10 - Understand Linux Services Using systemd

Jenkins runs as a background service on Linux.

Ubuntu uses systemd to manage system services.

### What is systemd?

systemd is a system and service manager used to initialize Linux systems and manage background services.

After installing Jenkins, we will use systemd to:

- Start Jenkins.
- Stop Jenkins.
- Restart Jenkins.
- Enable Jenkins at system startup.
- Check Jenkins service status.
- Troubleshoot Jenkins service failures.

### Step 1 - Check systemd Version

Execute:

```bash
systemctl --version
```

### Why do we use this command?

It displays the installed systemd version.

### Step 2 - Check Running Services

Execute:

```bash
systemctl list-units --type=service --state=running
```

### Why do we use this command?

It displays currently running system services.

### Step 3 - Understand Service Status

Execute:

```bash
systemctl status ssh
```

This checks the status of the SSH service.

### Important

We will learn Jenkins-specific service management commands after installing Jenkins.

---

## 6.12 Step 11 - Check Network Connectivity

Before installing Jenkins, we should verify that our server can access the internet and resolve domain names.

### Step 1 - Check IP Information

Execute:

```bash
hostname -I
```

### Why do we use this command?

It displays IP addresses assigned to the server.

### Step 2 - Check Routing Information

Execute:

```bash
ip route
```

### Why do we use this command?

It displays the system's network routing table.

It helps us understand how the server sends network traffic to other destinations.

### Step 3 - Check Internet Connectivity

Execute:

```bash
ping -c 4 8.8.8.8
```

### Why do we use this command?

It checks whether the server can communicate with an external IP address using ICMP.

### Step 4 - Check DNS Resolution

Execute:

```bash
getent hosts google.com
```

### Why do we use this command?

It checks whether the server can resolve a domain name into an IP address.

### Important

A failed ping does not always mean internet connectivity is unavailable because some networks block ICMP traffic.

---

## 6.13 Step 12 - Understand Important Jenkins Directories

After Jenkins installation, we will work with several important directories.

| Directory | Purpose |
|---|---|
| `/var/lib/jenkins` | Jenkins home directory and persistent data |
| `/var/log/jenkins` | Jenkins log directory on standard package installations |
| `/usr/share/java` | Common location for Java-related files |
| `/etc/default` | Default environment configuration directory used by some Ubuntu services |
| `/etc/systemd/system` | Location for systemd unit configuration files |

### What is Jenkins Home Directory?

Jenkins stores important information in its home directory.

Examples:

- Jenkins job configurations.
- Build history.
- Plugins.
- Credentials configuration.
- Workspace data.
- System configuration.

The default package installation uses:

```text
/var/lib/jenkins
```

We will understand Jenkins home directory in detail during the installation and configuration lessons.

---

## 6.14 Step 13 - Final Ubuntu Server Readiness Check

Before proceeding to Jenkins installation, execute the following commands.

### Operating System

```bash
cat /etc/os-release
```

### Kernel Version

```bash
uname -r
```

### CPU Information

```bash
lscpu
```

### Memory Information

```bash
free -h
```

### Disk Space

```bash
df -h
```

### Java Version

```bash
java -version
```

### Java Executable

```bash
which java
```

### Java Runtime Directory

```bash
java -XshowSettings:properties -version 2>&1 | grep 'java.home'
```

### Network Information

```bash
hostname -I
```

### Firewall Status

```bash
sudo ufw status
```

### systemd Version

```bash
systemctl --version
```

### Expected Readiness

| Check | Expected Result |
|---|---|
| Ubuntu | Operating system identified |
| Architecture | 64-bit |
| CPU | Resources available |
| Memory | Sufficient for learning workload |
| Disk | Sufficient free space |
| Java | Java 21 installed |
| Network | Repository access available |
| SSH | Remote connection working |
| systemd | Available |

If these checks are successful, our Ubuntu server is prepared for Jenkins installation.

---

## 6.15 Troubleshooting Common Problems

### Problem 1 - Java Command Not Found

Error:

```text
java: command not found
```

Possible reason:

Java is not installed or the Java executable is not available in the system PATH.

Solution:

```bash
sudo apt update
sudo apt install openjdk-21-jre -y
```

Verify:

```bash
java -version
```

### Problem 2 - Unable to Download Packages

Possible reasons:

- Internet connectivity issues.
- DNS resolution problems.
- Incorrect repository configuration.
- Network restrictions.

Check connectivity:

```bash
ping -c 4 8.8.8.8
```

Check DNS:

```bash
getent hosts google.com
```

### Problem 3 - Permission Denied

Example:

```text
Permission denied
```

Possible reason:

The current user does not have sufficient permissions to execute the command.

Solution:

Use `sudo` for commands that require administrator privileges.

Example:

```bash
sudo apt update
```

### Problem 4 - Insufficient Disk Space

Check disk space:

```bash
df -h
```

Check directory sizes:

```bash
sudo du -sh /var/*
```

Jenkins requires disk space for plugins, workspaces, build history, logs, and artifacts.

### Problem 5 - Unable to Connect to EC2

Possible reasons:

- Incorrect public IP address.
- Incorrect private key.
- Incorrect SSH username.
- SSH port 22 is not allowed in the Security Group.
- Incorrect key file permissions.

Verify the EC2 Security Group and SSH configuration.

---

## 6.16 Practical Assignment

Perform the following activities on your Ubuntu EC2 instance.

### Server Preparation

- [ ] Connect to Ubuntu using SSH.
- [ ] Identify the Ubuntu version.
- [ ] Check Linux kernel version.
- [ ] Check CPU information.
- [ ] Check memory.
- [ ] Check disk space.
- [ ] Update Ubuntu packages.
- [ ] Install Java 21.
- [ ] Verify Java installation.
- [ ] Identify the Java executable location.
- [ ] Check network connectivity.
- [ ] Check DNS resolution.
- [ ] Check UFW firewall status.
- [ ] Verify systemd availability.

### Command Practice

Execute the following commands independently and understand their outputs.

```bash
cat /etc/os-release
```

```bash
uname -r
```

```bash
uname -m
```

```bash
lscpu
```

```bash
free -h
```

```bash
df -h
```

```bash
sudo apt update
```

```bash
sudo apt upgrade -y
```

```bash
sudo apt install fontconfig openjdk-21-jre -y
```

```bash
java -version
```

```bash
which java
```

```bash
sudo ufw status
```

```bash
systemctl --version
```

---

## 6.17 Interview Questions

**1. What is SSH?**

SSH stands for Secure Shell. It is used to securely connect to remote Linux servers.

**2. What is the difference between Ubuntu and Red Hat?**

Ubuntu belongs to the Debian family and uses APT package management. Red Hat belongs to the Red Hat family and uses DNF/YUM package management.

**3. What is APT?**

APT stands for Advanced Package Tool. It manages software packages on Debian-based distributions such as Ubuntu.

**4. What is the difference between `apt update` and `apt upgrade`?**

`apt update` refreshes package information, whereas `apt upgrade` upgrades installed packages.

**5. Why does Jenkins require Java?**

Jenkins is a Java-based application and requires a supported Java runtime to execute.

**6. What is the difference between JDK and JRE?**

JDK includes Java development tools, whereas the runtime environment provides the components needed to execute Java applications.

**7. What is the purpose of `free -h`?**

It displays system memory information in human-readable format.

**8. What is the purpose of `df -h`?**

It displays filesystem disk usage and available storage.

**9. What is systemd?**

systemd is a system and service manager used to initialize Linux systems and manage background services.

**10. What is the default Jenkins port?**

8080.

**11. What is UFW?**

UFW stands for Uncomplicated Firewall. It provides a simple interface for managing firewall rules on Ubuntu.

**12. What is the purpose of `/var/lib/jenkins`?**

It is the default Jenkins home directory used to store persistent Jenkins data.

**13. Why should we check disk space before installing Jenkins?**

Jenkins stores plugins, build logs, workspaces, job configurations, and artifacts. Insufficient disk space can cause build failures.

**14. What is the difference between an AWS Security Group and UFW?**

An AWS Security Group controls traffic at the EC2 network interface level, whereas UFW controls traffic within the Ubuntu operating system.

---

## 6.18 Lesson Summary

In this lesson, we prepared an Ubuntu server for Jenkins installation.

We learned:

1. How to connect to an Ubuntu EC2 instance using SSH.
2. How to identify the Ubuntu version.
3. How to check CPU, memory, and disk space.
4. How to update Ubuntu packages.
5. Why Jenkins requires Java.
6. How to install Java 21.
7. How to verify Java installation.
8. How to understand Jenkins network requirements.
9. How to check UFW firewall configuration.
10. How to understand systemd.
11. How to verify network connectivity.
12. How to troubleshoot common Linux server preparation issues.

### What Comes Next?

**Document 07 - Jenkins Installation on Ubuntu Server**

In the next lesson, we will install Jenkins LTS on our Ubuntu EC2 instance.

We will cover:

1. Understanding the official Jenkins repository.
2. Adding the Jenkins repository signing key.
3. Configuring the Jenkins package repository.
4. Installing Jenkins.
5. Starting the Jenkins service.
6. Enabling Jenkins at system startup.
7. Checking Jenkins service status.
8. Understanding Jenkins logs.
9. Accessing Jenkins through a web browser.
10. Retrieving the initial administrator password.
11. Completing the Jenkins initial setup wizard.

We will understand every command, why we use it, and when it is used in real-world DevOps environments.

---

## 6.19 Official References

1. Jenkins Linux Installation Guide: https://www.jenkins.io/doc/book/installing/linux/
2. Jenkins Java Support Policy: https://www.jenkins.io/doc/book/platform-information/support-policy-java/
3. Ubuntu Server Documentation: https://documentation.ubuntu.com/server/
4. OpenJDK Documentation: https://openjdk.org/
5. AWS EC2 Documentation: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html
</WritingBlock>

