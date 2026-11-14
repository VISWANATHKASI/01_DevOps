# 06. Linux Server Preparation for Jenkins

## 6.1 Introduction

Before installing Jenkins, we need to prepare our Linux server.

In the previous lesson, we created an AWS EC2 instance and connected to it using SSH from Windows 11.

Our server configuration:

| Component | Configuration |
|---|---|
| Cloud Provider | AWS |
| Service | EC2 |
| Region | ap-south-1 (Mumbai) |
| Operating System | Ubuntu 24.04.5 LTS |
| Login User | ubuntu |
| Memory | 4 GiB |
| Root Storage | 20 GiB |

In this lesson, we will prepare Ubuntu for Jenkins installation.

### What We Will Learn

1. Understand Linux package management.
2. Update Ubuntu package information.
3. Upgrade installed packages.
4. Understand Java requirements for Jenkins.
5. Install Java.
6. Verify Java installation.
7. Understand Linux environment variables.
8. Check server resources.
9. Verify that the server is ready for Jenkins installation.

---

## 6.2 Understand Linux Package Management

### What Is a Package?

A package is a collection of files required to install and run software.

For example, Java, Git, Nginx, and other Linux applications can be installed using packages.

Instead of manually downloading and configuring every application, Linux provides package management tools.

### What Is APT?

APT stands for Advanced Package Tool.

It is the package management system used by Ubuntu and Debian-based Linux distributions.

We use APT to:

- Install software.
- Remove software.
- Update package information.
- Upgrade installed packages.
- Manage software dependencies.

### Important APT Commands

| Command | Purpose |
|---|---|
| `sudo apt update` | Refresh package information |
| `sudo apt upgrade` | Upgrade installed packages |
| `sudo apt install` | Install software |
| `sudo apt remove` | Remove installed software |
| `sudo apt list --installed` | List installed packages |

### What Is sudo?

`sudo` stands for Superuser Do.

It allows an authorized user to execute commands with elevated privileges.

For example:

```bash
sudo apt update
```

Updating system package information requires administrative privileges, so we use `sudo`.

### When Do We Use sudo?

We commonly use `sudo` when:

- Installing applications.
- Updating the operating system.
- Modifying system configuration files.
- Managing system services.
- Changing system-level permissions.

---

## 6.3 Update Ubuntu Package Information

### Command

```bash
sudo apt update
```

### Why Do We Use This Command?

Ubuntu maintains information about available software packages in configured repositories.

This information includes:

- Package names.
- Available versions.
- Package dependencies.
- Repository information.

The `apt update` command downloads the latest package information from configured repositories.

### Important Difference

`apt update` does not upgrade the installed software.

It only refreshes the information about available software versions.

### Real-Time Example

Imagine that Ubuntu has Java version 17 available in its package repository.

A newer compatible version becomes available.

Running:

```bash
sudo apt update
```

refreshes the package information so APT knows about the available versions.

### Execute

```bash
sudo apt update
```

Wait until the command completes.

---

## 6.4 Upgrade Installed Packages

### Command

```bash
sudo apt upgrade
```

### Why Do We Use This Command?

This command upgrades installed packages to newer versions available through the configured repositories.

It helps keep the operating system updated with available bug fixes and security updates.

### Difference Between apt update and apt upgrade

| Command | What It Does |
|---|---|
| `sudo apt update` | Refreshes package information |
| `sudo apt upgrade` | Upgrades installed packages |

### When Do We Use These Commands?

In real-world environments, DevOps engineers use package management commands when:

- Preparing new Linux servers.
- Applying security updates.
- Installing application dependencies.
- Maintaining server operating systems.

### Execute

```bash
sudo apt upgrade
```

If prompted for confirmation, review the changes and proceed.

**Important:** In production environments, operating system upgrades should follow the organization's change-management and maintenance procedures.

---

## 6.5 Understand Java Requirements for Jenkins

### Why Does Jenkins Require Java?

Jenkins is primarily developed using Java.

The Jenkins application runs on the Java runtime environment.

Without a compatible Java runtime, Jenkins cannot start.

