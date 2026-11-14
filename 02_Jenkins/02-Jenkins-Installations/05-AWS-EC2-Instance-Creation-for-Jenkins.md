# 05. AWS EC2 Instance Creation for Jenkins

## 5.1 Introduction

Before installing Jenkins, we need a server where Jenkins will run.

We will use AWS EC2 to create a Linux virtual machine and install Jenkins on it.

### What Is AWS EC2?

Amazon EC2 stands for Amazon Elastic Compute Cloud.

It provides virtual servers in the AWS cloud.

These virtual servers are called EC2 instances.

We can use EC2 instances to:

- Host applications.
- Install Jenkins.
- Run CI/CD pipelines.
- Host web servers.
- Deploy applications.
- Run Docker containers.

### Our Goal

We will create one EC2 instance dedicated to Jenkins.

Our architecture will look like this:

```text
              Windows 11 Laptop
                     |
                     |
                 Web Browser
                     |
                     |
                  Internet
                     |
                     |
                  AWS Cloud
                     |
                     |
                EC2 Instance
                     |
                     |
                Ubuntu Linux
                     |
                     |
                   Java
                     |
                     |
                  Jenkins
                     |
                     |
                Port 8080
```

---

## 5.2 Prerequisites

Before creating the EC2 instance, we need:

1. An AWS account.
2. Access to the AWS Management Console.
3. An AWS region.
4. A Windows 11 computer.
5. An internet connection.

### AWS Region

An AWS region is a geographical area where AWS provides cloud services.

For our practical training, we will use:

```text
Region: Asia Pacific (Mumbai)
Region Code: ap-south-1
```

### Why Are We Using ap-south-1?

AWS regions are geographically distributed.

Choosing a nearby region can help reduce network latency when accessing our server.

We will keep our Jenkins environment in this region throughout our practical training.

---

## 5.3 Understand EC2 Instance Configuration

Before creating the instance, understand the important configuration options.

| Configuration | Selection | Purpose |
|---|---|---|
| Instance name | Jenkins-Server | Identifies our server |
| AMI | Ubuntu Server LTS | Operating system |
| Instance type | t3.medium | CPU and memory resources |
| Key pair | Create new | Secure SSH access |
| Network | Default VPC | Network connectivity |
| Security group | Jenkins-SG | Controls inbound traffic |
| Storage | 20 GiB | Operating system and Jenkins data |

### Why Ubuntu?

Ubuntu is a popular Linux distribution used in cloud environments.

It is suitable for learning:

- Jenkins.
- Docker.
- Kubernetes.
- Terraform.
- AWS DevOps tools.

We will use Ubuntu for our practical exercises.

### Why t3.medium?

For our learning environment, we will start with:

```text
Instance Type: t3.medium
vCPUs: 2
Memory: 4 GiB
```

This gives us more room to run Jenkins and perform basic CI/CD exercises.

**Cost consideration:** EC2 instances incur charges while running, depending on the instance type, region, and pricing model. Check the AWS pricing page before launching. Stop or terminate the instance when you are not using it, according to whether you need to preserve it.

---

## 5.4 Create an EC2 Instance

### Step 1: Open AWS Management Console

1. Open https://console.aws.amazon.com/
2. Sign in to your AWS account.
3. Search for `EC2`.
4. Open the EC2 service.
5. Select the region `Asia Pacific (Mumbai)`.

### Step 2: Open Launch Instance

1. Select **Instances** from the left navigation.
2. Click **Launch instances**.

You will see the EC2 instance creation page.

### Step 3: Enter Instance Name

Under Name and tags, enter:

```text
Jenkins-Server
```

This name helps us identify the EC2 instance.

### Step 4: Select Operating System

Under Application and OS Images (AMI):

1. Select Ubuntu.
2. Choose an Ubuntu Server LTS image.
3. Prefer the latest supported Ubuntu LTS image available in your region.

For this training, we will use Ubuntu Server 24.04 LTS if available.

**Why do we select an AMI?**

AMI stands for Amazon Machine Image.

It is a template used to create an EC2 instance.

An AMI contains the operating system and may include additional software.

### Step 5: Select Instance Type

Choose:

```text
Instance Type: t3.medium
```

This provides:

- 2 vCPUs.
- 4 GiB memory.

We can change the instance type later if our practical requirements increase.

### Step 6: Create a Key Pair

Under Key pair (login), select:

**Create new key pair**

Enter:

```text
Key Pair Name: jenkins-key
Key Pair Type: RSA
Private Key File Format: .pem
```

Click **Create key pair**.

Your browser will download:

```text
jenkins-key.pem
```

### Why Do We Need a Key Pair?

AWS uses key pairs to authenticate SSH connections.

The key pair contains:

- Public key: Stored by AWS for the EC2 instance.
- Private key: Downloaded and securely stored on your computer.

We use the private key to connect to our Linux server.

**Important:**

- Never share your `.pem` file.
- Never upload it to GitHub.
- Do not delete it.
- Keep it in a secure location.

Example Windows location:

```text
C:\AWS\jenkins-key.pem
```

Create the `C:\AWS` folder if it does not already exist.

### Step 7: Configure Network Settings

Under Network settings, configure the security group.

Select:

**Create security group**

Enter:

```text
Security Group Name: Jenkins-SG
Description: Security group for Jenkins EC2 server
```

Add the following inbound rules:

| Type | Protocol | Port | Source |
|---|---|---|---|
| SSH | TCP | 22 | My IP |
| Custom TCP | TCP | 8080 | My IP |

### Why Do We Need Port 22?

Port 22 is the default SSH port.

We use it to connect to the Linux server from our Windows computer.

### Why Do We Need Port 8080?

Port 8080 is the default Jenkins web interface port.

