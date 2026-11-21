
METHOD 1: CONNECT USING USERNAME AND PASSWORD
=============================================
SECURITY RECOMMENDATION: For AWS EC2 instances, SSH key authentication is the recommended and more secure method. Password authentication is generally disabled by 
default because it is more vulnerable to brute-force attacks.

If you enable password authentication:
    1. Restrict SSH access in the EC2 Security Group to your own public IP address.
    2. Never allow SSH access from everywhere (0.0.0.0/0) unless absolutely necessary.
    3. Use a strong password.
    4. Prefer SSH key authentication for production servers.


# switch to root user
sudo -i

# create a user
useradd -m -s /bin/bash viswa    --> -m --> creates /home/viswa directory
                                          -s --> sets bash as the user’s login shell


# Check whether the user was created successfully
id viswa               # id viswa – Displays UID, GID and group memberships.
getent passwd viswa    # getent passwd viswa – Checks whether the user exists in the system user database.


# set password before enabling passwd authentication
passwd viswa


# Check password status
passwd -S viswa    # --> Displays whether the account has a password and its status.


# config ssh password authentication
vi /etc/ssh/sshd_config

# make below changes
PasswordAuthentication yes
PubkeyAuthentication yes


# Check SSH configuration for duplicate settings
grep -nE '^(Include|PasswordAuthentication|PubkeyAuthentication|KbdInteractiveAuthentication|AuthenticationMethods)' /etc/ssh/sshd_config

sshd -T -C user=viswa,host=DESKTOP-DC1KR2F,addr=205.254.168.201 | grep -E 'passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication'

sshd -T  --> Displays the effective SSH server configuration. Does not start or restart the SSH service. Does not modify the configuration.
sshd -T -C user=viswa,host=DESKTOP-DC1KR2F,addr=205.254.168.201 --> user=viswa – We are checking configuration for user viswa.
                                                           host=localhost – We are supplying localhost as the client hostname.
                                                           addr=203.0.113.10 – We are supplying the client IP address for matching purposes.
                                                           Replace 203.0.113.10 with your actual Windows machine public IP address.

