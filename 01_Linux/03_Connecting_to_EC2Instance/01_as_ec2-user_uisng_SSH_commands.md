
# Connect to AWS EC2 Instance Using SSH

SSH (Secure Shell) is a protocol used to securely connect to a remote Linux server over a network.

## 1. Connect to AWS EC2 Instance

### Step 1: Open the Downloads Directory

Open your terminal (Git Bash / Linux terminal) and navigate to the directory where your `.pem` key file is downloaded.

```bash
cd Downloads
```

### Step 2: Set Permissions for the PEM File

Set the private key file permissions to `400` so that only the file owner can read it.

```bash
chmod 400 chandra-nv.pem
```

**Why do we use `chmod 400`?**

- `4` = Read permission
- `0` = No write permission
- `0` = No execute permission

SSH requires the private key to have restricted permissions. Otherwise, it may reject the key with an `UNPROTECTED PRIVATE KEY FILE` warning.

### Step 3: Connect to the EC2 Instance

Execute the following SSH command:

```bash
ssh -i chandra-nv.pem ec2-user@98.81.155.74
```

**Understanding the SSH command:**

| Component | Description |
|---|---|
| `ssh` | Establishes a secure SSH connection. |
| `-i` | Specifies the identity (private key) file. |
| `chandra-nv.pem` | EC2 instance private key file. |
| `ec2-user` | Default username for Amazon Linux EC2 instances. |
| `98.81.155.74` | Public IP address of the EC2 instance. |

**Note:**
- `ec2-user` is commonly used for Amazon Linux instances.
- Ubuntu EC2 instances generally use `ubuntu` as the username.
- Ensure the EC2 instance is running and its Security Group allows inbound SSH traffic on port `22` from your public IP address.
- The PEM file must correspond to the EC2 instance's key pair.

---

## 2. Disconnect from the EC2 Instance

Once you finish working on the EC2 instance, you can disconnect using either of the following methods.

### Method 1: Using the exit Command

```bash
exit
```

### Method 2: Using the Keyboard Shortcut

Press:

```text
Ctrl + D
```

Both methods terminate the SSH session and return you to your local terminal.

---

## 3. Complete SSH Connection Workflow

```bash
# Navigate to Downloads
cd Downloads

# Set private key permissions
chmod 400 chandra-nv.pem

# Connect to EC2
ssh -i chandra-nv.pem ec2-user@98.81.155.74

# Disconnect from EC2
exit
```

---

## 4. Common SSH Connection Errors

| Error | Possible Reason | Solution |
|---|---|---|
| Permission denied (publickey) | Incorrect PEM file or username | Verify the key pair and EC2 username. |
| UNPROTECTED PRIVATE KEY FILE | Private key permissions are too open | Run `chmod 400 chandra-nv.pem`. |
| Connection timed out | Port 22 blocked or incorrect IP | Check Security Group inbound rules, network ACLs, and public IP. |
| Connection refused | SSH service may not be running or listening | Check the SSH service on the EC2 instance. |
| No such file or directory | PEM file not found in the current directory | Verify the file location and filename. |

---

## Key Takeaways

1. SSH is used to connect securely to remote Linux servers.
2. A `.pem` file acts as a private key for authentication.
3. `chmod 400` restricts access to the private key.
4. `ssh -i` specifies the private key used for authentication.
5. `exit` or `Ctrl + D` disconnects the SSH session.
6. AWS Security Groups must allow inbound SSH traffic on port `22`.
