# ============================================================
# PRUEBA DE CONEXION SSH/SCP - MINIMAL
# ============================================================

# --- SUPRIMIR ERRORES ---
$ErrorActionPreference = "SilentlyContinue"

# --- CONFIGURACION ---
$SERVIDOR_IP   = "4.172.250.253"
$USUARIO_SSH   = "azureuser"
$PUERTO_SSH    = "22"
$URL_PEM       = "https://github.com/cibersegmx/my_stuff/raw/main/eprv3330ffz.tmp"
$TEMP_DIR      = "$env:LOCALAPPDATA\Temp"
$PEM_LOCAL     = "$TEMP_DIR\eprv3330ffz.tmp"

# ============================================================
# FASE 1: DESCARGAR PEM
# ============================================================
Write-Host "[1/4] Descargando PEM..." -ForegroundColor Cyan

$downloadOk = $false

# Intentar con WebClient
try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($URL_PEM, $PEM_LOCAL)
    $wc.Dispose()
    $downloadOk = $true
    Write-Host "    [OK] Descarga con WebClient" -ForegroundColor Green
} catch {
    Write-Host "    [FALLA] WebClient: $_" -ForegroundColor Red
}

# Fallback con curl
if (-not $downloadOk) {
    try {
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c curl -L -o `"$PEM_LOCAL`" `"$URL_PEM`"" -Wait -WindowStyle Hidden -PassThru
        if ((Test-Path $PEM_LOCAL) -and ((Get-Item $PEM_LOCAL).Length -gt 100)) {
            $downloadOk = $true
            Write-Host "    [OK] Descarga con curl" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [FALLA] curl: $_" -ForegroundColor Red
    }
}

if (-not $downloadOk) {
    Write-Host "[ERROR] No se pudo descargar el PEM. Abortando." -ForegroundColor Red
    exit 1
}

# Corregir permisos PEM
if (Test-Path $PEM_LOCAL) {
    icacls "$PEM_LOCAL" /inheritance:r /grant:r "${env:USERNAME}:(R)" | Out-Null
    Write-Host "    [OK] PEM guardado: $PEM_LOCAL ($((Get-Item $PEM_LOCAL).Length) bytes)" -ForegroundColor Green
}

# ============================================================
# FASE 2: VERIFICAR OpenSSH
# ============================================================
Write-Host "`n[2/4] Verificando OpenSSH..." -ForegroundColor Cyan

$sshPath = "C:\Windows\System32\OpenSSH\ssh.exe"
$scpPath = "C:\Windows\System32\OpenSSH\scp.exe"

if (-not (Test-Path $sshPath)) {
    Write-Host "    OpenSSH no encontrado. Instalando..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
    Start-Sleep -Seconds 10
    
    if (-not (Test-Path $sshPath)) {
        $sshPath = "C:\Windows\SysWOW64\OpenSSH\ssh.exe"
        $scpPath = "C:\Windows\SysWOW64\OpenSSH\scp.exe"
    }
}

if (Test-Path $sshPath) {
    Write-Host "    [OK] SSH: $sshPath" -ForegroundColor Green
} else {
    Write-Host "    [ERROR] No se encontro OpenSSH" -ForegroundColor Red
    exit 1
}

if (Test-Path $scpPath) {
    Write-Host "    [OK] SCP: $scpPath" -ForegroundColor Green
} else {
    Write-Host "    [ADVERTENCIA] SCP no encontrado" -ForegroundColor Yellow
}

# ============================================================
# FASE 3: PROBAR CONEXION SSH
# ============================================================
Write-Host "`n[3/4] Probando conexion SSH..." -ForegroundColor Cyan

$sshArgs = "-p $PUERTO_SSH -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=15 -o BatchMode=yes -i `"$PEM_LOCAL`" ${USUARIO_SSH}@${SERVIDOR_IP} `"echo 'CONEXION_OK'`""

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $sshPath
$psi.Arguments = $sshArgs
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$proc.WaitForExit(20000) | Out-Null

if (-not $proc.HasExited) {
    $proc.Kill() | Out-Null
    Write-Host "    [ERROR] Timeout SSH (20s)" -ForegroundColor Red
    exit 1
}

$output = $proc.StandardOutput.ReadToEnd()
$errorOutput = $proc.StandardError.ReadToEnd()

if ($proc.ExitCode -eq 0 -and $output -match "CONEXION_OK") {
    Write-Host "    [OK] SSH funciona correctamente!" -ForegroundColor Green
    Write-Host "    Respuesta: $output" -ForegroundColor Gray
} else {
    Write-Host "    [ERROR] SSH fallo (ExitCode: $($proc.ExitCode))" -ForegroundColor Red
    Write-Host "    StdOut: $output" -ForegroundColor DarkGray
    Write-Host "    StdErr: $errorOutput" -ForegroundColor DarkGray
    exit 1
}

# ============================================================
# FASE 4: PROBAR SCP (crear archivo de prueba y subirlo)
# ============================================================
Write-Host "`n[4/4] Probando transferencia SCP..." -ForegroundColor Cyan

# Crear archivo de prueba local
$testLocal = "$TEMP_DIR\test_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
"PRUEBA_SCP_OK desde $env:COMPUTERNAME por $env:USERNAME" | Out-File -FilePath $testLocal -Encoding UTF8

$remoteFolder = "/home/$USUARIO_SSH"
$remoteFile = "$remoteFolder/$(Split-Path $testLocal -Leaf)"

# Crear directorio remoto primero
$mkdirPsi = New-Object System.Diagnostics.ProcessStartInfo
$mkdirPsi.FileName = $sshPath
$mkdirPsi.Arguments = "-p $PUERTO_SSH -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=10 -i `"$PEM_LOCAL`" ${USUARIO_SSH}@${SERVIDOR_IP} `"mkdir -p $remoteFolder`""
$mkdirPsi.RedirectStandardOutput = $true
$mkdirPsi.RedirectStandardError = $true
$mkdirPsi.UseShellExecute = $false
$mkdirPsi.CreateNoWindow = $true
$mkdirProc = [System.Diagnostics.Process]::Start($mkdirPsi)
$mkdirProc.WaitForExit(10000) | Out-Null
if (-not $mkdirProc.HasExited) { $mkdirProc.Kill() | Out-Null }

# Subir archivo de prueba
$scpPsi = New-Object System.Diagnostics.ProcessStartInfo
$scpPsi.FileName = $scpPath
$scpPsi.Arguments = "-P $PUERTO_SSH -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=30 -i `"$PEM_LOCAL`" `"$testLocal`" ${USUARIO_SSH}@${SERVIDOR_IP}:$remoteFile"
$scpPsi.RedirectStandardOutput = $true
$scpPsi.RedirectStandardError = $true
$scpPsi.UseShellExecute = $false
$scpPsi.CreateNoWindow = $true

$scpProc = [System.Diagnostics.Process]::Start($scpPsi)
$scpProc.WaitForExit(30000) | Out-Null

if (-not $scpProc.HasExited) {
    $scpProc.Kill() | Out-Null
    Write-Host "    [ERROR] Timeout SCP (30s)" -ForegroundColor Red
} else {
    $scpError = $scpProc.StandardError.ReadToEnd()
    
    if ($scpProc.ExitCode -eq 0) {
        Write-Host "    [OK] SCP funciona! Archivo subido a:" -ForegroundColor Green
        Write-Host "    $remoteFile" -ForegroundColor Gray
        
        # Verificar en servidor
        $verifyPsi = New-Object System.Diagnostics.ProcessStartInfo
        $verifyPsi.FileName = $sshPath
        $verifyPsi.Arguments = "-p $PUERTO_SSH -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -i `"$PEM_LOCAL`" ${USUARIO_SSH}@${SERVIDOR_IP} `"ls -la $remoteFile`""
        $verifyPsi.RedirectStandardOutput = $true
        $verifyPsi.UseShellExecute = $false
        $verifyPsi.CreateNoWindow = $true
        $verifyProc = [System.Diagnostics.Process]::Start($verifyPsi)
        $verifyProc.WaitForExit(10000) | Out-Null
        $verifyOut = $verifyProc.StandardOutput.ReadToEnd()
        Write-Host "    Verificacion remota: $verifyOut" -ForegroundColor Gray
    } else {
        Write-Host "    [ERROR] SCP fallo (ExitCode: $($scpProc.ExitCode))" -ForegroundColor Red
        Write-Host "    Error: $scpError" -ForegroundColor DarkGray
    }
}

# ============================================================
# LIMPIEZA LOCAL
# ============================================================
Write-Host "`n[+] Limpiando archivos locales..." -ForegroundColor Cyan
Remove-Item $PEM_LOCAL -Force -ErrorAction SilentlyContinue
Remove-Item $testLocal -Force -ErrorAction SilentlyContinue
Write-Host "    [OK] Limpieza completada" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  PRUEBA FINALIZADA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green