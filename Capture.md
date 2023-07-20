<h2>Target:  10.10.157.44 Capture </h2>

In order to get the flag we need to brute force the username and password.  <br>
Standard brute force attack using hydra, burp suite intruder, etc doesn't work because their is a math captcha.  

Write a script that will brute force the login and calculate the answer to the math captcha for each post request.  

The script I wrote using javascript can be found on my github page: https://github.com/AdamRose1/Captcha-Login-Bypass

To keep it simple I have split it into two scripts.  <br>
One to find the valid username, and the second to find the password for that username.  
