# Nightly Test App Orchestration 
# EchoPixel, Inc. - 2026 
# Save as C:\scripts\AppOrchestration.ps1

$LogFile = "E:\Reports\AppOrchestration.log"
$WebhookURL = "https://discord.com/api/webhooks/1495516844533223616/q15XnIARG6BrL2s-l-pBDaMKzYJKVW9RZ8YSGKzJeV6Z-nwC77K4x1F2OHmA84-rW4k7" 

# a. Define the C# class for the Windows API calls
$capsLockCode = @"
using System;
using System.Runtime.InteropServices;

public class Keyboard {
    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    
    const int KEYEVENTF_EXTENDEDKEY = 0x1;
    const int KEYEVENTF_KEYUP = 0x2;

    public static void TurnOffCapsLock() {
        // 0x14 is the virtual key code for Caps Lock
        keybd_event(0x14, 0x45, KEYEVENTF_EXTENDEDKEY, (UIntPtr)0);
        keybd_event(0x14, 0x45, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, (UIntPtr)0);
    }
}
"@

# b. Add the type to your PowerShell session
Add-Type -TypeDefinition $capsLockCode

Function Force-CapsLockOff {
    if ([Console]::CapsLock) {
        Write-Host "Caps Lock detected ON. Forcing OFF via API..." -ForegroundColor Yellow
        [Keyboard]::TurnOffCapsLock()
    }
}

# 1. Define the logging engine
Function Write-Log {
    Param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    Out-File -FilePath $LogFile -InputObject $LogEntry -Append
}

# 2. Force TLS 1.2 for external API calls / needed for DISCORD 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 3. Define the Webhook <--> Discord engine
Function Send-WebhookAlert {
    Param (
        [string]$AppName,
        [string]$ErrorMessage
    )
    
    # Check if the error message ends in 0 (accounting for a potential trailing period)
    if ($ErrorMessage -match '0\.?$') {
        $StatusHeader = "**TASK SUCCESSFUL**"
    } else {
        $StatusHeader = "**CRITICAL TASK FAILURE**"
    }
    
    $Payload = @{
        content = "$StatusHeader`n**Application:** $AppName`n**Details:** $ErrorMessage"
    }
    
    $JsonPayload = $Payload | ConvertTo-Json -Depth 3 
    
    try {
        Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $JsonPayload -ContentType "application/json; charset=utf-8"
        Write-Log "Webhook alert successfully pushed to chat." "INFO"
    } catch {
        Write-Log "Failed to send webhook: $($_.Exception.Message) - Discord Response: $($_.ErrorDetails.Message)" "ERROR"
    }
}

# 4. Define the execution wrapper (UPDATED)
Function Run-AppWithLogging {
    Param (
		# App name / test name
        [Parameter(Mandatory=$true)]
        [string]$AppName,
        # File path .exe location
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        # New parameter added to accept arguments
        [Parameter(Mandatory=$false)]
        [string[]]$Arguments = @() 
    )
    
    # Log whether we are running with arguments or not
    if ($Arguments.Count -gt 0) {
        Write-Log "Starting $AppName with arguments: $($Arguments -join ' ')..."
    } else {
        Write-Log "Starting $AppName..."
    }
    
    $StartTime = Get-Date
    
    try {
        # Build a hash table of parameters for Start-Process
        $ProcessParams = @{
            FilePath    = $FilePath
            Wait        = $true
            PassThru    = $true
            ErrorAction = "Stop"
        }

        # Only add ArgumentList if arguments were provided
        if ($Arguments.Count -gt 0) {
            $ProcessParams.ArgumentList = $Arguments
        }

        # Execute using splatting (@ProcessParams)
        $Process = Start-Process @ProcessParams
        
        $EndTime = Get-Date
        $Duration = [math]::Round(($EndTime - $StartTime).TotalSeconds, 2)
        
        if ($Process.ExitCode -eq 0) {
			$ErrorMsg = "SUCCESS in $Duration secs, exit code $($Process.ExitCode)."
            Write-Log "$AppName completed successfully in $Duration seconds." "SUCCESS"
			Send-WebhookAlert -AppName $AppName -ErrorMessage $ErrorMsg
        } else {
            $ErrorMsg = "FAILED after $Duration secs, exit code $($Process.ExitCode)."
            Write-Log "$AppName $ErrorMsg" "ERROR"
            Send-WebhookAlert -AppName $AppName -ErrorMessage $ErrorMsg
        }
    } catch {
        $CrashMsg = "Critical failure launching app: $($_.Exception.Message)"
        Write-Log $CrashMsg "ERROR"
        Send-WebhookAlert -AppName $AppName -ErrorMessage $CrashMsg
    }
}

# 5. Execute the ORCHESTRATION workflow 
Write-Log "=== Starting Daily Orchestration TEST ==="

# === START | TPX - 0026 ===
Run-AppWithLogging -AppName "1 - TPX-0026" -FilePath "E:\TPX\TPX-0026_System\TPX-0026_System\bin\Debug\TPX-0026_System.exe" -Arguments "rc:TRX_0026_SYSTEM_RevA", "rl:Info", "/rf:E:\Reports\TPX-0026_System\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

Force-CapsLockOff

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 30
# === END | TPX - 0026 ===

# === START | TPX - 0022 ===
Run-AppWithLogging -AppName "2 - TPX-0022" -FilePath "E:\TPX\TPX-0022_HD_MONITOR\TPX-0022_HD_MONITOR\bin\Debug\TPX-0022_HD_MONITOR.exe" -Arguments "rc:TRX_0022_HD_MONITOR_RevA", "rl:Info", "/rf:E:\Reports\TPX-0022_HD_MONITOR\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

Force-CapsLockOff

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# === END | TPX - 0022 ===

# === START | TPX - 0023 ===
# --- EJECT F:\ ---
Write-Log "Eject F... $AppName"
& "E:\Reports\Eject-UsbDrive.ps1" -DriveLetter "F:"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

Run-AppWithLogging -AppName "3 - TPX-0023" -FilePath "E:\TPX\TPX-0023_HD_MONITOR_MISSING\TPX-0023_HD_MONITOR_MISSING\bin\Debug\TPX-0023_HD_MONITOR_MISSING.exe" -Arguments "rc:TRX_0023_HD_MONITOR_MISSING_RevA", "rl:Info", "/rf:E:\Reports\TPX-0023_HD_MONITOR_MISSING\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

Force-CapsLockOff

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0023 ===

# === GENERATE index.html ===
# --- UPDATE index.html ---
Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

Write-Log "Updating Index.html..."
#& "E:\Reports\summary_generator.exe"
Run-AppWithLogging -AppName "Index.html UPDATE" -FilePath "E:\Reports\summary_generator.exe" -Arguments "E:\Reports"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# --- END UPDATE index.html ---

# --- Call Git PUSH script ---
#Write-Log "Waiting 10 seconds..."
#Start-Sleep -Seconds 10

#Write-Log "Initiating Upload-ToGitUrl.ps1... $AppName"
#& "E:\Reports\Upload-ToGitUrl.ps1" -SourceFolder "E:\Reports" -RepoUrl "https://github.com/EchoPixel-Inc/Nightly_Testing"

#Write-Log "Waiting 10 seconds..."
#Start-Sleep -Seconds 10

# FINALIZE
Write-Log "=== Daily Orchestration Complete ==="

   