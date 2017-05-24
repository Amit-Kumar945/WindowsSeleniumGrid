Param(
  [Parameter(Mandatory=$True)]
  [string[]]$nodes,
  [string]$hub
)
$nodes = $nodes | sort -unique
Add-WindowsFeature NET-Framework-Core -Source C:\sources\sxs
$serviceName = 'selenium-node'
$installPath = 'C:\Selenium'
$download = @{
  "selenium-server-standalone.jar" = "http://selenium-release.storage.googleapis.com/3.4/selenium-server-standalone-3.4.0.jar";
  "${serviceName}.exe" = "http://repo.jenkins-ci.org/releases/com/sun/winsw/winsw/1.13/winsw-1.13-bin.exe"
}
$argument = New-Object System.Collections.ArrayList
$argument.Add("-jar ${installPath}\selenium-server-standalone.jar") > $null
$argument.Add("-role node") > $null
$argument.Add("-hub http://${hub}:4444/grid/register") > $null

foreach ($node in $nodes) {
  switch ($node.ToUpper()) {
    "IE" {
      $ver = [int](Get-Item ('HKLM:\Software\Microsoft\Internet Explorer\Version Vector')).GetValue("IE")
      $argument.Add("-Dwebdriver.ie.driver=`"${installPath}\ie-driver.exe`"") > $null
      $argument.Add("-browser `"browserName=internet explorer,version=${ver},maxInstances=1,platform=WINDOWS`"") > $null
      $download.Add("ie-driver.zip", "https://selenium.googlecode.com/files/IEDriverServer_Win32_2.33.0.zip")
    }
    "CHROME" {
      $argument.Add("-Dwebdriver.chrome.driver=`"${installPath}\chrome-driver.exe`"") > $null
      $argument.Add("-browser `"browserName=chrome,maxInstances=1,platform=WINDOWS`"") > $null
      $download.Add("chrome-driver.zip", "https://chromedriver.googlecode.com/files/chromedriver_win32_2.1.zip")
    }
    "FIREFOX" {
      $argument.Add("-browser `"browserName=firefox,maxInstances=1,platform=WINDOWS`"") > $null
    }
    default { exit 1 }
  }
}

# Uninstall service if installed
$service = Get-Service "$serviceName" -ErrorAction SilentlyContinue
if ($service)
{
  if ($service.status -ne "Stopped")
  {
    $service.stop()
    $service.WaitForStatus('Stopped', (New-Timespan -seconds 10))
  }
  & "$installPath\${serviceName}.exe" uninstall
  rm "$installPath" -recurse > $null
}

# Create install directory
mkdir "$installPath" > $null
mkdir "$installPath\log\" > $null

# Download files
$wc = New-Object System.Net.WebClient
foreach ($file in $($download.keys)) {
  try {
    $wc.DownloadFile($($download[$file]), "$installPath\$file")
  }
  catch [Net.WebException],[System.IO.IOException] {
    Write-Host "Failed to download file, exiting..." -ErrorAction stop 
  }
  if ($file.EndsWith('zip')) {
    $sh = New-Object -com shell.application
    $zip = $sh.namespace("$installPath\$file")
    $zip.items() | foreach {
      ($sh.namespace("$installPath")).Copyhere($_, 0x14)
      $fname = $_.name
      $file = $file -replace 'zip','exe'
      mv "$installPath\$fname" "$installPath\$file" -force
    }
  }
}

# Service config file
$xml = @"
<service>
  <id>selenium</id>
  <name>$serviceName</name>
  <description>Selenium Node Server</description>
  <executable>java</executable>
  <arguments>$($argument -join " ")</arguments>
  <onfailure action="restart" />
  <interactive />
  <logmode>rotate</logmode>
  <logpath>$installPath\log\</logpath>
</service>
"@
$xml | Out-File -force "${installPath}\${serviceName}.xml"

# Install service
& "$installPath\${serviceName}.exe" install

# Add firewall inbound rule
& netsh advfirewall firewall add rule name="$serviceName" dir=in action=allow protocol=TCP localport=5555 profile=any >null

# Start the service
$service = Get-Service "$serviceName" -ErrorAction SilentlyContinue
if ($service.status -eq "Stopped") {
  $service.start()
  try {
    $service.WaitForStatus('Running', (New-Timespan -seconds 10))
  } catch {
    Write-Host "Failed to start the service, exiting..." -ErrorAction stop 
  } finally {
    "Service started."
    "Available at: http://${hub}:4444/grid/console"
  }
}
