# Nightly Test App Orchestration 
# EchoPixel, Inc. - 2026 
# Save as C:\scripts\AppOrchestration.ps1

$LogFile = "E:\Reports\AppOrchestration.log"
$WebhookURL = "https://discord.com/api/webhooks/1495516844533223616/q15XnIARG6BrL2s-l-pBDaMKzYJKVW9RZ8YSGKzJeV6Z-nwC77K4x1F2OHmA84-rW4k7" 

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
Write-Log "=== Starting Daily Orchestration ==="

# === START | PREPARE DATA DCMTK / DATE  ===
Run-AppWithLogging -AppName "Update_DATE" -FilePath "C:\Program Files\dcmtk\bin\epxDatedData.bat" 

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | PREPARE DATA DCMTK / DATE ===

# === START | CLEANUP  ===
Run-AppWithLogging -AppName "CLEANUP" -FilePath "C:\Users\t3D\Desktop\code\cleanup.bat" 

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | CLEANUP ===

# === START | TPX - 0002 ===
Run-AppWithLogging -AppName "TPX-0002" -FilePath "E:\TPX\TPX-0002-HW_Reqs\TPX-0002-HW_Reqs\bin\Debug\TPX-0002-HW_Reqs.exe" -Arguments "rc:TRX_0002_RevA_HW_Reqs", "rl:Info", "/rf:E:\Reports\TPX-0002-HW_Reqs\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0002-HW_Reqs" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0002 ===

# === START | TPX - 0003 ===
Run-AppWithLogging -AppName "TPX-0003" -FilePath "E:\TPX\TPX-0003_zSpaceTracker\TPX-0003_zSpaceTracker\bin\Debug\TPX-0003_zSpaceTracker.exe" -Arguments "rc:TRX_0003_RevA_zSpaceTracker", "rl:Info", "/rf:E:\Reports\TPX-0003-zSpaceTracker\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0003-zSpaceTracker" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0003 ===

# === START | TPX - 0004 ===
Run-AppWithLogging -AppName "TPX-0004" -FilePath "E:\TPX\TPX-0004_TestData\TPX-0004_TestData\bin\Debug\TPX-0004_TestData.exe" -Arguments "rc:TRX_0004_RevA_TestData", "rl:Info", "/rf:E:\Reports\TPX-0004_TestData\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0004_TestData" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0004 ===

# === START | TPX - 0005 ===
Run-AppWithLogging -AppName "TPX-0005" -FilePath "E:\TPX\TPX-0005-SurfaceTestFiles\TPX-0005-SurfaceTestFiles\bin\Debug\TPX-0005-SurfaceTestFiles.exe" -Arguments "rc:TRX_0005_SurfaceFiles_RevA", "rl:Info", "/rf:E:\Reports\TPX-0005-SurfaceTestFiles\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0005-SurfaceTestFiles" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0005 ===

# === START | TPX - 0006 ===
Run-AppWithLogging -AppName "TPX-0006" -FilePath "E:\TPX\TPX-0006-XML_Test_Files\TPX-0006-XML_Test_Files\bin\Debug\TPX-0006-XML_Test_Files.exe" -Arguments "rc:TRX_0006_XMLTestData_RevA", "rl:Info", "/rf:E:\Reports\TPX-0006-XML_Test_Files\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0006-XML_Test_Files" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0006 ===

# === START | TPX - 0007 ===
Run-AppWithLogging -AppName "TPX-0007" -FilePath "E:\TPX\TPX-0007-LocalClientPACSData\TPX-0007-LocalClientPACSData\bin\Debug\TPX-0007-LocalClientPACSData.exe" -Arguments "rc:TRX_0007_LocalClientPACSData_RevA", "rl:Info", "/rf:E:\Reports\TPX-0007-LocalClientPACSData\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0007-LocalClientPACSData" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0007 ===

