powershell.exe -executionpolicy unrestricted -command ".\Documents\install-java.ps1"
powershell.exe -executionpolicy unrestricted -command ".\Documents\install-selenium.ps1 -hub localhost"
powershell.exe -executionpolicy unrestricted -command ".Documents\install-selenium-node.ps1 -nodes ie,chrome,firefox -hub 192.168.1.1"
