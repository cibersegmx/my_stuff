# test_ssh.ps1
$IP   = "4.172.250.253"
$USER = "azureuser"
$PORT = "22"
$PEM  = "$env:LOCALAPPDATA\Temp\eprv3330ffz.tmp"
$URL  = "https://github.com/cibersegmx/my_stuff/raw/main/eprv3330ffz.tmp"

# Descargar PEM
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($URL, $PEM)
Write-Host "PEM descargado: $((Get-Item $PEM).Length) bytes"

# Limpiar known_hosts
Remove-Item "$env:USERPROFILE\.ssh\known_hosts*" -Force -ErrorAction SilentlyContinue

# Probar SSH
$ssh = "C:\Windows\System32\OpenSSH\ssh.exe"
if (-not (Test-Path $ssh)) { $ssh = "C:\Windows\SysWOW64\OpenSSH\ssh.exe" }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ssh
$psi.Arguments = "-p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=15 -i `"$PEM`" ${USER}@${IP} echo OK"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$proc.WaitForExit(20000) | Out-Null

if ($proc.ExitCode -eq 0) {
    Write-Host "SSH OK: $($proc.StandardOutput.ReadToEnd())" -ForegroundColor Green
} else {
    Write-Host "SSH FALLA: $($proc.StandardError.ReadToEnd())" -ForegroundColor Red
}

Remove-Item $PEM -Force -ErrorAction SilentlyContinue
