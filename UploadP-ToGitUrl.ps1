<#
.SYNOPSIS
    Batches and uploads a large folder to a GitHub repository URL in chunks smaller than 2GB.
.DESCRIPTION
    1) Scans the source folder and calculates total data size.
    2) Segments the files into batches smaller than 1.9GB.
    3) Creates a temporary Git workspace, cloning the provided URL.
    4) Copies, stages, commits, and pushes each batch sequentially to the root of 'main'.
    5) Outputs success/failure messages for each batch.
    6) Cleans up the temporary Git workspace when finished.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$SourceFolder,       # Example: "E:\Reports"

    [Parameter(Mandatory=$true)]
    [string]$RepoUrl,            # Example: "https://github.com/Username/Repository.git"

    [double]$MaxBatchSizeGB = 1.9, # Slightly under 2GB to account for Git metadata
    [string]$BranchName = "protocols"
)

# -------------------------------------------------------------------------
# 1. Gather files and check sizes
# -------------------------------------------------------------------------
if (-not (Test-Path $SourceFolder)) {
    Write-Error "Source folder does not exist: $SourceFolder"
    exit
}

Write-Host "Scanning directory: $SourceFolder..." -ForegroundColor Cyan
$allFiles = Get-ChildItem -Path $SourceFolder -Recurse -File

# Calculate Total Size
$totalBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum
$totalGB = [math]::Round($totalBytes / 1GB, 3)

Write-Host "Total data stored in folder: $totalGB GB" -ForegroundColor Yellow

# GitHub strict limit warning
$largeFiles = $allFiles | Where-Object { $_.Length -gt 100MB }
if ($largeFiles.Count -gt 0) {
    Write-Warning "Found $($largeFiles.Count) file(s) larger than 100MB. Standard GitHub pushes will fail for these unless Git LFS is configured in your repo!"
}

if ($allFiles.Count -eq 0) {
    Write-Host "No files found in $SourceFolder. Exiting." -ForegroundColor Yellow
    exit
}

# -------------------------------------------------------------------------
# 2. Create File List Variables (Batches)
# -------------------------------------------------------------------------
$maxBytes = $MaxBatchSizeGB * 1GB
$batches = @()
$currentBatch = @()
$currentBatchBytes = 0

foreach ($file in $allFiles) {
    if (($currentBatchBytes + $file.Length) -gt $maxBytes -and $currentBatch.Count -gt 0) {
        $batches += ,$currentBatch
        $currentBatch = @()
        $currentBatchBytes = 0
    }
    $currentBatch += $file
    $currentBatchBytes += $file.Length
}

if ($currentBatch.Count -gt 0) {
    $batches += ,$currentBatch
}

$totalBatches = $batches.Count
Write-Host "Divided contents into $totalBatches batch(es) of < $MaxBatchSizeGB GB each." -ForegroundColor Cyan

# -------------------------------------------------------------------------
# 3. Setup Temporary Git Workspace (No Clone)
# -------------------------------------------------------------------------
# Create a unique temporary directory
$tempGuid = [guid]::NewGuid().ToString().Substring(0,8)
$tempRepoPath = Join-Path $env:TEMP "GitUpload_$tempGuid"

Write-Host "`nInitializing temporary workspace at: $tempRepoPath" -ForegroundColor DarkGray

# Create the folder and move into it
New-Item -ItemType Directory -Path $tempRepoPath -Force | Out-Null
Set-Location -Path $tempRepoPath

# Initialize a brand new local repository with the correct branch name
git init -b $BranchName -q

# Link the local repository to your target GitHub URL
git remote add origin $RepoUrl
Write-Host "Initialized fresh local repository and linked to remote." -ForegroundColor Cyan

# -------------------------------------------------------------------------
# 4 & 5. Stage, Commit, and Push Iteratively
# -------------------------------------------------------------------------
$batchNumber = 1
$hasError = $false

try {
    foreach ($batch in $batches) {
        Write-Host "`n--- Processing Batch $batchNumber of $totalBatches ---" -ForegroundColor Cyan
        
        $filesToStage = @()

        # Copy batch files to temp repo root directly
        foreach ($file in $batch) {
            # Get the path relative to the source folder (e.g. "subfolder\file.txt")
            $relativePath = $file.FullName.Substring($SourceFolder.Length).TrimStart('\')
            
            # Map that directly to the root of the temp repo
            $destPath = Join-Path $tempRepoPath $relativePath
            
            # Ensure any nested sub-folders exist in the destination before copying
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            
            # Convert Windows backslashes to Git forward slashes for staging
            $gitFilePath = $relativePath -replace '\\', '/'
            $filesToStage += $gitFilePath
        }

        # Stage specific files
        foreach ($gitFile in $filesToStage) {
            git add $gitFile
        }

        # Commit
        $commitMsg = "Automated upload: Batch $batchNumber of $totalBatches"
        git commit -m $commitMsg -q

        # Push
        Write-Host "Pushing Batch $batchNumber to GitHub..."
        $pushOutput = git push --force origin $BranchName 2>&1
        
        # Output success or error
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Batch $batchNumber uploaded successfully." -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Batch $batchNumber failed to upload." -ForegroundColor Red
            Write-Host "Git Output: $pushOutput" -ForegroundColor Red
            $hasError = $true
            break 
        }

        $batchNumber++
    }
}
finally {
    # -------------------------------------------------------------------------
    # 6. Cleanup Temporary Workspace
    # -------------------------------------------------------------------------
    Write-Host "`nCleaning up temporary workspace..." -ForegroundColor DarkGray
    # Move out of the directory so Windows doesn't lock it
    Set-Location $env:USERPROFILE
    
    # Git processes sometimes briefly lock files, short pause helps
    Start-Sleep -Seconds 2 
    
    try {
        Remove-Item -Path $tempRepoPath -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Could not fully remove temp folder: $tempRepoPath. You may need to delete it manually."
    }
    
    if (-not $hasError) {
        Write-Host "All operations completed successfully." -ForegroundColor Green
    } else {
        Write-Warning "Script stopped early due to an error."
    }
}