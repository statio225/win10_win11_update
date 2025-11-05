# ==========================
# Windows 10 -> 11 Upgrade Script (Remote Shell Safe)
# ==========================

# Variables
$isoUrl = "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64FRE_en-us.iso"
$destPath = "C:\Win11Upgrade"
$isoPath = "$destPath\Win11.iso"
$logPath = "$destPath\Logs"
$runTaskScript = "$destPath\RunUpgrade.ps1"

# Create folders
New-Item -ItemType Directory -Path $destPath,$logPath -Force | Out-Null

Write-Host "Downloading Windows 11 ISO..."

# Download ISO (BITS = resumable)
Start-BitsTransfer -Source $isoUrl -Destination $isoPath

Write-Host "ISO downloaded to $isoPath"

# Create upgrade runner script (runs after reboot if needed)
$scriptContent = @"
Start-Transcript -Path '$logPath\Upgrade-Transcript.txt' -Append

Write-Host "Mounting ISO..."
\$image = Mount-DiskImage -ImagePath "$isoPath" -PassThru
Start-Sleep -Seconds 5
\$drive = (Get-Volume -DiskImage \$image).DriveLetter + ":"

Write-Host "Starting setup from drive \$drive..."
Start-Process "\$drive\setup.exe" -ArgumentList "/auto upgrade /quiet /eula accept /dynamicupdate enable /copylogs $logPath" -Wait

Stop-Transcript
"@

Set-Content -Path $runTaskScript -Value $scriptContent -Force -Encoding UTF8

Write-Host "Creating scheduled task to run upgrade..."

# Create scheduled task (survives disconnect/restart)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$runTaskScript`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(30)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName "Win11RemoteUpgrade" -Action $action -Trigger $trigger -Principal $principal | Out-Null

Write-Host "Windows 11 upgrade task scheduled. It will run in 30 seconds."
Write-Host "Your session may disconnect when upgrade starts."
