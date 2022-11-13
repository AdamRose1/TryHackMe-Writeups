<h2>Target: 10.10.10.201  Neighbor</h2>

<b>Initial Access: </b><br>
nmap -Pn 10.10.10.201 --min-rate=5000 -p- |grep open |awk -F '/' '{print $1}'|tr '\n' ',' <br>
Output shows open ports: 22,80

Enumerate these open ports further with nmap:<br>
nmap -Pn 10.10.10.201 --min-rate=5000 -p 22,80 -sC -sV -oN nmap.neighbour

![image](https://user-images.githubusercontent.com/93153300/201550169-826007ad-dd45-4b4d-a74d-34822ed41bd6.png)
 
Visiting port 80 we find a login page:

![image](https://user-images.githubusercontent.com/93153300/201550386-05d84710-5d7a-4317-b301-36faeeef9953.png)
 
Check the source code:
 
![image](https://user-images.githubusercontent.com/93153300/201550180-151d133a-aa8d-4785-bb24-7eebeaefc703.png)

Source code shows credentials username guest and password guest .  Log in on port 80 with username guest and password guest.  
 
<b>2nd  way to find credentials:</b><br>
Run directory brute force on port 80 with dirsearch: dirsearch -r -u http://10.10.10.201  -e txt,php,html -f -o dsearch.80

Dirsearch found an interesting directory: http://10.10.10.201/db/users.sql

Visiting http://10.10.10.201/db/users.sql downloads the file users.sql.  The file shows credentials:
 
![image](https://user-images.githubusercontent.com/93153300/201550184-952d5bbb-4599-4294-8735-261a26f33f0f.png)
  
We have 2 usernames and 2 hashed passwords.  Crack these hashes to get the password.  <br>
Step 1: Place the 2 hashes in a file.  We will call the file ‘hash’.  <br>
Step 2: Check the hash type being used with command ‘nth’: nth -f hash    → The hash type is md5 <br>
Step 3: john hash --wordlist=/usr/share/wordlists/rockyou.txt --format=raw-md5 <br>
John was able to crack the guest hash, not the admin hash.  The guest password is ‘guest’. 

Log in to port 80 with credentials.  Upon logging in we get redirected to directory /profile.php with a query of ‘?user=guest’:

![image](https://user-images.githubusercontent.com/93153300/201550189-04f93a2e-041f-4630-8207-12cdc092971e.png)
 
The query of ‘?user=guest’  might be vulnerable to insecure direct object reference.  In the directory ‘db/users.sql’ that we found earlier with dirsearch we saw that there is a username ‘admin’.  Change the query from ‘?user=guest’ to ‘?user=admin’: 
 
![image](https://user-images.githubusercontent.com/93153300/201550197-cd6aeed7-40c5-4960-89df-bfb9643bbdda.png)
 
The site was vulnerable to insecure direct object reference, we can grab the flag.  

*TryHackMe made this machine as a capture the flag, there is nothing further to do.
