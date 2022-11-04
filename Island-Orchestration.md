**Target: 10.10.92.50 Island Orchestration**

nmap -Pn 10.10.92.50  -p- |grep open|awk -F '/' '{print $1}'|tr '\n' ','\
Output shows open ports: 22,80,8443

Enumerating these open ports further with nmap:\
nmap -Pn 10.10.92.50 --min-rate=5000 -p 22,80,8443 -sC -sV -oN nmap.island\
Output shows:

![image](https://user-images.githubusercontent.com/93153300/198814689-d0bad09e-d083-46a2-b804-d7c37b3ba84b.png)

Navigating to port 80 shows:

![image](https://user-images.githubusercontent.com/93153300/198814583-e4420ae9-57b8-41e1-87ca-60f8175a3bf3.png)
 
On the right side on the page it shows top 5 islands.  Click on any one of the top 5 islands directs the webpage to directory /?page=.  So if we click on Bali, it’ll show:

![image](https://user-images.githubusercontent.com/93153300/198814586-03415972-ef95-46af-bc58-1c40358f5ec1.png)
 
Direcotry /?page=  is sometimes vulnerable to lfi.  Trying a proof of concept with replacing bali.php with /etc/passwd shows it’s vulnerable to lfi:

![image](https://user-images.githubusercontent.com/93153300/198814603-6e3d0d84-649a-4019-9e27-4779475e2f7b.png)
 
Checking for different files with the lfi, we don’t find anything of interest.

Nmap showed port 8443 is running kubernetes.  Let's look into port 8443.  Navigating to https://10.10.92.50:8443, and viewing the certificate to the site shows:

![image](https://user-images.githubusercontent.com/93153300/198814606-804241d1-9149-485b-b060-daf452a98744.png)

This certificate indicates the target is using minikube. Minikube is a lightweight kubernetes.  Now that we know target is running minikube, let’s try and find the token it uses with our lfi exploit.  Google search for ‘where is kubernetes token directory’.  The google search shows it’s located in /var/run/secrets/kubernetes.io/serviceaccount/token

Let’s try to get the token with the lfi:\
http://10.10.92.50/?page=/var/run/secrets/kubernetes.io/serviceaccount/token \
We found the token:

![image](https://user-images.githubusercontent.com/93153300/198814613-c44db89f-3e5e-4404-aa16-c51c6668d516.png)

Now that we have the token we can run commands from the command line with kubectl. The command is made up of:\
```kubectl <server name> <token>  <bypass verifying the cert>  <action>```

Check for hidden secrets using kubectl with command: 

![image](https://user-images.githubusercontent.com/93153300/198814619-bb4abd91-025c-4486-a57b-9565633ddbdb.png)

Output on that command finds a flag:

![image](https://user-images.githubusercontent.com/93153300/198814621-2c41d108-bcf5-4620-981f-456e4f61fa2c.png)

Decode the flag with command:\
echo -n "ZmxhZ3swOGJlZDlmYzBiYzZkOTRmZmY5ZTUxZjI5MTU3Nzg0MX0="|base64 -d

This machine only has one flag, and was not made for privilege escalation to get root. So that's all for this machine.
