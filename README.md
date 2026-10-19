<div align="center">

# 🌐 Website - Visual Testing


### A Comparator helping by regression Testing and provides a short report at the end !!

<img width="949" height="623" alt="Screenshot 2026-10-16 110457" src="https://github.com/user-attachments/assets/6ceea101-ff01-48eb-b333-801fa49f4fb3" />


---

## 🌍 Why This Exists
A lot of companies nowadays are trying to implement or have a short visual test of a website with a short report at the end, and this little experimental repo shows an easy way to solve this challenge using ImageMagick, Playwright, JavaScript, and PowerShell.

---

## 🎛️ What This Thing Does
The concept looks really simple:
 First steps: make full screenshots of all possible pages available or accessible from the web app or website with the Script.

 Rename the first generated repo as **baseline**.
 
 Then, a couple of hours later, run the Script again, of course after installing and setting all possible requirements
 Wait for the process to finish.
 
 (Process ended) A dashboard with results of the comparison between the baseline and the current State of the Website screenshots should be visible.


## ⚡ Quick Start

 ``git clone https://github.com/EddylianOrigin/TestsVisual.git``

 ``cd to the repo path``
 
 ``powershell -ExecutionPolicy Bypass -File install.ps1``

 Run the Script using this command, or configure the test-visuel script aligned with your requirements before running it:
  `` .\test-visuel.ps1 -BaseDir "C:\Tests" -MaxPages 500 ``

(**Remarks:** The dependencies should be installed automatically after the previous steps. If not, follow the Steps below or debug yourself. 😉 )

 Clone the Repo locally

 Sometimes you could need to install dotnet with ``dotnet install`` (if it has not been done automatically)

 Download ImageMagick using the Winget command: ``winget install ImageMagick.ImageMagick``

 Install Playwright using the command: ``npx playwright install``

 Set the URL of your website in the script "test-visuel.ps1" and adapt the configs aligned with your level of tolerance

 Run the Script using this command:
  `` .\test-visuel.ps1 -BaseDir "C:\Tests" -MaxPages 500 ``
  
**Wait for the process to end**

**See the results**
  
  **Remarks:** If nothing happens, you should get an error message showing you the missing files or libraries and advice.

### Expected Dependencies
 .NET 8+

 Node.js 20+

 Playwright

 ImageMagick 7.x (Q16 HDRI)

	Remarks: No ImageMagick Download: https://imagemagick.org/script/download.php
---



## 🧭 What's Next

**First — thank you to everyone who is going to test this little experimental tool**

**Please don't forget to like the repo to encourage me**.

**Let's see, guys... 😉**

**🌐 Website - Visual Testing**

</div>
