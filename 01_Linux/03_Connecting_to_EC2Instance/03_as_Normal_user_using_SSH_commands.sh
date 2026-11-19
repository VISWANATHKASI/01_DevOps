
METHOD 1: CONNECT USING USERNAME AND PASSWORD
=============================================
SECURITY RECOMMENDATION: For AWS EC2 instances, SSH key authentication is the recommended and more secure method. Password authentication is generally disabled by default because it is more vulnerable to brute-force attacks.

If you enable password authentication:
    1. Restrict SSH access in the EC2 Security Group to your own public IP address.
    2. Never allow SSH access from everywhere (0.0.0.0/0) unless absolutely necessary.
    3. Use a strong password.
    4. Prefer SSH key authentication for production servers.


# create a user
sudo useradd -m -s /bin/bash viswa    --> -m --> creates /home/viswa directory
                                          -s --> sets bash as the user’s login shell


# config ssh password authentication
sudo vi /etc/ssh/sshd_config

# make below changes
PasswordAuthentication yes
PubkeyAuthentication yes

# restart ssh 
sudo systemctl restart sshd
sudo systemctl status sshd

# set password :
sudo passwd viswa

# connect to ec2 instance
ssh viswa@54.210.100.25 # enter password then promoted

# verify user
whoami

# disconnect from the user
exit   or   ctrl+D


#delete user
userdel viswa   # --> it deletes user only, not user home directory


#delete user home directory also
userdel -r viswa  # --> -r - deletes user home directory also


============================================================================================================================






