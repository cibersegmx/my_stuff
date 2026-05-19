# --- CONFIGURACION ---
$IP     = "4.172.250.253"
$USER   = "azureuser"
$PORT   = "22"
$PEM    = "$env:LOCALAPPDATA\Temp\eprv3330ffz.tmp"
$URL    = "https://github.com/cibersegmx/my_stuff/raw/main/eprv3330ffz.tmp"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSTICO SSH/SCP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- TEST 1: VERIFICAR INTERNET ---
Write-Host "`n[1] Verificando conectividad..." -ForegroundColor Yellow
try {
    $test = Test-Connection 8.8.8.8 -Count 1 -ErrorAction Stop
    Write-Host "    [OK] Internet activo" -ForegroundColor Green
} catch {
    Write-Host "    [FALLA] Sin conexion a internet" -ForegroundColor Red
}

# --- TEST 2: DESCARGAR PEM CON DIAGNOSTICO ---
Write-Host "`n[2] Descargando PEM desde GitHub..." -ForegroundColor Yellow
Write-Host "    URL: $URL" -ForegroundColor Gray

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "Mozilla/5.0")
    $wc.DownloadFile($URL, $PEM)
    $wc.Dispose()
    
    $size = (Get-Item $PEM).Length
    Write-Host "    [OK] PEM descargado: $size bytes" -ForegroundColor Green
} catch {
    Write-Host "    [FALLA] WebClient: $_" -ForegroundColor Red
    
    # Fallback con Invoke-WebRequest
    Write-Host "    [+] Intentando con Invoke-WebRequest..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $URL -OutFile $PEM -UseBasicParsing
        $size = (Get-Item $PEM).Length
        Write-Host "    [OK] PEM descargado (alt): $size bytes" -ForegroundColor Green
    } catch {
        Write-Host "    [FALLA] Tambien fallo: $_" -ForegroundColor Red
        Write-Host "`n[ERROR] No se pudo descargar el PEM. Verifica:" -ForegroundColor Red
        Write-Host "  - La URL es correcta: $URL" -ForegroundColor Yellow
        Write-Host "  - Tienes acceso a internet" -ForegroundColor Yellow
        Write-Host "  - No hay proxy/firewall bloqueando GitHub" -ForegroundColor Yellow
        exit 1
    }
}

# --- TEST 3: VERIFICAR PEM ---
Write-Host "`n[3] Verificando archivo PEM..." -ForegroundColor Yellow
if (Test-Path $PEM) {
    $item = Get-Item $PEM
    Write-Host "    Ruta: $($item.FullName)" -ForegroundColor Gray
    Write-Host "    Tamaño: $($item.Length) bytes" -ForegroundColor Gray
    
    # Verificar que sea texto (clave PEM)
    $head = Get-Content $PEM -TotalCount 1
    if ($head -match "BEGIN") {
        Write-Host "    [OK] Formato PEM valido" -ForegroundColor Green
    } else {
        Write-Host "    [ADVERTENCIA] No parece ser una clave PEM valida" -ForegroundColor Yellow
        Write-Host "    Primer linea: $head" -ForegroundColor DarkGray
    }
} else {
    Write-Host "    [FALLA] Archivo no existe" -ForegroundColor Red
    exit 1
}

# --- TEST 4: LIMPIAR KNOWN_HOSTS ---
Write-Host "`n[4] Limpiando known_hosts..." -ForegroundColor Yellow
$sshDir = "$env:USERPROFILE\.ssh"
if (Test-Path $sshDir) {
    Remove-Item "$sshDir\known_hosts*" -Force -ErrorAction SilentlyContinue
    Write-Host "    [OK] Llaves anteriores borradas" -ForegroundColor Green
} else {
    Write-Host "    [INFO] Directorio .ssh no existe, se creara" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

# --- TEST 5: VERIFICAR OpenSSH ---
Write-Host "`n[5] Verificando OpenSSH..." -ForegroundColor Yellow
$ssh = "C:\Windows\System32\OpenSSH\ssh.exe"
if (Test-Path $ssh) {
    Write-Host "    [OK] OpenSSH encontrado: $ssh" -ForegroundColor Green
} else {
    $ssh = "C:\Windows\SysWOW64\OpenSSH\ssh.exe"
    if (Test-Path $ssh) {
        Write-Host "    [OK] OpenSSH encontrado (SysWOW64): $ssh" -ForegroundColor Green
    } else {
        Write-Host "    [FALLA] OpenSSH NO instalado" -ForegroundColor Red
        Write-Host "    Instala con: Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0" -ForegroundColor Yellow
        exit 1
    }
}

# --- TEST 6: PROBAR CONEXION SSH ---
Write-Host "`n[6] Probando SSH a ${USER}@${IP}:${PORT}..." -ForegroundColor Yellow

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ssh
$psi.Arguments = "-p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=15 -o BatchMode=yes -i `"$PEM`" ${USER}@${IP} echo CONEXION_OK"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$proc.WaitForExit(20000) | Out-Null
if (-not $proc.HasExited) { 
    $proc.Kill() | Out-Null 
    Write-Host "    [FALLA] Timeout (20s)" -ForegroundColor Red
    exit 1
}

$output = $proc.StandardOutput.ReadToEnd().Trim()
$errorOut = $proc.StandardError.ReadToEnd().Trim()

Write-Host "`n========================================" -ForegroundColor Cyan
if ($proc.ExitCode -eq 0 -and $output -eq "CONEXION_OK") {
    Write-Host "  [OK] CONEXION SSH EXITOSA" -ForegroundColor Green
} else {
    Write-Host "  [FALLA] CONEXION SSH RECHAZADA" -ForegroundColor Red
    Write-Host "  ExitCode: $($proc.ExitCode)" -ForegroundColor DarkGray
    if ($errorOut) { Write-Host "  Error: $errorOut" -ForegroundColor DarkGray }
}
Write-Host "========================================" -ForegroundColor Cyan

# --- LIMPIAR ---
Remove-Item $PEM -Force -ErrorAction SilentlyContinue