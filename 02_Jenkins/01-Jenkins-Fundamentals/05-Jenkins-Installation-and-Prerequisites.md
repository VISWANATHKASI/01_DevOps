# 05. Jenkins Installation and Prerequisites

## 5.1 Introduction

In this lesson, we will prepare our AWS EC2 instance for Jenkins installation.

Before installing Jenkins, we need to understand the server requirements and verify the operating system and Java environment.

We will perform the installation on an AWS EC2 Linux instance.

### What We Will Learn

1. Jenkins installation requirements.
2. Why Jenkins requires Java.
3. How to connect to an EC2 instance.
4. How to identify the Linux distribution.
5. How to check the Java version.
6. How to prepare the server for Jenkins installation.

---

## 5.2 Jenkins Installation Architecture

Before installing Jenkins, let's understand where Jenkins will run.

Our setup will look like this:

```text
              Windows 11 Laptop
                     |
                     |
                Web Browser
                     |
                     |
              Internet Connection
                     |
                     |
                AWS EC2
              Linux Server
                     |
                     |
                  Jenkins
                     |
                     |
             Jenkins Web UI
               Port 8080
```

### Explanation

| Component | Purpose |
|---|---|
| Windows 11 | Our local computer |
| Web Browser | Used to access Jenkins |
| AWS EC2 | Cloud virtual machine |
| Linux | Operating system running on EC2 |
| Java | Runtime environment required by Jenkins |
| Jenkins | Automation server |
| Port 8080 | Default Jenkins web interface port |

### Real-Time Example

Imagine that you are working as a DevOps engineer.

Your company wants to automate application deployment.

Instead of installing Jenkins on your personal laptop, you install Jenkins on an AWS EC2 Linux server.

Your development team can then access Jenkins through a browser.

This is a common approach in real-world DevOps environments.

---

## 5.3 Jenkins Installation Requirements

Before installing Jenkins, we need the following:

| Requirement | Purpose |
|---|---|
| AWS EC2 instance | Server to host Jenkins |
| Linux operating system | Operating system for Jenkins |
| Java | Runtime environment for Jenkins |
| Internet connectivity | Download Jenkins packages and plugins |
| Security Group | Controls network access |
| Port 8080 | Jenkins web interface |

### Why Does Jenkins Require Java?

Jenkins is primarily developed using Java.

Java provides the runtime environment required to execute Jenkins.

Without a compatible Java runtime, Jenkins cannot start.

For example:

```text
Jenkins Application
        |
        |
        v
Java Runtime Environment
        |
        |
        v
Linux Operating System
        |
        |
        v
AWS EC2
```

### When Do We Use Java?

Java is required when:

- Installing Jenkins.
- Starting the Jenkins service.
- Running Jenkins pipelines.
- Executing Java-based build tools.
- Running Java applications during CI/CD pipelines.

**Important:** The required Java version depends on the Jenkins release. We will verify the supported Java version before installation.

---

## 5.4 Connect to AWS EC2

We are using Windows 11 as our local operating system and AWS EC2 as our Jenkins server.

### Step 1: Open AWS Console

1. Open the AWS Management Console.
2. Navigate to EC2.
3. Select Instances.
4. Locate your Jenkins EC2 instance.
5. Confirm that the instance state is `Running`.

### Step 2: Connect to EC2

You can connect using either:

- EC2 Instance Connect through the AWS Console.
- SSH from your Windows terminal.

For this training, we can use SSH.

Open PowerShell on Windows.

Navigate to the folder containing your EC2 private key.

Example:

```powershell
cd C:\Users\YourUsername\Downloads
```

Connect using:

```powershell
ssh -i "your-key.pem" ubuntu@YOUR_EC2_PUBLIC_IP
```

**Note:** The SSH username depends on the Linux distribution.

Common usernames:

| Linux Distribution | Default Username |
|---|---|
| Ubuntu | ubuntu |
| Amazon Linux | ec2-user |
| RHEL | ec2-user |

Replace `YOUR_EC2_PUBLIC_IP` with your instance's public IPv4 address.

### Why Do We Use SSH?

SSH stands for Secure Shell.

It allows us to connect securely to a remote Linux server.

### When Do We Use SSH?

