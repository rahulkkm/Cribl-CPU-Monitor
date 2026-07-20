<#
.DESCRIPTION
Monitors Cribl process CPU utilization and sends email alert when usage exceeds 15%
.OUTPUTS
No outputs expected if successful
#>

# SMTP Configuration
$smtpServer = "smtp.dell.com"
$smtpPort = 587
$serviceAccount = "svc_prdmecmemailacct@amer.dell.com"
$serviceAccountPwd = "your_password"  # Replace with valid password OR use encrypted file below
$encryptedPasswordFile = "C:\Scripts\encrypted_password.txt"

# Try to read encrypted password from file if it exists
if (Test-Path $encryptedPasswordFile) {
    try {
        $securePwd = Get-Content $encryptedPasswordFile | ConvertTo-SecureString
        $serviceAccountPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePwd))
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Using encrypted password from file" -ForegroundColor Cyan
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Failed to read encrypted password, using plain text" -ForegroundColor Yellow
    }
}
$sender = "noreply@dell.com"
$recipient = "rahul.sreedharan@dell.com"  # Replace with valid recipient

# Monitoring Configuration
$cpuThreshold = 15  # CPU threshold in percentage
$checkInterval = 30  # Check interval in seconds
$processName = "cribl"  # Process name to monitor

# Cribl Configuration
$criblPath = "C:\Program Files\Cribl\bin\cribl.exe"
$criblVolumeDir = "C:\ProgramData\Cribl"
$diagOutputDir = "C:\ProgramData\Cribl\diag"
$centralShare = "\\typhoon.us.dell.com\load\Cribl_diag"

# Function to send email alert
function Send-EmailAlert {
    param(
        [string]$Subject,
        [string]$Body
    )
    
    try {
        $msg = New-Object Net.Mail.MailMessage
        $smtp = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $msg.From = New-Object System.Net.Mail.MailAddress($sender)
        $msg.To.Add($recipient)
        $msg.Subject = $subject
        $msg.Body = $body
        $msg.IsBodyHTML = $true
        $smtp.EnableSSL = $true
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $smtp.Credentials = New-Object System.Net.NetworkCredential($serviceAccount, $serviceAccountPwd)
        $smtp.Send($msg)
        $smtp.Dispose()
        
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Email alert sent successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Failed to send email: $_" -ForegroundColor Red
    }
}

# Function to get process CPU utilization
function Get-ProcessCpuUsage {
    param(
        [string]$ProcessName
    )
    
    try {
        $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $process) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Process '$processName' not found" -ForegroundColor Yellow
            return $null
        }
        
        # Get CPU counter for the process
        $counterPath = "\Process($processName)\% Processor Time"
        $cpuCounter = Get-Counter -Counter $counterPath -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
        
        if ($cpuCounter) {
            $cpuUsage = [math]::Round($cpuCounter.CounterSamples.CookedValue, 2)
            return $cpuUsage
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Unable to get CPU counter for process '$processName'" -ForegroundColor Yellow
            return $null
        }
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Error getting process CPU usage: $_" -ForegroundColor Red
        return $null
    }
}

# Function to collect Cribl diagnostic files
function Collect-CriblDiagnostics {
    param(
        [string]$CriblPath,
        [string]$OutputDir
    )
    
    try {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Collecting Cribl diagnostic files..." -ForegroundColor Cyan
        
        # Set environment variable
        $env:CRIBL_VOLUME_DIR = $criblVolumeDir
        
        # Run diagnostic collection
        $diagResult = & $CriblPath diag create -g -d 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Diagnostic files collected successfully to $OutputDir" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Failed to collect diagnostic files: $diagResult" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Error collecting diagnostics: $_" -ForegroundColor Red
        return $false
    }
}

