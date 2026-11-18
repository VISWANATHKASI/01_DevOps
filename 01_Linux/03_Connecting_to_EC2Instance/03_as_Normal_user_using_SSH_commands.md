
# Linux User Management and SSH Authentication

There are two ways to connect to a Linux EC2 instance using a newly created Linux user:

1. **Method 1:** Connect using username and password.
2. **Method 2:** Connect using username and SSH key (PEM / private key).

---

# Method 1: Connect Using Username and Password

## Security Recommendation

For AWS EC2 instances, SSH key authentication is the recommended and more secure method.

Password authentication is generally disabled by default because it is more vulnerable to brute-force attacks.

If you enable password authentication:

- Restrict SSH access in the EC2 Security Group to your own public IP address.
- Never allow SSH access from everywhere (`0.0.0.0/0`) unless absolutely necessary.
- Use a strong password.
- Prefer SSH key authentication for production servers.

## Step 1: Create a Linux User

Execute the following command to create a new user named `viswa`.

```bash
sudo useradd -m -s /bin/bash viswa
```

**Command explanation:**

| Option | Description |
|---|---|
| `useradd` | Creates a new Linux user. |
| `-m` | Creates the user's home directory. |
| `-s /bin/bash` | Sets Bash as the user's login shell. |
| `viswa` | Username. |

The user's home directory will be:

```text
/home/viswa
```

## Step 2: Configure SSH Password Authentication

Open the SSH configuration file.

```bash
sudo vi /etc/ssh/sshd_config
```

Ensure the following settings are configured:

```text
PasswordAuthentication yes
PubkeyAuthentication yes
```

**Explanation:**

| Setting | Description |
|---|---|
| `PasswordAuthentication yes` | Enables SSH login using a username and password. |
| `PubkeyAuthentication yes` | Enables SSH public-key authentication. |

**Note:** Make sure these settings are not overridden by other SSH configuration files or `Match` blocks.

## Step 3: Restart the SSH Service

Restart the SSH daemon to apply the configuration changes.

```bash
sudo systemctl restart sshd
```

Verify the SSH service status:

```bash
sudo systemctl status sshd
```

## Step 4: Set a Password for the New User

Execute:

```bash
sudo passwd viswa
```

Enter the new password when prompted.

## Step 5: Connect to the EC2 Instance

From your local terminal, execute:

```bash
ssh viswa@54.210.100.25
```

When prompted:

```text
viswa@54.210.100.25's password:
```

Enter the password and press Enter.

**Note:** The password will not be displayed while typing.

## Step 6: Verify the Connected User

Execute:

```bash
whoami
```

Expected output:

```text
viswa
```

## Step 7: Disconnect from the EC2 Instance

You can disconnect using either method:

```bash
exit
```

Or press:

```text
Ctrl + D
```

Both methods terminate the SSH session.

---

# Method 2: Connect Using Username and SSH Key (PEM / Private Key)

SSH key authentication uses two keys:

- **Private Key:** Must remain securely stored on your local machine.
- **Public Key:** Must be added to the remote Linux user's `authorized_keys` file.

The public key verifies that the connecting user possesses the corresponding private key.

## Step 1: Create a Linux User

Execute:

```bash
sudo useradd -m -s /bin/bash viswa
```

This creates:

```text
/home/viswa
```

## Step 2: Generate SSH Keys

**Recommended approach:** Generate the SSH key pair on your local machine rather than generating the private key on the EC2 instance.

On your local machine, execute:

```bash
ssh-keygen -t ed25519 -f viswa_key
```

This generates two files:

```text
viswa_key       # Private key
viswa_key.pub   # Public key
```

Keep `viswa_key` securely on your local machine.

Never share or upload the private key to GitHub.

## Step 3: Create the .ssh Directory on the EC2 Instance

Connect to the EC2 instance using an existing administrator account.

Execute:

```bash
sudo mkdir -p /home/viswa/.ssh
```

Set ownership:

```bash
sudo chown -R viswa:viswa /home/viswa/.ssh
```

Set directory permissions:

```bash
sudo chmod 700 /home/viswa/.ssh
```

## Step 4: Add the Public Key to authorized_keys

From your local machine, display the public key:

```bash
cat viswa_key.pub
```

Copy the complete public key.

On the EC2 instance, add it to the new user's `authorized_keys` file:

```bash
sudo sh -c 'echo "PASTE_PUBLIC_KEY_HERE" >> /home/viswa/.ssh/authorized_keys'
```

Set ownership:

```bash
sudo chown viswa:viswa /home/viswa/.ssh/authorized_keys
```

Set permissions:

```bash
sudo chmod 600 /home/viswa/.ssh/authorized_keys
```

Set the private key permissions on your local machine:

```bash
chmod 600 viswa_key
```

**Important SSH permissions:**

| File / Directory | Permission | Purpose |
|---|---|---|
| `/home/viswa/.ssh` | `700` | Only the owner can access the directory. |
| `authorized_keys` | `600` | Only the owner can read and write the file. |
| Private key | `600` | Only the owner can read and write the key. |
| Public key | `644` | Public key can be readable by others. |

## Step 5: Connect to the EC2 Instance

From your local machine, execute:

```bash
ssh -i viswa_key viswa@98.81.155.74
```

**Command explanation:**

| Component | Description |
|---|---|
| `ssh` | Establishes a secure SSH connection. |
| `-i` | Specifies the private key file. |
| `viswa_key` | Private key used for authentication. |
| `viswa` | Linux username. |
| `98.81.155.74` | Public IP address of the EC2 instance. |

## Step 6: Verify the Connected User

Execute:

```bash
whoami
```

Expected output:

```text
viswa
```

