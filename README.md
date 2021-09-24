# UbntCambAuditTool


Disclaimer :D  This was written by me when I was intern in 2017. I now know that there are better solutions for remotley managing many hosts. ie Ansible and even Rundeck. However, I was not aware of these at the time so a wild mess of expect scripts was the best option at the time.

tldr; quick and dirty shell script for auditing a WISP's hosts, works reliably for Ubiquiti radios and somewhat reliably for Cambiums --> more functionality can be added with more time.  Will export as CSVs host specific information, parent child data, a CSV listing all radio level traffic shaping data and an error log that is hopelessly vauge.


Steps for use.
  1) Create directory somewhere onto your Linux filesystem, root or SU rights are usually not needed for executing the script.
  2) Download everything
  3) Add list of addresses into ./list
  4) Add plain text (yeah we all know this is a bad idea!) password(s) (yes some of us have multiple passwords that could be in use) into each "foo" string in script.  You might as well delete the other unused expect script attempts.
  5) You may need to tweak some of the hard variables such as http(s) or ssh ports if you have custom configurations
  6) Push go.
  
 Results
  1) ./results/$DATE/radioData.csv --> Here you will see information that is related to each radio in a CSV.  Just about anything can be added as we are parsing this out of config and status files.
  2) ./results/$DATE/parentChild.csv --> Here you see each AP with all the respective hosts that are connected to it
  3) ./results/$DATE/shape.csv --> Here you see information related to radio level Traffic Shaping configured.  If this file does not populate then you have nothing configured and/or enabled.
  
 Afterwards
  1) Discuss with co-workers as to why we should move away from Ubiquiti's radios, we should not have to write bash for a week straight in order to get some useful information.  UNMS and AirControl are horrible.  Ubiquiti, please fix.
