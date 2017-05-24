Add-WindowsFeature NET-Framework-Core -Source C:\sources\sxs
$serviceName = 'selenium-hub'
$installPath = 'C:\Selenium'
$download = @{
  "selenium-server-standalone.jar" = "http://selenium-release.storage.googleapis.com/3.4/selenium-server-standalone-3.4.0.jar";
  "${serviceName}.exe" = "http://repo.jenkins-ci.org/releases/com/sun/winsw/winsw/1.13/winsw-1.13-bin.exe"
}
$argument = New-Object System.Collections.ArrayList
$argument.Add("-jar ${installPath}\selenium-server-standalone.jar") > $null
$argument.Add("-role hub") > $null


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