# Function to collect CPU profile for Cribl processes
function Collect-CriblCpuProfile {
    param(
        [string]$CriblPath,
        [string]$VolumeDir
    )
    
    try {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Collecting CPU profile for Cribl processes..." -ForegroundColor Cyan
        
        # Set environment variable
        $env:CRIBL_VOLUME_DIR = $VolumeDir
        
        # Get all Cribl processes
        $criblProcesses = Get-Process -Name "cribl" -ErrorAction SilentlyContinue
        
        if (-not $criblProcesses) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] No Cribl processes found for CPU profiling" -ForegroundColor Yellow
            return $false
        }
        
        $profileCollected = $false
        
        foreach ($process in $criblProcesses) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Processing CPU profile for PID: $($process.Id)" -ForegroundColor Cyan
            
            $profileResult = & $CriblPath diag cpuprofile -p $process.Id 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] CPU profile collected for PID: $($process.Id)" -ForegroundColor Green
                $profileCollected = $true
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Failed to collect CPU profile for PID $($process.Id): $profileResult" -ForegroundColor Red
            }
        }
        
        return $profileCollected
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Error collecting CPU profile: $_" -ForegroundColor Red
        return $false
    }
}

# Function to copy diagnostic files to central share
function Copy-DiagnosticsToShare {
    param(
        [string]$SourceDir,
        [string]$DestinationShare,
        [DateTime]$CollectionStartTime
    )
    
    try {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Copying diagnostic files to central share..." -ForegroundColor Cyan
        
        # Check if source directory exists
        if (-not (Test-Path $SourceDir)) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Source directory not found: $SourceDir" -ForegroundColor Yellow
            return $false
        }
        
        # Wait for file stability - ensure no files are being written
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Waiting for file stability check..." -ForegroundColor Cyan
        $stableCount = 0
        $previousFileCount = 0
        while ($stableCount -lt 2) {
            $currentFiles = Get-ChildItem -Path $SourceDir -File
            $currentFileCount = $currentFiles.Count
            
            if ($currentFileCount -eq $previousFileCount) {
                $stableCount++
            }
            else {
                $stableCount = 0
                $previousFileCount = $currentFileCount
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] File count changed to $currentFileCount, resetting stability check" -ForegroundColor Yellow
            }
            
            if ($stableCount -lt 2) {
                Start-Sleep -Seconds 5
            }
        }
        
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] File stability confirmed. Proceeding with copy..." -ForegroundColor Cyan
        
        # Create server-specific subdirectory with hostname only (no timestamp)
        $serverName = $env:COMPUTERNAME
        $destSubDir = Join-Path $DestinationShare $serverName
        
        # Create destination subdirectory
        New-Item -ItemType Directory -Path $destSubDir -Force | Out-Null
        
        # Copy only files created after collection started
        $totalFiles = 0
        $filesCopied = 0
        $filesFailed = 0
        $copiedFilesList = @()  # Track successfully copied files
        Get-ChildItem -Path $SourceDir -File | Where-Object { $_.CreationTime -gt $CollectionStartTime } | ForEach-Object {
            $totalFiles++
            try {
                $destPath = Join-Path $destSubDir $_.Name
                Copy-Item -Path $_.FullName -Destination $destPath -Force -ErrorAction Stop
                
                # Verify the file was actually copied
                if (Test-Path $destPath) {
                    $filesCopied++
                    $copiedFilesList += $_.FullName  # Add to list of successfully copied files
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Copied: $($_.Name)" -ForegroundColor Gray
                }
                else {
                    $filesFailed++
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Failed to copy (verification failed): $($_.Name)" -ForegroundColor Red
                }
            }
            catch {
                $filesFailed++
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Failed to copy file: $($_.Name) - $_" -ForegroundColor Red
            }
        }
        
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Copy summary: $filesCopied/$totalFiles files copied successfully, $filesFailed failed" -ForegroundColor Cyan
        
        if ($filesCopied -gt 0) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Successfully copied $filesCopied files to $destSubDir" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] No files were copied to central share" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Error copying diagnostics to share: $_" -ForegroundColor Red
        return $false
    }
}

