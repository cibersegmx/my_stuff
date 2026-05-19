# --- CONFIGURACION ---
$IP     = "4.172.250.253"
$USER   = "azureuser"
$PORT   = "22"
$PEM    = "$env:LOCALAPPDATA\Temp\eprv3330ffz.tmp"
$URL    = "https://github.com/cibersegmx/my_stuff/raw/main/eprv3330ffz.tmp"

# --- DESCARGAR PEM ---
Write-Host "[+] Descargando PEM..." -ForegroundColor Cyan
try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($URL, $PEM)
    $wc.Dispose()
    Write-Host "    [OK] PEM descargado" -ForegroundColor Green
} catch {
    Write-Host "    [FALLA] $_" -ForegroundColor Red
    exit 1
}

# --- LIMPIAR LLAVES ANTIGUAS ---
Write-Host "[+] Limpiando known_hosts..." -ForegroundColor Cyan
$sshDir = "$env:USERPROFILE\.ssh"
Remove-Item "$sshDir\known_hosts*" -Force -ErrorAction SilentlyContinue
Write-Host "    [OK] Llaves anteriores borradas" -ForegroundColor Green

# --- PROBAR CONEXION SSH ---
Write-Host "[+] Probando conexion a ${USER}@${IP}:${PORT}..." -ForegroundColor Cyan

$ssh = "C:\Windows\System32\OpenSSH\ssh.exe"
if (-not (Test-Path $ssh)) { $ssh = "C:\Windows\SysWOW64\OpenSSH\ssh.exe" }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ssh
$psi.Arguments = "-p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=15 -i `"$PEM`" ${USER}@${IP} echo CONEXION_OK"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$proc.WaitForExit(20000) | Out-Null
if (-not $proc.HasExited) { $proc.Kill() | Out-Null }

# --- RESULTADO ---
Write-Host ""
if ($proc.ExitCode -eq 0 -and ($proc.StandardOutput.ReadToEnd()) -match "CONEXION_OK") {
    Write-Host "[OK] CONEXION EXITOSA" -ForegroundColor Green
} else {
    Write-Host "[FALLA] NO HAY CONEXION" -ForegroundColor Red
    Write-Host "Error: $($proc.StandardError.ReadToEnd())" -ForegroundColor DarkGray
}

# --- LIMPIAR PEM ---
Remove-Item $PEM -Force -ErrorAction SilentlyContinue