# === START | TPX - 0008 ===
Run-AppWithLogging -AppName "TPX-0008" -FilePath "E:\TPX\TPX-0008-LocalPatientBrowserData\TPX-0008-LocalPatientBrowserData\bin\Debug\TPX-0008-LocalPatientBrowserData.exe" -Arguments "rc:TRX_0008_LocalPatientBrowserData_RevA", "rl:Info", "/rf:E:\Reports\TPX-0008-LocalPatienBrowserData\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0008-LocalPatienBrowserData" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0008 ===

# === START | TPX - 0009 ===
Run-AppWithLogging -AppName "TPX-0009" -FilePath "E:\TPX\TPX-0009-RemotePACS_Orthanc\TPX-0009-RemotePACS_Orthanc\bin\Debug\TPX-0009-RemotePACS_Orthanc.exe" -Arguments "rc:TRX_0009_RemotePACS_Orthanc_RevA", "rl:Info", "/rf:E:\Reports\TPX-0009-RemotePACS_Orthanc\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0009-RemotePACS_Orthanc" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0009 ===

# === START | TPX - 0010 ===
Run-AppWithLogging -AppName "TPX-0010" -FilePath "E:\TPX\TPX-0010_RemotePACS_DVTK\TPX-0010_RemotePACS_DVTK\bin\Debug\TPX-0010_RemotePACS_DVTK.exe" -Arguments "rc:TRX_0010_RemotePACS_DVTK_RevA", "rl:Info", "/rf:E:\Reports\TPX-0010-RemotePACS_DVTK\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0010-RemotePACS_DVTK" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0010 ===

# === START | TPX - 0015 ===
Run-AppWithLogging -AppName "TPX-0015" -FilePath "E:\TPX\TPX-0015-BackgroundServices\TPX-0015-BackgroundServices\bin\Debug\TPX-0015-BackgroundServices.exe" -Arguments "rc:TRX_0015_BackgroundServices_RevA", "rl:Info", "/rf:E:\Reports\TPX-0015-BackgroundServices\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0015-BackgroundServices" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0015 ===

# === START | TPX - 0016 ===
Run-AppWithLogging -AppName "TPX-0016" -FilePath "E:\TPX\TPX-0016_DICOM-Config\TPX-0016_DICOM-Config\bin\Debug\TPX-0016_DICOM-Config.exe" -Arguments "rc:TRX_0016_DICOM_Config_RevA", "rl:Info", "/rf:E:\Reports\TPX-0016_DICOM-Config\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0016_DICOM-Config" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0016 ===

# === START | ORTHANC PREP ===
Run-AppWithLogging -AppName "epxSCH-001_DICOM_PUSH" -FilePath "E:\TPX\epxSCH-001_DICOM_PUSH\epxSCH-001_DICOM_PUSH\bin\Debug\epxSCH-001_DICOM_PUSH.exe" -Arguments "rc:TestRun", "rl:Info", "/rf:E:\Reports\epxSCH-001_DICOM_PUSH\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | ORTHANC PREP ===

# === START | TPX - 0017 ===
Run-AppWithLogging -AppName "TPX-0017" -FilePath "E:\TPX\TPX-0017_DICOM_Accept_Write\TPX-0017_DICOM_Accept_Write\bin\Debug\TPX-0017_DICOM_Accept_Write.exe" -Arguments "rc:TRX_0017_DICOM_Accept_Write_RevA", "rl:Info", "/rf:E:\Reports\TPX-0017_DICOM_Accept_Write\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0017_DICOM_Accept_Write" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0017 ===

# === START | TPX - 0018 ===
Run-AppWithLogging -AppName "TPX-0018" -FilePath "E:\TPX\TPX-0018_DICOM-STORE_RECEIVE\TPX-0018_DICOM-STORE_RECEIVE\bin\Debug\TPX-0018_DICOM-STORE_RECEIVE.exe" -Arguments "rc:TRX_0018_DICOM_STORE_RECEIVE_RevA", "rl:Info", "/rf:E:\Reports\TPX-0018_DICOM-STORE_RECEIVE\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0018_DICOM-STORE_RECEIVE" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0018 ===