### Jenkins Execution Architecture

```text
             AWS EC2
                |
                |
           Ubuntu Linux
                |
                |
          Java Runtime
                |
                |
             Jenkins
                |
                |
         Jenkins Pipelines
```

### Which Java Version Should We Install?

The supported Java versions depend on the Jenkins release.

For this training, we will use Java 21 if it is supported by the Jenkins LTS release we install.

Before installing Jenkins, we will verify the official Jenkins Java compatibility requirements.

### Why Java 21?

Java 21 is a Long-Term Support (LTS) release.

It provides a stable Java runtime suitable for many enterprise applications.

---

## 6.6 Check Whether Java Is Already Installed

Before installing Java, check whether it is available.

### Command

```bash
java -version
```

### Why Do We Use This Command?

It displays the installed Java runtime version.

### Possible Output 1: Java Is Installed

Example:

```text
openjdk version "21.0.x"
```

This indicates that Java is installed.

We still need to confirm that the version is supported by our selected Jenkins release.

### Possible Output 2: Java Is Not Installed

Example:

```text
Command 'java' not found
```

This indicates that Java is not available through the current command path.

In that case, we need to install Java.

---

## 6.7 Install Java 21

Only perform this section if Java 21 is not already installed and the selected Jenkins release supports it.

### Step 1: Install Java Runtime

Execute:

```bash
sudo apt install fontconfig openjdk-21-jre -y
```

### Why Do We Use This Command?

This command installs two packages:

| Package | Purpose |
|---|---|
| `fontconfig` | Provides font configuration support |
| `openjdk-21-jre` | Provides the Java 21 runtime environment |

### What Is JRE?

JRE stands for Java Runtime Environment.

It provides the components required to execute Java applications.

Jenkins needs a Java runtime to execute.

### What Does -y Mean?

The `-y` option automatically answers yes to package installation confirmation prompts.

Without `-y`, APT may ask you to confirm the installation.

### Step 2: Verify Java Installation

Execute:

```bash
java -version
```

Example output:

```text
openjdk version "21.0.x"
OpenJDK Runtime Environment
OpenJDK 64-Bit Server VM
```

The exact version and additional output will depend on the installed package update.

### Step 3: Verify Java Package Installation

Execute:

```bash
dpkg -l | grep openjdk
```

### Why Do We Use This Command?

- `dpkg -l` lists installed Debian packages.
- `|` sends the output of the first command to the next command.
- `grep openjdk` filters the output and displays matching package names.

This helps us verify whether OpenJDK packages are installed.

---

## 6.8 Understand Java Environment Variables

### What Is JAVA_HOME?

`JAVA_HOME` is an environment variable that points to the Java installation directory.

Some applications and build tools use this variable to locate Java.

Examples include:

- Jenkins-related tools.
- Maven.
- Gradle.
- Java application build scripts.

### Check Java Executable Location

Execute:

```bash
which java
```

Example output:

```text
/usr/bin/java
```

### Why Do We Use This Command?

It identifies the location of the Java executable found through the system PATH.

### Find the Actual Java Installation Path

Execute:

```bash
readlink -f $(which java)
```

Example output:

```text
/usr/lib/jvm/java-21-openjdk-amd64/bin/java
```

### Why Do We Use readlink -f?

- `which java` identifies the Java executable available in PATH.
- `readlink -f` resolves symbolic links and displays the final path.
- `$(...)` executes the command inside the parentheses and substitutes its output.

### Identify JAVA_HOME

For a typical Ubuntu OpenJDK 21 installation, the Java home directory may be:

```text
/usr/lib/jvm/java-21-openjdk-amd64
```

The exact path can vary depending on the installed Java package.

We will configure `JAVA_HOME` only if required by our tools or environment.

---

## 6.9 Understand Linux Services

Before installing Jenkins, we should understand how Linux manages background services.

### What Is a Service?

A service is a program that runs in the background and provides functionality to the system or other applications.

Examples:

- Jenkins.
- SSH.
- Nginx.
- Docker.

### What Is systemd?

