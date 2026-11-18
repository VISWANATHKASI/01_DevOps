
# Linux Wheel Group Management

In Linux, the `wheel` group is a special group used to grant users administrative privileges through `sudo`.

Instead of adding sudo permissions individually in the `/etc/sudoers` file, you can add users to the `wheel` group.

**Note:**
- `wheel` is commonly used in Amazon Linux, RHEL, CentOS, and Fedora.
- Ubuntu and Debian generally use the `sudo` group instead.

---

## 1. Verify Whether the Wheel Group Is Enabled

Check the sudoers configuration to verify whether the `wheel` group has sudo privileges.

```bash
grep wheel /etc/sudoers
```

### Typical Working Output

```text
%wheel ALL=(ALL) ALL
```

**Meaning:**

All users belonging to the `wheel` group can execute any command as any user using `sudo`.

### If the Rule Is Commented

Example:

```text
# %wheel ALL=(ALL) ALL
```

The `#` symbol indicates that the rule is commented out and is not active.

To enable it:

```bash
sudo visudo
```

Find the following line:

```text
# %wheel ALL=(ALL) ALL
```

Remove the `#` symbol:

```text
%wheel ALL=(ALL) ALL
```

Save and exit.

---

## 2. Add a User to the Wheel Group

To grant sudo privileges to the user `viswa`, execute:

```bash
sudo usermod -aG wheel viswa
```

### Command Explanation

| Option | Description |
|---|---|
| `usermod` | Modifies an existing Linux user account. |
| `-a` | Appends the user to additional groups without removing existing supplementary groups. |
| `-G` | Specifies the supplementary groups. |
| `wheel` | Group that provides sudo privileges. |
| `viswa` | Username to be added. |

**Important:** Always use `-aG` instead of `-G` alone. Using `-G` without `-a` can remove the user from other supplementary groups.

---

## 3. Verify the User's Group Membership

Execute:

```bash
groups viswa
```

Expected output:

```text
viswa : viswa wheel
```

This confirms that `viswa` belongs to the `wheel` group.

You can also verify using:

```bash
id viswa
```

Example output:

```text
uid=1001(viswa) gid=1001(viswa) groups=1001(viswa),10(wheel)
```

---

## 4. Verify Sudo Access

Switch to the `viswa` user:

```bash
su - viswa
```

Check sudo permissions:

```bash
sudo -l
```

Test sudo access:

```bash
sudo whoami
```

Expected output:

```text
root
```

This confirms that the user can execute commands with root privileges.

**Note:** If the user is already logged in when added to the `wheel` group, start a new login session for the updated group membership to take effect.

---

# Remove a User from the Wheel Group

If you want to revoke sudo privileges from the user `viswa`, remove the user from the `wheel` group.

## 1. Remove User from the Wheel Group

Execute:

```bash
sudo gpasswd -d viswa wheel
```

Example output:

```text
Removing user viswa from group wheel
```

### Command Explanation

| Component | Description |
|---|---|
| `gpasswd` | Manages Linux group membership. |
| `-d` | Deletes a user from a group. |
| `viswa` | Username to remove. |
| `wheel` | Group from which the user is removed. |

## 2. Verify Group Membership

Execute:

```bash
groups viswa
```

Expected output:

```text
viswa : viswa
```

The `wheel` group should no longer appear in the output.

## 3. Verify Sudo Access Is Removed

Switch to the user:

```bash
su - viswa
```

Execute:

```bash
sudo -l
```

If the user has no other sudo permissions, the output should indicate that the user is not allowed to run sudo commands.

---

# Quick Reference

| Task | Command |
|---|---|
| Check wheel sudo configuration | `grep wheel /etc/sudoers` |
| Edit sudoers safely | `sudo visudo` |
| Add user to wheel group | `sudo usermod -aG wheel viswa` |
| Verify group membership | `groups viswa` |
| Check user ID and groups | `id viswa` |
| Check sudo permissions | `sudo -l` |
| Test root access | `sudo whoami` |
| Remove user from wheel group | `sudo gpasswd -d viswa wheel` |
| Verify sudoers syntax | `sudo visudo -c` |

---

# Key Takeaways

1. The `wheel` group is commonly used to manage sudo privileges in RHEL-based Linux distributions.
2. `%wheel ALL=(ALL) ALL` grants full sudo privileges to wheel group members.
3. Use `usermod -aG wheel username` to add a user to the wheel group.
4. Use `gpasswd -d username wheel` to remove a user from the wheel group.
5. Always verify group membership using `groups username` or `id username`.
6. Use `sudo -l` to check sudo permissions.
7. Removing a user from the wheel group does not remove other individually assigned sudo permissions.
8. Follow the principle of least privilege when granting administrative access.
