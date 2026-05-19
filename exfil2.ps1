$url = "https://github.com/cibersegmx/my_stuff/raw/main/eprv3330ffz.tmp"
$output = "$env:LOCALAPPDATA\Temp\test_pem.tmp"

# Método 1: WebClient
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($url, $output)

# Verificar
Get-Item $output