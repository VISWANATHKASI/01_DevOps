
# Linux Sudoers Configuration

The `/etc/sudoers` file controls which users and groups can execute commands with elevated privileges using `sudo`.

Using sudoers rules, we can control:

- **Who:** Which user or group can execute commands.
- **Where:** On which server or host the commands can be executed.
- **As Whom:** Which user the commands can be executed as (root or another user).
- **What:** Which commands the user is allowed to execute.

---

## 1. Basic Sudoers Syntax

```text
USER  HOSTS  =  (RUN_AS_USERS)  COMMANDS
```

| Component | Description |
|---|---|
| USER | Username or group receiving sudo permissions. |
| HOSTS | Hostname or IP address where the rule applies. |
| RUN_AS_USERS | User account under which the command will execute. |
| COMMANDS | Commands the user is allowed to execute. |

**Example:**

```text
viswa ALL=(ALL) ALL
```

Explanation:

- `viswa` → Username.
- `ALL` → Applies to all hosts.
- `(ALL)` → Can execute commands as any user.
- `ALL` → Can execute any command.

**Meaning:** User `viswa` can execute any command as any user on all hosts, subject to sudo authentication requirements.

---

## 2. Common Sudoers Rules

| Sudoers Entry | Meaning |
|---|---|
| `viswa ALL=(ALL) ALL` | `viswa` can run any command as any user. |
| `viswa ALL=(root) ALL` | `viswa` can run any command as root. |
| `viswa ALL=(ALL) /usr/bin/systemctl` | `viswa` can run only `systemctl` as any user. |
| `viswa ALL=(root) /usr/bin/systemctl` | `viswa` can run `systemctl` only as root. |
| `viswa ALL=(root) /usr/bin/systemctl restart nginx` | `viswa` can restart nginx only. |
| `viswa ALL=(root) /usr/bin/systemctl restart nginx, /usr/bin/systemctl status nginx` | `viswa` can restart and check the status of nginx only. |
| `viswa ALL=(root) /usr/bin/journalctl` | `viswa` can run `journalctl` as root. |
| `viswa ALL=(root) /usr/bin/tail /var/log/messages` | `viswa` can use `tail` on `/var/log/messages` only. |
| `%developers ALL=(ALL) ALL` | All users in the `developers` group get full sudo access. |
| `%developers ALL=(root) /usr/bin/systemctl` | Users in the `developers` group can run `systemctl` as root. |

**Note:** Command restrictions depend on the exact command and argument matching supported by sudoers. Allowing a command such as `systemctl` without restricting its arguments can provide broader privileges than intended.

---

## 3. NOPASSWD: Execute Commands Without a Password

By default, sudo may ask the user for their password before executing an authorized command.

Using `NOPASSWD`, we can allow specific commands to execute without a password prompt.

**Example:**

```text
viswa ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx
```

**Meaning:**

User `viswa` can restart nginx as root without entering a password.

Execute:

```bash
sudo /usr/bin/systemctl restart nginx
```

**Important:** Use `NOPASSWD` only when required. Avoid granting passwordless access to unrestricted or powerful commands.

---

## 4. Restrict Sudo Access to Specific Hosts

You can configure sudo permissions for specific servers using hostnames or IP addresses.

### Example 1: Access on One Server

```text
viswa server1=(ALL) ALL
```

**Meaning:** User `viswa` has full sudo access on `server1` only.

### Example 2: Access on Multiple Servers

```text
viswa server1,server2,server3=(ALL) ALL
```

**Meaning:** User `viswa` has full sudo access on `server1`, `server2`, and `server3`.

### Example 3: Access on One IP Address

```text
viswa 192.168.1.10=(ALL) ALL
```

**Meaning:** User `viswa` has full sudo access on `192.168.1.10` only.

### Example 4: Access on Multiple IP Addresses

```text
viswa 192.168.1.10,192.168.1.20=(ALL) ALL
```

**Meaning:** User `viswa` has full sudo access on the specified IP addresses.

**Note:** The `HOSTS` field matches the hostname of the machine where sudo is being executed, not the remote destination of an SSH connection.

---

## 5. How to Configure Sudoers

### Step 1: Open the Sudoers File

Always use `visudo` instead of directly editing `/etc/sudoers`.

```bash
sudo visudo
```

### Step 2: Add the Sudoers Rule

Example:

```text
viswa ALL=(ALL) ALL
```

Save and exit.

### Step 3: Verify Sudo Permissions

Switch to the `viswa` user:

```bash
su - viswa
```

Check the allowed sudo commands:

```bash
sudo -l
```

### Step 4: Test Sudo Access

Execute:

```bash
sudo whoami
```

Expected output:

```text
root
```

This confirms that `viswa` can execute the command with root privileges.

---

## 6. Recommended Approach: Create a Separate Sudoers File

Instead of modifying the main `/etc/sudoers` file, you can create a separate configuration file under `/etc/sudoers.d/`.

### Step 1: Create a Sudoers File

```bash
sudo visudo -f /etc/sudoers.d/viswa
```

### Step 2: Add the Rule

```text
viswa ALL=(ALL) ALL
```

### Step 3: Verify Permissions

```bash
sudo chmod 440 /etc/sudoers.d/viswa
```

### Step 4: Validate the Sudoers Configuration

```bash
sudo visudo -c
```

Expected output:

```text
/etc/sudoers: parsed OK
/etc/sudoers.d/viswa: parsed OK
```

---

## 7. Quick Reference

| Requirement | Sudoers Rule |
|---|---|
| Full sudo access | `viswa ALL=(ALL) ALL` |
| Root-only access | `viswa ALL=(root) ALL` |
| Specific command access | `viswa ALL=(root) /usr/bin/systemctl` |
| Restart nginx only | `viswa ALL=(root) /usr/bin/systemctl restart nginx` |
| Passwordless command | `viswa ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx` |
| Group-based sudo | `%developers ALL=(ALL) ALL` |
| Specific host access | `viswa server1=(ALL) ALL` |

---

## 8. Important Sudoers Commands

| Command | Description |
|---|---|
| `sudo visudo` | Safely edit the main sudoers file. |
| `sudo visudo -f /etc/sudoers.d/viswa` | Edit a separate sudoers configuration file. |
| `sudo visudo -c` | Validate sudoers configuration syntax. |
| `sudo -l` | Display commands the current user is allowed to execute using sudo. |
| `sudo whoami` | Verify execution with elevated privileges. |
| `sudo -u viswa whoami` | Execute a command as user `viswa`. |
| `sudo -i` | Open an interactive root login shell. |

---

## Key Takeaways

1. The `/etc/sudoers` file controls sudo permissions in Linux.
2. Always use `visudo` to modify sudoers configuration safely.
3. `ALL` represents all applicable users, hosts, or commands depending on its position.
4. `(root)` allows commands to execute as root.
5. `NOPASSWD` allows authorized commands to execute without a password prompt.
6. `%developers` represents the Linux group named `developers`.
7. Use `/etc/sudoers.d/` to maintain separate sudo configuration files.
8. Use `sudo -l` to check user sudo permissions.
9. Use `sudo visudo -c` to validate sudoers configuration.
10. Follow the principle of least privilege: grant users only the permissions they actually need.