`systemd` is the service and system manager used by Ubuntu.

It helps us start, stop, restart, and monitor services.

### Important systemctl Commands

| Command | Purpose |
|---|---|
| `systemctl status service-name` | Check service status |
| `sudo systemctl start service-name` | Start a service |
| `sudo systemctl stop service-name` | Stop a service |
| `sudo systemctl restart service-name` | Restart a service |
| `sudo systemctl enable service-name` | Enable automatic startup |
| `sudo systemctl disable service-name` | Disable automatic startup |

We will use these commands to manage Jenkins after installation.

---

## 6.10 Check Server Resources

Jenkins consumes server resources while executing builds and pipelines.

We should understand how to monitor memory, disk space, and CPU usage.

### Check Memory

```bash
free -h
```

Purpose:

Displays total, used, free, and available memory.

### Check Disk Space

```bash
df -h
```

Purpose:

Displays disk usage for mounted filesystems.

### Check CPU Information

```bash
lscpu
```

Purpose:

Displays CPU architecture, processor count, and other CPU information.

### Check Current Processes

```bash
top
```

Purpose:

Displays running processes and resource consumption.

Press `q` to exit the `top` interface.

### Why Do We Monitor These Resources?

Consider a Jenkins pipeline that builds a Java application.

During execution, Jenkins may consume:

- CPU for compilation.
- RAM for Java processes.
- Disk space for downloaded dependencies.
- Disk space for build artifacts and logs.

Resource monitoring helps us identify performance problems.

---

## 6.11 Verify Linux Server Preparation

Execute the following commands:

```bash
whoami
```

```bash
cat /etc/os-release
```

```bash
java -version
```

```bash
which java
```

```bash
free -h
```

```bash
df -h
```

```bash
lscpu
```

### Expected Results

| Verification | Expected Result |
|---|---|
| Current user | ubuntu |
| Operating system | Ubuntu 24.04 LTS |
| Java | Compatible Java version installed |
| Java location | Java executable path displayed |
| Memory | Sufficient available memory |
| Disk | Sufficient available storage |
| CPU | CPU information displayed |

---

## 6.12 Practical Exercise

Complete the following tasks:

- [ ] Connect to the EC2 instance using SSH.
- [ ] Update Ubuntu package information.
- [ ] Upgrade installed packages.
- [ ] Check whether Java is installed.
- [ ] Verify Java version compatibility.
- [ ] Install Java 21 if required.
- [ ] Verify Java installation.
- [ ] Find the Java executable location.
- [ ] Check memory.
- [ ] Check disk space.
- [ ] Check CPU information.
- [ ] Understand Linux service management commands.

---

## 6.13 Important Commands Summary

| Command | Purpose |
|---|---|
| `sudo apt update` | Refresh package information |
| `sudo apt upgrade` | Upgrade installed packages |
| `sudo apt install package-name` | Install a package |
| `java -version` | Check Java version |
| `dpkg -l` | List installed packages |
| `which java` | Find Java executable |
| `readlink -f` | Resolve symbolic links |
| `free -h` | Check memory |
| `df -h` | Check disk space |
| `lscpu` | Check CPU information |
| `top` | Monitor running processes |
| `systemctl status` | Check service status |

---

## 6.14 What We Learned

In this lesson, we learned:

1. Linux package management using APT.
2. Difference between `apt update` and `apt upgrade`.
3. Why Jenkins requires Java.
4. How to verify Java installation.
5. How to install Java 21 when required.
6. How to identify the Java installation path.
7. What JAVA_HOME means.
8. How Linux manages background services.
9. How to monitor server resources.

---

## 6.15 Next Lesson

**Document:** `07-Jenkins-Installation.md`

In the next lesson, we will learn:

1. What the Jenkins LTS release is.
2. Why we use the official Jenkins repository.
3. How to add the Jenkins repository to Ubuntu.
4. How to install Jenkins.
5. How to start the Jenkins service.
6. How to enable Jenkins at system startup.
7. How to verify Jenkins installation.

We will install Jenkins on our existing AWS EC2 Ubuntu server.
