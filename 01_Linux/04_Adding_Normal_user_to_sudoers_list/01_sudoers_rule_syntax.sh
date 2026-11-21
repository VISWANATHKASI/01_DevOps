
Linux Sudoers Configuration
===========================
The /etc/sudoers file controls which users and groups can execute commands with elevated privileges using sudo.

Using sudoers rules, we can control:
-   Who: Which user or group can execute commands.
-   Where: On which server or host the commands can be executed.
-   As Whom: Which user the commands can be executed as (root or another
    user).
-   What: Which commands the user is allowed to execute.


Basic Sudoers Syntax
====================
USER HOSTS = (RUN_AS_USERS) COMMANDS

HOSTS         --> Hostname or IP address where the rule applies.
RUN_AS_USERS  --> User account under which the command will execute.
COMMANDS      --> Commands the user is allowed to execute.


Example:
-------
viswa ALL=(ALL) ALL      # -->  User viswa can execute any command as any user on all hosts, subject to sudo authentication requirements.

viswa: Username.
ALL: Applies to all hosts.
(ALL): Can execute commands as any user.
ALL: Can execute any command.



S.No	Sudoers Entry	Meaning
1	viswa ALL=(ALL) ALL	User viswa can run any command as any user.
2	viswa ALL=(root) ALL	User viswa can run any command as root.
3	viswa ALL=(ALL) /usr/bin/systemctl	User viswa can run only systemctl as any user.
4	viswa ALL=(root) /usr/bin/systemctl	User viswa can run systemctl as root.
5	viswa ALL=(root) /usr/bin/systemctl restart nginx	User viswa can restart nginx only.
6	viswa ALL=(root) /usr/bin/systemctl restart nginx, /usr/bin/systemctl status nginx	User viswa can restart nginx and check its status only.
7	viswa ALL=(root) /usr/bin/journalctl	User viswa can run journalctl as root.
8	viswa ALL=(root) /usr/bin/tail /var/log/messages	User viswa can use tail on /var/log/messages only.
9	%developers ALL=(ALL) ALL	All users in the developers group get full sudo access.
10	%developers ALL=(root) /usr/bin/systemctl	Users in the developers group can run systemctl as root.




Note: Command restrictions depend on the exact command and argument matching supported by sudoers. Allowing a command such as systemctl without restricting its arguments can provide broader privileges than intended.


NOPASSWD: Execute Commands Without a Password
=============================================
By default, sudo may ask the user for their password before executing an authorized command.
Using NOPASSWD, we can allow specific commands to execute without a password prompt.

Example:
viswa ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx

Meaning: User viswa can restart nginx as root without entering a password.

Execute:
sudo /usr/bin/systemctl restart nginx

Important: Use NOPASSWD only when required. Avoid granting passwordless access to unrestricted or powerful commands.



Restrict Sudo Access to Specific Hosts
======================================
You can configure sudo permissions for specific servers using hostnames or IP addresses.

Example 1: Access on One Server
viswa server1=(ALL) ALL
Meaning: User viswa has full sudo access on server1 only.

Example 2: Access on Multiple Servers
viswa server1,server2,server3=(ALL) ALL
Meaning: User viswa has full sudo access on server1, server2, and server3.

Example 3: Access on One IP Address
viswa 192.168.1.10=(ALL) ALL
Meaning: User viswa has full sudo access on 192.168.1.10 only.

Example 4: Access on Multiple IP Addresses
viswa 192.168.1.10,192.168.1.20=(ALL) ALL
Meaning: User viswa has full sudo access on the specified IP addresses.

Note: The HOSTS field matches the hostname of the machine where sudo is
being executed, not the remote destination of an SSH connection.


How to Configure Sudoers
========================
# Open the Sudoers File
# Always use visudo instead of directly editing /etc/sudoers.

sudo visudo

# Add the Sudoers Rule

viswa ALL=(ALL) ALL
Save and exit.

# Verify Sudo Permissions

#Switch to the viswa user:
su - viswa

# Check the allowed sudo commands:
sudo -l

# Test Sudo Access
sudo whoami
# Expected output: root  --> This confirms that viswa can execute the command with root privileges.


# Recommended Approach: Create a Separate Sudoers File

8. Important Sudoers Commands

-   sudo visudo Description: Safely edit the main sudoers file.
-   sudo visudo -f /etc/sudoers.d/viswa Description: Edit a separate
    sudoers configuration file.
-   sudo visudo -c Description: Validate sudoers configuration syntax.
-   sudo -l Description: Display commands the current user is allowed to
    execute using sudo.
-   sudo whoami Description: Verify execution with elevated privileges.
-   sudo -u viswa whoami Description: Execute a command as user viswa.
-   sudo -i Description: Open an interactive root login shell.





Key Takeaways
=============
1.  The /etc/sudoers file controls sudo permissions in Linux.
2.  Always use visudo to modify sudoers configuration safely.
3.  ALL represents all applicable users, hosts, or commands depending on
    its position.
4.  (root) allows commands to execute as root.
5.  NOPASSWD allows authorized commands to execute without a password
    prompt.
6.  %developers represents the Linux group named developers.
7.  Use /etc/sudoers.d/ to maintain separate sudo configuration files.
8.  Use sudo -l to check user sudo permissions.
9.  Use sudo visudo -c to validate sudoers configuration.
10. Follow the principle of least privilege: grant users only the
    permissions they actually need.