# Main monitoring loop
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting Cribl CPU monitor..." -ForegroundColor Cyan
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] CPU Threshold: $cpuThreshold%" -ForegroundColor Cyan
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Check Interval: $checkInterval seconds" -ForegroundColor Cyan
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Diagnostic Output: $diagOutputDir" -ForegroundColor Cyan
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Central Share: $centralShare" -ForegroundColor Cyan
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Press Ctrl+C to stop monitoring" -ForegroundColor Cyan

$lastAlertTime = $null
$alertCooldown = 300  # 5 minutes cooldown between alerts to avoid spam

while ($true) {
    $cpuUsage = Get-ProcessCpuUsage -ProcessName $processName
    
    if ($cpuUsage -ne $null) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Cribl CPU Usage: $cpuUsage%" -ForegroundColor White
        
        if ($cpuUsage -gt $cpuThreshold) {
            $currentTime = Get-Date
            
            # Check if we should send an alert (respect cooldown period)
            if ($null -eq $lastAlertTime -or ($currentTime - $lastAlertTime).TotalSeconds -gt $alertCooldown) {
                # Collect diagnostics before sending alert
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] High CPU detected. Collecting diagnostics..." -ForegroundColor Cyan
                
                $collectionStartTime = Get-Date
                $diagSuccess = Collect-CriblDiagnostics -CriblPath $criblPath -OutputDir $diagOutputDir
                $cpuProfileSuccess = Collect-CriblCpuProfile -CriblPath $criblPath -VolumeDir $criblVolumeDir
                
                # Wait 90 seconds after collection to ensure all files are fully written
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Waiting 90 seconds after collection to ensure all files are fully written..." -ForegroundColor Cyan
                Start-Sleep -Seconds 90
                
                $copySuccess = Copy-DiagnosticsToShare -SourceDir $diagOutputDir -DestinationShare $centralShare -CollectionStartTime $collectionStartTime
                
                $diagStatus = if ($diagSuccess) { "SUCCESS" } else { "FAILED" }
                $cpuProfileStatus = if ($cpuProfileSuccess) { "SUCCESS" } else { "FAILED" }
                $copyStatus = if ($copySuccess) { "SUCCESS" } else { "FAILED" }
                
                $subject = "ALERT: Cribl Process High CPU Usage - $cpuUsage%"
                $body = @"
                    <html>
                    <body>
                        <h2>Cribl Process High CPU Usage Alert</h2>
                        <p><strong>Server:</strong> $env:COMPUTERNAME</p>
                        <p><strong>Process:</strong> $processName</p>
                        <p><strong>CPU Usage:</strong> $cpuUsage%</p>
                        <p><strong>Threshold:</strong> $cpuThreshold%</p>
                        <p><strong>Timestamp:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
                        <hr>
                        <h3>Diagnostic Collection Status:</h3>
                        <p><strong>General Diagnostics:</strong> $diagStatus</p>
                        <p><strong>CPU Profile:</strong> $cpuProfileStatus</p>
                        <p><strong>Copy to Central Share:</strong> $copyStatus</p>
                        <p><strong>Local Diagnostic Location:</strong> $diagOutputDir</p>
                        <p><strong>Central Share Location:</strong> $centralShare\$env:COMPUTERNAME</p>
                        <hr>
                        <p><em>This is an automated alert from the Cribl CPU Monitor script - Gcore Engineering.</em></p>
                    </body>
                    </html>
"@
                
                Send-EmailAlert -Subject $subject -Body $body
                $lastAlertTime = $currentTime
            }
            else {
                $timeUntilNextAlert = [math]::Round(($alertCooldown - ($currentTime - $lastAlertTime).TotalSeconds) / 60, 1)
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Alert cooldown active. Next alert possible in $timeUntilNextAlert minutes" -ForegroundColor Yellow
            }
        }
    }
    
    Start-Sleep -Seconds $checkInterval
}