We use it to access Jenkins through a browser.

Example:

```text
http://EC2-PUBLIC-IP:8080
```

### Why Should We Select My IP?

Selecting My IP restricts access to your current public IP address.

This is safer than allowing access from every IP address.

Avoid using:

```text
0.0.0.0/0
```

for SSH or Jenkins access unless there is a specific, secured reason.

If your public IP changes, you may need to update the security group rule.

### Step 8: Configure Storage

Under Configure storage, select:

```text
Volume Type: General Purpose SSD (gp3)
Size: 20 GiB
```

### Why Do We Need Storage?

Jenkins stores:

- Configuration files.
- Installed plugins.
- Build history.
- Console logs.
- Workspace files.
- Job information.

All these consume disk space.

We can increase storage later if required.

### Step 9: Review Configuration

Before launching, verify:

```text
Instance Name: Jenkins-Server
Operating System: Ubuntu Server LTS
Instance Type: t3.medium
Key Pair: jenkins-key
Security Group: Jenkins-SG
Storage: 20 GiB
Region: ap-south-1
```

Click:

**Launch instance**

---

## 5.5 Verify EC2 Instance

After launching:

1. Open EC2.
2. Select Instances.
3. Locate `Jenkins-Server`.
4. Wait until Instance state shows `Running`.
5. Wait until Status check shows `2/2 checks passed`.

### Important EC2 Information

Select the instance and note the following:

| Information | Purpose |
|---|---|
| Instance ID | Unique EC2 identifier |
| Public IPv4 address | Used to connect from the internet |
| Private IPv4 address | Used for internal VPC communication |
| Instance state | Shows whether the instance is running |
| Availability Zone | Shows the physical AWS availability zone |

We will need the Public IPv4 address to connect to Jenkins.

---

## 5.6 Connect to EC2 from Windows 11

We will use PowerShell to connect to our Ubuntu server.

### Step 1: Open PowerShell

Press:

```text
Windows Key + X
```

Select:

```text
Terminal
```

Open a PowerShell tab.

### Step 2: Navigate to the Key Location

If your private key is stored in `C:\AWS`:

```powershell
cd C:\AWS
```

### Step 3: Connect Using SSH

Execute:

```powershell
ssh -i "jenkins-key.pem" ubuntu@YOUR_PUBLIC_IP
```

Replace `YOUR_PUBLIC_IP` with the public IPv4 address of your EC2 instance.

Example format:

```powershell
ssh -i "jenkins-key.pem" ubuntu@13.xxx.xxx.xxx
```

When connecting for the first time, you may see a confirmation message.

Type:

```text
yes
```

You should now be connected to your Ubuntu EC2 instance.

### Why Do We Use the ubuntu Username?

AWS Ubuntu AMIs use `ubuntu` as their default SSH username.

If we were using Amazon Linux, the default username would normally be `ec2-user`.

---

## 5.7 Verify the Linux Server

After connecting, execute:

```bash
whoami
```

Expected output:

```text
ubuntu
```

Check the operating system:

```bash
cat /etc/os-release
```

Check the server hostname:

```bash
hostname
```

Check the available memory:

```bash
free -h
```

Check disk space:

```bash
df -h
```

### Why Are We Verifying These Details?

Before installing Jenkins, we must confirm:

- We connected to the correct EC2 instance.
- The expected Linux distribution is installed.
- The server has sufficient memory.
- The server has sufficient disk space.

---

## 5.8 Access Jenkins Port

After Jenkins is installed and running, we will access it through:

```text
http://YOUR_PUBLIC_IP:8080
```

At this stage, Jenkins is not installed yet.

Therefore, opening this URL will not show the Jenkins dashboard.

We will configure and verify Jenkins access in a later lesson.

---

## 5.9 Security Best Practices

Follow these practices while working with AWS EC2:

1. Never share your private key.
2. Never upload private keys to GitHub.
3. Restrict SSH access to your own IP.
4. Restrict Jenkins access to trusted IP addresses.
5. Do not expose Jenkins publicly without proper security controls.
6. Use strong administrator credentials.
7. Stop or terminate unused EC2 resources.
8. Monitor AWS costs regularly.

---

## 5.10 Practical Exercise

Complete the following tasks:

- [ ] Open AWS Management Console.
- [ ] Select Mumbai region (`ap-south-1`).
- [ ] Open EC2.
- [ ] Launch an Ubuntu Server LTS instance.
- [ ] Select `t3.medium`.
- [ ] Create the `jenkins-key` key pair.
- [ ] Create the `Jenkins-SG` security group.
- [ ] Configure SSH port 22 with My IP.
- [ ] Configure Jenkins port 8080 with My IP.
- [ ] Configure 20 GiB gp3 storage.
- [ ] Launch the instance.
- [ ] Wait for 2/2 status checks.
- [ ] Connect using SSH from Windows 11.
- [ ] Verify the Linux operating system.

---

## 5.11 What We Learned

In this lesson, we learned:

- What AWS EC2 is.
- Why Jenkins needs a server.
- How to select an operating system.
- How to select an EC2 instance type.
- How to create an SSH key pair.
- How to configure a security group.
- Why ports 22 and 8080 are required.
- How to configure EC2 storage.
- How to connect to Ubuntu from Windows 11.
- How to verify our EC2 server.

---

## 5.12 Next Lesson

**Document:** `06-Linux-Server-Preparation-for-Jenkins.md`

In the next lesson, we will learn:

1. Linux operating system verification.
2. Linux package management.
3. Updating Ubuntu packages.
4. Understanding Java requirements.
5. Installing Java.
6. Verifying Java installation.
7. Checking disk space and memory before Jenkins installation.

After completing the Linux preparation, we will install Jenkins.