We commonly use SSH to:

- Install applications on Linux servers.
- Execute Linux commands remotely.
- Manage server configurations.
- Troubleshoot application issues.
- Monitor server processes.

---

## 5.5 Identify the Linux Distribution

After connecting to EC2, execute:

```bash
cat /etc/os-release
```

### Why Do We Use This Command?

The `/etc/os-release` file contains information about the Linux operating system.

It helps us identify:

- Operating system name.
- Linux distribution.
- Operating system version.
- Distribution ID.

### Example Output

The output may look similar to this:

```text
NAME="Ubuntu"
VERSION="24.04 LTS"
ID=ubuntu
VERSION_ID="24.04"
```

Or:

```text
NAME="Amazon Linux"
VERSION="2023"
ID="amzn"
VERSION_ID="2023"
```

### When Do We Use This Command?

We use this command before installing software because installation commands differ between Linux distributions.

For example:

| Distribution | Package Manager |
|---|---|
| Ubuntu | apt |
| Debian | apt |
| Amazon Linux 2023 | dnf |
| RHEL | dnf |

**Important:** Do not execute installation commands until we identify the operating system.

---

## 5.6 Check Whether Java Is Installed

Execute:

```bash
java -version
```

### Why Do We Use This Command?

This command displays the installed Java runtime version.

It helps us determine whether Java is already installed on the EC2 instance.

### Possible Output 1: Java Is Installed

Example:

```text
openjdk version "21.0.x"
```

This indicates that Java is installed.

We still need to verify that the installed version is supported by our Jenkins release.

### Possible Output 2: Java Is Not Installed

Example:

```text
Command 'java' not found
```

This indicates that Java is not available through the current command path.

We will install a compatible Java version in the next practical step.

### When Do We Use This Command?

We use `java -version` when:

- Checking Java installation.
- Troubleshooting Jenkins startup failures.
- Verifying Java compatibility.
- Checking the runtime environment.

---

## 5.7 Verify the Server Information

Execute the following commands one by one.

### Check Linux Kernel Information

```bash
uname -r
```

**Purpose:** Displays the Linux kernel version.

### Check Current Logged-in User

```bash
whoami
```

**Purpose:** Displays the username currently executing commands.

### Check Available Disk Space

```bash
df -h
```

**Purpose:** Displays available disk space in a human-readable format.

### Check Available Memory

```bash
free -h
```

**Purpose:** Displays total, used, and available memory.

### Why Are These Checks Important?

Jenkins needs sufficient memory and disk space to operate.

Builds, plugins, logs, and workspace files consume server resources.

Checking these resources helps us identify potential limitations before installation.

---

## 5.8 Practical Exercise

Before proceeding with Jenkins installation, execute these commands on your EC2 instance:

```bash
cat /etc/os-release
```

```bash
java -version
```

```bash
uname -r
```

```bash
whoami
```

```bash
df -h
```

```bash
free -h
```

### Expected Result

After executing these commands, we should know:

1. Which Linux distribution is running.
2. Which operating system version is installed.
3. Whether Java is already installed.
4. Which user is connected to the server.
5. How much disk space is available.
6. How much memory is available.

---

## 5.9 Important Commands Summary

| Command | Purpose |
|---|---|
| `cat /etc/os-release` | Identify Linux distribution |
| `java -version` | Check Java version |
| `uname -r` | Check Linux kernel version |
| `whoami` | Identify current user |
| `df -h` | Check disk space |
| `free -h` | Check memory |

---

## 5.10 What We Learned

In this lesson, we learned:

- Where Jenkins will be installed.
- Why Jenkins requires Java.
- How to connect to an AWS EC2 instance.
- How to identify the Linux distribution.
- How to check the Java version.
- How to verify disk space and memory.
- Why we must check server requirements before installation.

---

## 5.11 Next Lesson

**Document:** `06-Jenkins-Initial-Setup-and-Access.md`

In the next lesson, we will cover:

1. Installing Java if required.
2. Adding the official Jenkins repository.
3. Installing Jenkins.
4. Starting the Jenkins service.
5. Enabling Jenkins to start automatically after server reboot.
6. Verifying Jenkins installation.

We will select the correct installation commands based on the Linux distribution identified in this lesson.
