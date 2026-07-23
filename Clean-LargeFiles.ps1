<#
.SYNOPSIS
    Recursively finds and deletes files larger than a specified size, outputting a list of deleted files.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TargetFolder,

    [Parameter(Mandatory=$false)]
    [long]$SizeThresholdMB = 100
)

# Verify the target directory exists before proceeding
if (-not (Test-Path -Path $TargetFolder -PathType Container)) {
    Write-Error "The directory '$TargetFolder' does not exist."
    exit
}

# Convert MB to Bytes for comparison
$ThresholdBytes = $SizeThresholdMB * 1MB
$DeletedFiles = @()

Write-Host "Scanning '$TargetFolder' and subfolders for files larger than $($SizeThresholdMB)MB..." -ForegroundColor Cyan

# Get all files recursively that exceed the size threshold
$LargeFiles = Get-ChildItem -Path $TargetFolder -File -Recurse -Force -ErrorAction SilentlyContinue | 
              Where-Object { $_.Length -gt $ThresholdBytes }

if ($LargeFiles.Count -eq 0) {
    Write-Host "No files larger than $($SizeThresholdMB)MB were found." -ForegroundColor Green
    exit
}

# Iterate through the identified files and delete them
foreach ($File in $LargeFiles) {
    try {
        # Attempt to delete the file
        Remove-Item -Path $File.FullName -Force -ErrorAction Stop
        
        # If successful, add to our list of deleted files
        $DeletedFiles += [PSCustomObject]@{
            FileName = $File.Name
            FilePath = $File.FullName
            SizeMB   = [math]::Round($File.Length / 1MB, 2)
        }
    }
    catch {
        Write-Warning "Failed to delete $($File.FullName). Reason: $($_.Exception.Message)"
    }
}

# Output the results
Write-Host "`nCleanup Complete!" -ForegroundColor Cyan
Write-Host "======================================"

if ($DeletedFiles.Count -gt 0) {
    Write-Host "The following $($DeletedFiles.Count) file(s) were successfully deleted:`n" -ForegroundColor Green
    
    # Format the output as a neat table
    $DeletedFiles | Format-Table -AutoSize
} else {
    Write-Host "No files were deleted (check warnings above for access/lock issues)." -ForegroundColor Yellow
}