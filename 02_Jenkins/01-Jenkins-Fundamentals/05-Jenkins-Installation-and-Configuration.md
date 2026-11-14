## 5.1 What Is Jenkins Installation?

Jenkins is a Java-based automation server.

To run Jenkins, we need to prepare a machine with the required software and configurations.

For our learning environment, we will use an AWS EC2 Linux instance.

The installation process involves:

1. Preparing the EC2 instance.
2. Connecting to the EC2 instance.
3. Identifying the Linux distribution.
4. Installing Java.
5. Adding the official Jenkins repository.
6. Installing Jenkins.
7. Starting the Jenkins service.
8. Configuring Jenkins to start automatically after reboot.
9. Accessing Jenkins through a web browser.
10. Completing the initial Jenkins setup.

## 5.2 Jenkins Installation Prerequisites

Before installing Jenkins, let's understand its requirements.

### 5.2.1 Hardware Requirements

Jenkins hardware requirements depend on the number of jobs, plugins, users, and workloads.

The official Jenkins documentation lists the following baseline requirements:

| Resource | Minimum | Recommended small-team configuration |
|---|---:|---:|
| RAM | 256 MB | 4 GB or more |
| Disk | 1 GB | 50 GB or more |
| CPU | Depends on workload | Multiple cores recommended |

These are general guidelines, not guaranteed production sizing.

For our learning environment, we will start with the existing EC2 instance and monitor its resource consumption.

### 5.2.2 Software Requirements

Jenkins requires a supported Java runtime.

For our installation, we will use Java 21.

Why Java?

Jenkins itself is developed using Java and requires a supported Java runtime to execute.

Without a compatible Java runtime, Jenkins cannot start.

Important:

There is a difference between:

- JRE (Java Runtime Environment): Provides the environment required to run Java applications.
- JDK (Java Development Kit): Includes the runtime environment and development tools such as the Java compiler.

Jenkins Controller requires a supported runtime.

Later, when we build Java applications, our build agents may also need a JDK.

### 5.2.3 Jenkins Release Types

Jenkins provides two major release lines.

**1. Long-Term Support (LTS)**

LTS releases are intended for users who prefer a more stable release cycle.

Characteristics:

- More conservative updates.
- Regular security and bug fixes.
- Suitable for production environments.
- Recommended for our learning environment.

**2. Weekly Release**

Weekly releases provide newer features and updates more frequently.

Characteristics:

- Faster access to new features.
- More frequent changes.
- Useful for testing new Jenkins functionality.

For this training, we will use:

**Jenkins LTS**

## 5.3 Connect to AWS EC2 from Windows 11

We already have an EC2 instance running in AWS Mumbai (`ap-south-1`).

Now let's connect to it.

### 5.3.1 Open AWS Console

1. Open the AWS Management Console.
2. Navigate to EC2.
3. Select Instances.
4. Select your Jenkins EC2 instance.
5. Verify that the instance state is Running.

### 5.3.2 Connect Using SSH

From Windows 11, open PowerShell.

Use the following command:

```powershell
ssh -i "C:\path\to\your-key.pem" ec2-user@YOUR_EC2_PUBLIC_IP
