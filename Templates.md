**Target: 10.10.206.185 Templates**

**Initial Access:**\
nmap -Pn  10.10.206.185   --min-rate=5000 -p- |grep open |awk -F '/' '{print $1}'|tr '\n' ',' \
Output shows open ports: 22,5000

Enumerate these open ports further with nmap:\
nmap -Pn  10.10.206.185   --min-rate=5000 -p 22,5000 -sC -sV -oN nmap.templates

![image](https://user-images.githubusercontent.com/93153300/199852914-a941dbc7-166f-4733-9dfd-ade4a610d59d.png)
 
Navigate to port 5000. The page shows: 

![image](https://user-images.githubusercontent.com/93153300/199852934-8ef3de7a-4554-4f80-a3c1-c5e109eda25d.png)

It’s a pug template engine that converts pug to html.  We can enter anything we want on this page, and when we click ‘convert to html’ it shows us the input we entered in html.  So we have user input, our user input is being returned back to us, and we know this is a pug template.  This is an ideal situation to test for server site template injection.  

Google search pug ssti and you’ll find plenty of payloads.  A simple proof of concept for ssti is```#{3*3}```.  Remove the current script on the pug template, and instead insert ```#{3*3}```.  If it’s vulnerable to ssti then it should run the command 3*3 and return a value of 9.  

![image](https://user-images.githubusercontent.com/93153300/199853025-3258c492-b9e3-418c-aaeb-026e7900c417.png)

Click on convert to html at the bottom:

![image](https://user-images.githubusercontent.com/93153300/199853041-d3074e29-2e15-4bbc-8d8e-f0bf63651572.png)
 
We got a return of 9, now we know it’s vulnerable to ssti.  Use this to get a reverse shell.  Google search ‘pug template reverse shell’.  Found a few pages that showed how to get a reverse shell with a pug template using ssti (server side template injection).   Let’s open one of the pages (https://gist.githubusercontent.com/Jasemalsadi/2862619f21453e0a6ba2462f9613b49f/raw/e52a952130d102ef48b5146779249cceb3b5bf28/ssti_rev_shell_pug_node_js), it shows:

![image](https://user-images.githubusercontent.com/93153300/199852982-cd099795-7bd9-4491-80fe-8e07d2607b63.png)

Using this pug ssti reverse shell script, here are the steps to get a reverse shell with this ssti:  \
Step 1: Looking back at the reverse shell script we opened above, towards the bottom of this script it shows a coded payload.  It look likes base64, decode the payload: 

![image](https://user-images.githubusercontent.com/93153300/199853066-a3c9193d-f697-47b5-9140-26ab69f77c8b.png)
 
This payload is base64, so take the plaintext payload we just decoded and change the ip address to our ip address.  We will keep the port at 443.  \
Step 2: Now that we updated the payload to have our ip address, encode the payload back into base64: 

![image](https://user-images.githubusercontent.com/93153300/199853085-a46c570b-59d3-446d-af8e-e7bfa5978a77.png)
 
Step 3:  Put the new encoded payload back into the complete ssti reverse shell script we showed above:
 
![image](https://user-images.githubusercontent.com/93153300/199853114-ba80a499-b96a-43b5-b1c7-6ada41ca3350.png)
 
Step 4: Paste the updated ssti reverse shell script into the pug template: 

![image](https://user-images.githubusercontent.com/93153300/199853134-839bc2d1-e53b-4515-a522-b28616feac9c.png)
 
Step 5: open a netcat listener with command: nc  -lvnp 443 (I’ll use pwncat-cs -lp 443 as it gives a better shell). \
Step 6: click on convert to html at the bottom of the pug template page.  

We have shell as user, can go to /usr/src/app/flag.txt to get the flag.

*TryHackMe made this a get the flag room, not a get user and escalate to root room.  So our work here is done.   

![image](https://user-images.githubusercontent.com/93153300/199853151-296385b7-6826-454b-af0b-014ad8452f1d.png)
 