## Step 7: Disconnect from the EC2 Instance

```bash
exit
```

Or press:

```text
Ctrl + D
```

---

# Additional SSH Commands and Concepts

## 1. Copy an Existing Public Key to authorized_keys

If you already have another public key that needs to be added, use:

```bash
grep -qxF 'PUBLIC_KEY_CONTENT' /home/viswa/.ssh/authorized_keys || echo 'PUBLIC_KEY_CONTENT' >> /home/viswa/.ssh/authorized_keys
```

This checks whether the public key already exists before adding it.

### Understanding grep Options

| Option | Description |
|---|---|
| `-q` | Quiet mode; does not display output. |
| `-x` | Matches the entire line. |
| `-F` | Treats special characters as ordinary text. |

### Understanding the Command

```bash
grep -qxF 'PUBLIC_KEY_CONTENT' authorized_keys
```

Possible exit statuses:

| Exit Status | Meaning |
|---|---|
| `0` | Matching line found. |
| `1` | No matching line found. |
| Other | An error occurred. |

To check the previous command's exit status:

```bash
echo $?
```

## 2. Understanding Command Substitution: $()

`$(command)` executes a command inside `$()` and substitutes its standard output into the surrounding command.

Example:

```bash
echo "Current user: $(whoami)"
```

Output:

```text
Current user: viswa
```

Another example:

```bash
grep -qxF "$(cat id_ed25519.pub)" authorized_keys || cat id_ed25519.pub >> authorized_keys
```

Explanation:

1. `cat id_ed25519.pub` displays the public key.
2. `$(...)` captures the command output.
3. `grep -qxF` checks whether the complete public key already exists.
4. `||` executes the next command only if the previous command fails.
5. `cat ... >> authorized_keys` appends the key if it is not already present.

## 3. Remove Duplicate Entries from authorized_keys

Execute:

```bash
awk '!seen[$0]++' authorized_keys > authorized_keys.tmp && mv authorized_keys.tmp authorized_keys
```

**Explanation:**

| Component | Description |
|---|---|
| `awk` | Processes text line by line. |
| `seen[$0]++` | Tracks previously encountered lines. |
| `!` | Selects lines that have not appeared before. |
| `>` | Redirects output to a temporary file. |
| `&&` | Executes the next command only if the previous command succeeds. |
| `mv` | Replaces the original file with the temporary file. |

**Important:** Take a backup before modifying `authorized_keys`. Preserve ownership and permissions after modification.

## 4. Copy a File from EC2 to Local Machine Using SCP

Example: Copy an existing private key from an EC2 instance to your local machine.

```bash
scp -i chandra-nv.pem ec2-user@172.31.15.153:/home/ec2-user/id_rsa /c/Users/HP/Downloads/
```

**SCP command explanation:**

| Component | Description |
|---|---|
| `scp` | Securely copies files between systems. |
| `-i` | Specifies the private key used for authentication. |
| `chandra-nv.pem` | Existing private key used to connect to the source EC2 instance. |
| `ec2-user` | Remote Linux username. |
| `172.31.15.153` | Private IP of the source EC2 instance. |
| `/home/ec2-user/id_rsa` | Source file path. |
| `/c/Users/HP/Downloads/` | Destination directory on the local Windows machine when using Git Bash. |

**Security Warning:** Transferring private keys from a server to your local machine is generally not recommended. Generate new keys locally and install only the public key on the server.

## 5. Connect Using an Existing PEM File

If you have an existing private key corresponding to the public key installed in `/home/viswa/.ssh/authorized_keys`, execute:

```bash
ssh -i chandra-nv.pem viswa@98.81.155.74
```

The private key must match one of the public keys in the user's `authorized_keys` file.

---

# Delete a Linux User

To delete a Linux user, use the following commands.

## Method 1: Delete User Without Removing Home Directory

```bash
sudo userdel viswa
```

The user account is deleted, but the home directory remains.

Example:

```text
/home/viswa
```

## Method 2: Delete User Along with Home Directory

```bash
sudo userdel -r viswa
```

The `-r` option removes the user's home directory and mail spool, if present.

**Important:** Check for running processes, scheduled jobs, and files owned by the user before deleting the account.

---

# Quick Reference

| Task | Command |
|---|---|
| Create user | `sudo useradd -m -s /bin/bash viswa` |
| Set password | `sudo passwd viswa` |
| Edit SSH configuration | `sudo vi /etc/ssh/sshd_config` |
| Restart SSH | `sudo systemctl restart sshd` |
| Check SSH status | `sudo systemctl status sshd` |
| Generate SSH key | `ssh-keygen -t ed25519 -f viswa_key` |
| Create .ssh directory | `sudo mkdir -p /home/viswa/.ssh` |
| Set .ssh permissions | `sudo chmod 700 /home/viswa/.ssh` |
| Set authorized_keys permissions | `sudo chmod 600 /home/viswa/.ssh/authorized_keys` |
| Connect using password | `ssh viswa@SERVER_IP` |
| Connect using private key | `ssh -i viswa_key viswa@SERVER_IP` |
| Verify username | `whoami` |
| Disconnect | `exit` |
| Delete user | `sudo userdel viswa` |
| Delete user and home directory | `sudo userdel -r viswa` |

---

# Key Takeaways

1. Linux supports password-based and SSH key-based authentication.
2. SSH key authentication is recommended for EC2 instances.
3. The private key must remain securely stored on the local machine.
4. The public key must be added to the remote user's `authorized_keys` file.
5. Correct ownership and permissions are essential for SSH authentication.
6. The SSH service must allow the required authentication method.
7. Always restrict SSH access through AWS Security Group rules.
8. Use `whoami` to verify the currently logged-in Linux user.