# execute below command in windows (localmachine) for host
hostname
# execute below command in windows power shell for addr
(Invoke-RestMethod https://api.ipify.org)



# Validate the configuration before restarting:
sshd -t
# No output means the configuration passed validation.
# An error means fix the configuration before restarting.


# restart ssh 
systemctl restart sshd
systemctl status sshd

# Check SSH listening port
ss -tlnp | grep ssh


Note: to prevent accidentally locking yourself out.
1. Don not disconnect your existing EC2 session. 
2. Open another terminal and test password authentication. 
3. Only close the original session after confirming the new connection works

# connect to ec2 instance
ssh viswa@54.210.100.25 # enter password then promoted

# verify user
whoami

# disconnect from the user
exit   or   ctrl+D

# Before deleting, check for running processes
ps -u viswa

# Delete user but keep home directory
userdel viswa   # --> it deletes user only, not user home directory
# IMPORTANT: Check for running processes, scheduled jobs, and files owned by the user before deleting the account.

# Delete user and home directory
userdel -r viswa  # --> -r - deletes user home directory also
# IMPORTANT: Check for running processes, scheduled jobs, and files owned by the user before deleting the account.


============================================================================================================================

Method 2: connecting using ssh private key & public key
=======================================================

# switch to root user
sudo -i

# create a user
useradd -m -s /bin/bash viswa    --> -m --> creates /home/viswa directory
                                          -s --> sets bash as the user’s login shell


# Check whether the user was created successfully
id viswa               # id viswa – Displays UID, GID and group memberships.
getent passwd viswa    # getent passwd viswa – Checks whether the user exists in the system user database.


# change to viswa
su - viswa

mkdir -p /home/viswa/.ssh
chmod 700 /home/viswa/.ssh

cd /home/viswa/.ssh

# create ssh keys in /home/viswa
ssh-keygen -t ed25519

touch authorized_keys


# copy public key to authorized_keys
cat id_ed25519.pub >> authorized_keys
     or
grep -qxF "$(cat /home/viswa/.ssh/id_ed25519.pub)" /home/viswa/.ssh/authorized_keys || cat /home/viswa/.ssh/id_ed25519.pub >> /home/viswa/.ssh/authorized_keys

$(cat /home/viswa/.ssh/id_ed25519.pub)  --> $() is called command substitution.
                                        --> Executes the command inside the parentheses.
                                        --> Replaces the expression with the commands output.
                                        --> Removes trailing newline characters from command substitution output.


# switch back to root user
exit
# sudo -i


chown -R viswa:viswa /home/viswa
chmod 755 /home/viswa
chmod 700 /home/viswa/.ssh
chmod 644 /home/viswa/.ssh/id_ed25519.pub
chmod 600 /home/viswa/.ssh/id_ed25519
chmod 600 /home/viswa/.ssh/authorized_keys


ls -ld /home/viswa /home/viswa/.ssh
ls -l /home/viswa/.ssh/authorized_keys




# copy id_ed25519 file to /home/ec2-user as root user to download to local
sudo cp /home/viswa/.ssh/id_ed25519 /home/ec2-user/
sudo chown ec2-user:ec2-user /home/ec2-user/id_ed25519
sudo chmod 600 /home/ec2-user/id_ed25519

# to download to local
scp -i chandra.mum.pem ec2-user@123.45.67.5:/home/ec2-user/id_ed25519 ./

# change permissions to downloaded file in local
chmod 600 id_ed25519

# remove key in ec2-user 
sudo rm /home/ec2-user/id_ed25519

# Check SSH listening port
sudo ss -tlnp | grep ssh

#connect to ec2-instance
ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no -v -i id_ed25519 viswa@54.210.100.25



                 or

                 
# LOCAL MACHINE
# Generate SSH key pair
ssh-keygen -t ed25519 -f viswa

# Set private key permission
chmod 600 viswa
chmod 644 viswa.pub

# Display fingerprint
ssh-keygen -lf viswa.pub

# Display public key
cat viswa.pub




# EC2-Instance
# switch to root user
sudo -i

# create a user
useradd -m -s /bin/bash viswa    --> -m --> creates /home/viswa directory
                                          -s --> sets bash as the user’s login shell


# Check whether the user was created successfully
id viswa               # id viswa – Displays UID, GID and group memberships.
getent passwd viswa    # getent passwd viswa – Checks whether the user exists in the system user database.


# switch to viswa
su - viswa

mkdir -p /home/viswa/.ssh/
touch /home/viswa/.ssh/authorized_keys


# in ec2-instance
cd /home/viswa/.ssh

# copy local machine pub key in ec2-instance
#sudo sh -c 'echo "PASTE_COMPLETE_PUBLIC_KEY_HERE" >> authorized_keys'
#echo "PASTE_COMPLETE_PUBLIC_KEY_HERE" | sudo tee -a /home/viswa/.ssh/authorized_keys
grep -qxF "PASTE_COMPLETE_PUBLIC_KEY_HERE" /home/viswa/.ssh/authorized_keys || echo "PASTE_COMPLETE_PUBLIC_KEY_HERE" >> /home/viswa/.ssh/authorized_keys

-q --> quiet mode
-x --> match entire text
-F --> treat special characters as normal text

echo "$?"
0 --> match
1 --> no match
other --> error

# to verify finger print
ssh-keygen -lf /home/viswa/.ssh/authorized_keys
# Compare this fingerprint with the fingerprint generated on local machine
# ssh-keygen -lf viswa.pub


#remove duplicate entries from authorized_keys
cp /home/viswa/.ssh/authorized_keys /home/viswa/.ssh/authorized_keys.21NOV2026backup
awk '!seen[$0]++' /home/viswa/.ssh/authorized_keys > /home/viswa/.ssh/authorized_keys.tmp && mv /home/viswa/.ssh/authorized_keys.tmp /home/viswa/.ssh/authorized_keys


chown -R viswa:viswa /home/viswa
chmod 755 /home/viswa
chmod 700 /home/viswa/.ssh
chmod 600 /home/viswa/.ssh/authorized_keys

ls -ld /home/viswa /home/viswa/.ssh
ls -l /home/viswa/.ssh/authorized_keys

# Check SSH listening port
sudo ss -tlnp | grep ssh

# connect to ec2 instance
ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no -v -i viswa viswa@54.210.100.25

# verify user
whoami

# disconnect from the user
exit   or   ctrl+D


# Before deleting, check for running processes
ps -u viswa

# Delete user but keep home directory
userdel viswa   # --> it deletes user only, not user home directory
# IMPORTANT: Check for running processes, scheduled jobs, and files owned by the user before deleting the account.

# Delete user and home directory
userdel -r viswa  # --> -r - deletes user home directory also
# IMPORTANT: Check for running processes, scheduled jobs, and files owned by the user before deleting the account.




