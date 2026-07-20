# Cribl CPU Monitor

A PowerShell script that monitors Cribl process CPU utilization and sends email alerts when usage exceeds a configured threshold. The script also automatically collects diagnostic files and CPU profiles when high CPU is detected.

## Features

- **CPU Monitoring**: Continuously monitors Cribl process CPU usage at configurable intervals
- **Email Alerts**: Sends HTML email notifications when CPU usage exceeds threshold
- **Automatic Diagnostics Collection**: Collects Cribl diagnostic files and CPU profiles on high CPU detection
- **File Stability Check**: Ensures all diagnostic files are fully written before copying
- **Central Share Copy**: Copies diagnostic files to a central network share for analysis
- **Cooldown Period**: Configurable cooldown between alerts to prevent spam
- **Console Logging**: Real-time console output with timestamps and color coding

## Prerequisites

- Windows PowerShell 5.1 or later
- Cribl installed at `C:\Program Files\Cribl\`
- Access to SMTP server for email alerts
- Access to central network share for diagnostic file storage
- `C:\Logs` directory (default on most servers)

## Configuration

### SMTP Configuration
```powershell
$smtpServer = "smtp.contoso.com"           # Your SMTP server
$smtpPort = 587                             # SMTP port
$serviceAccount = "svc_email@contoso.com"   # Service account for sending emails
$serviceAccountPwd = "your_password"        # Password or use encrypted file
$encryptedPasswordFile = "C:\Scripts\encrypted_password.txt"  # Encrypted password file
$sender = "noreply@contoso.com"             # Sender email address
$recipient = "user1@contoso.com"            # Recipient email address
```

### Monitoring Configuration
```powershell
$cpuThreshold = 15          # CPU threshold in percentage
$checkInterval = 30         # Check interval in seconds
$processName = "cribl"      # Process name to monitor
```

### Cribl Configuration
```powershell
$criblPath = "C:\Program Files\Cribl\bin\cribl.exe"
$criblVolumeDir = "C:\ProgramData\Cribl"
$diagOutputDir = "C:\ProgramData\Cribl\diag"
$centralShare = "\\fileshare.contoso.com\Cribl_diag"
```

## Usage

1. **Configure the script**: Edit the configuration section at the top of the script with your SMTP, monitoring, and Cribl settings

2. **Encrypt password (optional)**: For better security, encrypt your SMTP password:
   ```powershell
   Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Scripts\encrypted_password.txt"
   ```

3. **Run the script**:
   ```powershell
   .\CriblCpuMonitor.ps1
   ```

4. **Stop the script**: Press `Ctrl+C` to stop monitoring

## How It Works

1. The script runs in a continuous monitoring loop
2. Every 30 seconds (configurable), it checks the Cribl process CPU usage
3. If CPU usage exceeds the threshold (default 15%):
   - Collects Cribl diagnostic files using `cribl diag create -g -d`
   - Collects CPU profiles for all Cribl processes using `cribl diag cpuprofile`
   - Waits 90 seconds to ensure all files are fully written
   - Performs file stability check to confirm no new files are being written
   - Copies only newly created files (files created after collection started) to central share
   - Sends email alert with collection status
4. Respects a 5-minute cooldown period between alerts to prevent spam

## Diagnostic Files

The script collects the following diagnostic files:
- **Cribl Diagnostics**: Complete diagnostic package in tar.gz format
- **CPU Profiles**: CPU profiling data for each Cribl process

Files are copied to the central share in a server-specific folder:
```
\\fileshare.contoso.com\Cribl_diag\SERVERNAME\
```

## Email Alert Format

The email alert includes:
- Server name
- Process name
- CPU usage percentage
- Threshold value
- Timestamp
- Diagnostic collection status (diagnostics, CPU profile, copy to share)
- Local and central share locations

## Troubleshooting

### Script not sending emails
- Verify SMTP server settings are correct
- Check if the service account has permission to send emails
- Ensure network connectivity to SMTP server
- Verify recipient email address is correct

### Diagnostic files not copying
- Check if the central share is accessible
- Verify network connectivity to the file share
- Ensure the service account has write permissions on the share
- Check if `C:\ProgramData\Cribl\diag` directory exists

### CPU profile collection failing
- Ensure Cribl is running
- Verify Cribl path is correct
- Check if the Cribl service has sufficient permissions

## Security Considerations

- Store the script in a secure location with appropriate permissions
- Use encrypted password file instead of plain text password
- Limit access to the central share to authorized personnel
- Review and rotate SMTP credentials regularly
- Consider running the script with a service account with minimal required permissions

## License

This script is provided as-is for monitoring Cribl processes. Modify as needed for your environment.

## Support

For issues or questions, please contact your system administrator or Cribl support team.