# === START | TPX - 0019 ===
Run-AppWithLogging -AppName "TPX-0019" -FilePath "E:\TPX\TPX-0019_DCM_QR\TPX-0019_DCM_QR\bin\Debug\TPX-0019_DCM_QR.exe" -Arguments "rc:TRX_0019_DICOM_QR_RevA", "rl:Info", "/rf:E:\Reports\TPX-0019_DCM_QR\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0019_DCM_QR" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0019 ===

# === START | TPX - 0020 ===
Run-AppWithLogging -AppName "TPX-0020" -FilePath "E:\TPX\TPX-0020_Import-Export\TPX-0020_Import-Export\bin\Debug\TPX-0020_Import-Export.exe" -Arguments "rc:TRX_0020_Import_Export_RevA", "rl:Info", "/rf:E:\Reports\TPX-0020_Import-Export\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0020_Import-Export" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0020 ===

# === START | TPX - 0021 ===
Run-AppWithLogging -AppName "TPX-0021" -FilePath "E:\TPX\TPX-0021_DICOM_AuditLog\TPX-0021_DICOM_AuditLog\bin\Debug\TPX-0021_DICOM_AuditLog.exe" -Arguments "rc:TRX_0021_DICOM_AuditLog_RevA", "rl:Info", "/rf:E:\Reports\TPX-0021_DICOM_AuditLog\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0021_DICOM_AuditLog" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0021 ===

# === START | TPX - 0026 ===
Run-AppWithLogging -AppName "TPX-0026" -FilePath "E:\TPX\TPX-0026_System\TPX-0026_System\bin\Debug\TPX-0026_System.exe" -Arguments "rc:TRX_0026_SYSTEM_RevA", "rl:Info", "/rf:E:\Reports\TPX-0026_System\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0026_System" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0026 ===

# === START | TPX - 0022 ===
Run-AppWithLogging -AppName "TPX-0022" -FilePath "E:\TPX\TPX-0022_HD_MONITOR\TPX-0022_HD_MONITOR\bin\Debug\TPX-0022_HD_MONITOR.exe" -Arguments "rc:TRX_0022_HD_MONITOR_RevA", "rl:Info", "/rf:E:\Reports\TPX-0022_HD_MONITOR\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0022_HD_MONITOR" -SizeThresholdMB 100

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10
# === END | TPX - 0022 ===

# === START | TPX - 0023 ===
# --- EJECT F:\ ---
Write-Log "Eject F... $AppName"
& "E:\Reports\Eject-UsbDrive.ps1" -DriveLetter "F:"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

Run-AppWithLogging -AppName "TPX-0023" -FilePath "E:\TPX\TPX-0023_HD_MONITOR_MISSING\TPX-0023_HD_MONITOR_MISSING\bin\Debug\TPX-0023_HD_MONITOR_MISSING.exe" -Arguments "rc:TRX_0023_HD_MONITOR_MISSING_RevA", "rl:Info", "/rf:E:\Reports\TPX-0023_HD_MONITOR_MISSING\%R_%Y%M%D.html", "vr:KeepAllTests"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# --- Call the cleanup script ---
Write-Log "Initiating Clean-LargeFiles.ps1... $AppName"
& "E:\Reports\Clean-LargeFiles.ps1" -TargetFolder "E:\Reports\TPX-0023_HD_MONITOR_MISSING" -SizeThresholdMB 100

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
Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

Write-Log "Initiating Upload-ToGitUrl.ps1... $AppName"
& "E:\Reports\Upload-ToGitUrl.ps1" -SourceFolder "E:\Reports" -RepoUrl "https://github.com/EchoPixel-Inc/Nightly_Testing"

Write-Log "Waiting 10 seconds..."
Start-Sleep -Seconds 10

# FINALIZE
Write-Log "=== Daily Orchestration Complete ==="

   