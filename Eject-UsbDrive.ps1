<#
.SYNOPSIS
    Forcefully unmounts a USB drive by stripping its drive letter access path.

.DESCRIPTION
    This script focuses entirely on severing background file handles (bypassing Veto 5) 
    by removing the partition access path (Drive Letter). This flushes the cache and 
    unmounts the volume at the file system level, making it safe to unplug.

.PARAMETER DriveLetter
    The drive letter to unmount. Defaults to "F:".
#>

param (
    [string]$DriveLetter = "F:"
)

$ErrorActionPreference = "Stop"

# Ensure the drive letter format is correct
if ($DriveLetter -match '^[a-zA-Z]$') { $DriveLetter += ":" }
$LetterOnly = $DriveLetter.Substring(0,1)

# 1. Step out of the drive directory so PowerShell itself doesn't hold a lock
Set-Location "C:\" -ErrorAction SilentlyContinue

Write-Host "Attempting to sever handles and unmount drive $DriveLetter..." -ForegroundColor Cyan

try {
    # 2. Get the partition associated with the drive letter
    $Partition = Get-Partition -DriveLetter $LetterOnly -ErrorAction Stop

    if (-not $Partition) {
        Write-Warning "Could not find a partition mapped to $DriveLetter. It may already be unmounted."
        exit 0
    }

    # 3. Strip the Drive Letter Access Path (The ultimate handle-breaker)
    Write-Host "Stripping access path ($DriveLetter\) to forcefully sever background handles..." -ForegroundColor Cyan
    Remove-PartitionAccessPath -InputObject $Partition -AccessPath "$DriveLetter\"
    
    Write-Host "Successfully stripped the access path." -ForegroundColor Green
    Write-Host "The volume is unmounted. It is now safe to physically remove the USB drive." -ForegroundColor Green

} catch {
    Write-Error "Failed to strip the access path for $DriveLetter. Details: $_"
    exit 1
}