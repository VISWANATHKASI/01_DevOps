
METHOD 1: CONNECT USING USERNAME AND PASSWORD
=============================================
SECURITY RECOMMENDATION: For AWS EC2 instances, SSH key authentication is the recommended and more secure method. Password authentication is generally disabled by 
default because it is more vulnerable to brute-force attacks.

If you enable password authentication:
    1. Restrict SSH access in the EC2 Security Group to your own public IP address.
    2. Never allow SSH access from everywhere (0.0.0.0/0) unless absolutely necessary.
    3. Use a strong password.
    4. Prefer SSH key authentication for production servers.


# create a user
sudo useradd -m -s /bin/bash viswa    --> -m --> creates /home/viswa directory
                                          -s --> sets bash as the user’s login shell


# set password before enabling passwd authentication
sudo passwd viswa


# config ssh password authentication
sudo vi /etc/ssh/sshd_config

# make below changes
PasswordAuthentication yes
PubkeyAuthentication yes

# Validate the configuration before restarting:
sudo sshd -t
# No output means the configuration passed validation.
# An error means fix the configuration before restarting.

# restart ssh 
sudo systemctl restart sshd
sudo systemctl status sshd


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

#delete user
userdel viswa   # --> it deletes user only, not user home directory
# IMPORTANT: Check for running processes, scheduled jobs, and files owned by the user before deleting the account.

#delete user home directory also
userdel -r viswa  # --> -r - deletes user home directory also
# IMPORTANT: Check for running processes, scheduled jobs, and files owned by the user before deleting the account.

============================================================================================================================

Method 2: connecting using ssh private key & public key
=======================================================

# create a user
sudo useradd -m -s /bin/bash viswa    --> -m --> creates /home/viswa directory
                                          -s --> sets bash as the user’s login shell


# change to viswa
su - viswa

mkdir -p /home/viswa/.ssh
chmod 700 /home/viswa/.ssh

cd /home/viswa/.ssh

# create ssh keys
ssh-keygen -t ed25519

touch authorized_keys

sudo chown -R viswa:viswa /home/viswa
sudo chmod 755 /home/viswa
sudo chmod 700 /home/viswa/.ssh
sudo chmod 644 /home/viswa/.ssh/id_ed25519.pub
sudo chmod 600 /home/viswa/.ssh/id_ed25519
sudo chmod 600 /home/viswa/.ssh/authorized_keys


# copy public key to authorized_keys
cat id_ed25519.pub >> authorized_keys
     or
grep -qxF "$(cat /home/viswa/.ssh/id_ed25519.pub)" /home/viswa/.ssh/authorized_keys || cat /home/viswa/.ssh/id_ed25519.pub >> /home/viswa/.ssh/authorized_keys

$(cat id_ed25519.pub)  --> executes the command
                       --> catch the results
                       --> removes trailing newline characters
                       --> provide the value to corresponding command


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

#connect to ec2-instance
ssh -i id_ed25519 viswa@123.45.67.5



                 or


# create a user
sudo useradd -m -s /bin/bash viswa    --> -m --> creates /home/viswa directory
                                          -s --> sets bash as the user’s login shell


sudo mkdir -p /home/viswa/.ssh/
sudo touch /home/viswa/.ssh/authorized_keys
                
# Best method: create ssh-keys in your local machine and copy to ec2-istance
ssh-keygen -t ed25519 -f viswa

# get pub key in local
cat viswa.pub

cd /home/viswa/.ssh
# copy local machine pub key in ec2-instance
#sudo sh -c 'echo "PASTE_COMPLETE_PUBLIC_KEY_HERE" >> authorized_keys'
grep -qxF "PASTE_COMPLETE_PUBLIC_KEY_HERE" authorized_keys || echo "PASTE_COMPLETE_PUBLIC_KEY_HERE" >> authorized_keys

-q --> quiet mode
-x --> match entire text
-F --> treat special characters as normal text

echo "$?"
0 --> match
1 --> no match
other --> error


#remove duplicate entries from authorized_keys
cp authorized_keys authorized_keys.backup
awk '!seen[$0]++' authorized_keys > authorized_keys.tmp && mv authorized_keys.tmp authorized_keys



sudo chown -R viswa:viswa /home/viswa
sudo chmod 755 /home/viswa
sudo chmod 700 /home/viswa/.ssh
sudo chmod 600 /home/viswa/.ssh/authorized_keys

ls -ld /home/viswa /home/viswa/.ssh
ls -l /home/viswa/.ssh/authorized_keys

# connect to ec2 instance
ssh -i viswa viswa@54.210.100.25 

# verify user
whoami

# disconnect from the user
exit   or   ctrl+D


# Before deleting, check for running processes
ps -u viswa

#delete user
userdel viswa   # --> it deletes user only, not user home directory
# IMPORTANT: Check for running processes, scheduled jobs, and files owned by the user before deleting the account.

#delete user home directory also
userdel -r viswa  # --> -r - deletes user home directory also
# IMPORTANT: Check for running processes, scheduled jobs, and files owned by the user before deleting the account.




