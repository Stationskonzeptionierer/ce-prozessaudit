$ErrorActionPreference = 'Stop'
$httpPort = 8765
$httpsPort = 8766
$base = $PSScriptRoot
$certFolder = Join-Path $base 'lokale_zertifikate'
New-Item -ItemType Directory -Path $certFolder -Force | Out-Null

# Collect active IPv4 addresses; device must be on same trusted local network.
$ips = @([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
 Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' } |
 ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
 Where-Object { $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and -not $_.Address.ToString().StartsWith('169.254.') } |
 ForEach-Object { $_.Address.ToString() } | Select-Object -Unique)
if ($ips.Count -lt 1) { throw 'Keine aktive IPv4-Netzwerkadresse gefunden. Bitte WLAN pruefen.' }
$certPath = Join-Path $certFolder 'CE_Audit_Lokale_CA.cer'
$stateFile = Join-Path $certFolder 'zustand.clixml'

# CA and server certificate are generated ON THIS PC, never shipped inside ZIP.
# Windows 10/11: New-SelfSignedCertificate via native Windows certificate API.
$needCert = $true
if(Test-Path $stateFile) {
 try {
  $state = Import-Clixml $stateFile
  $stored = @($state.IPs)
  if((@($ips) -join ',') -eq ($stored -join ',') -and (Test-Path $certPath)) {
   $serverCert = Get-Item ('Cert:\CurrentUser\My\' + $state.ServerThumbprint) -ErrorAction SilentlyContinue
   if($serverCert -and $serverCert.HasPrivateKey -and $serverCert.NotAfter -gt (Get-Date).AddDays(1)) { $needCert = $false }
  }
 } catch {}
}
if($needCert) {
 Write-Host 'Erstelle lokale Zertifikate fuer die aktuelle WLAN-IP-Adresse ...' -ForegroundColor Yellow
 $root = New-SelfSignedCertificate -Type Custom -Subject 'CN=CE Audit Lokale Test CA' `
  -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyUsage CertSign,CRLSign `
  -KeyUsageProperty Sign -KeyExportPolicy Exportable -CertStoreLocation 'Cert:\CurrentUser\My' `
  -TextExtension @('2.5.29.19={critical}{text}ca=true&pathlength=0') `
  -NotAfter (Get-Date).AddMonths(6)
 $san = (@($ips | ForEach-Object { 'IPAddress=' + $_ }) -join '&')
 $serverCert = New-SelfSignedCertificate -Type Custom -Subject 'CN=CE Audit Local' `
  -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyUsage DigitalSignature,KeyEncipherment `
  -KeyExportPolicy Exportable -CertStoreLocation 'Cert:\CurrentUser\My' -Signer $root `
  -TextExtension @("2.5.29.17={text}$san",'2.5.29.37={text}1.3.6.1.5.5.7.3.1','2.5.29.19={critical}{text}ca=false') `
  -NotAfter (Get-Date).AddMonths(5)
 Export-Certificate -Cert $root -FilePath $certPath -Force | Out-Null
 [pscustomobject]@{IPs=@($ips);ServerThumbprint=$serverCert.Thumbprint} | Export-Clixml -Path $stateFile
}

function Send-Response($stream, [string]$urlPath, [bool]$secure) {
 $plain = $urlPath.Split('?')[0]
 $plain = [uri]::UnescapeDataString($plain)
 $contentType = 'text/plain; charset=utf-8'
 $status = '200 OK'
 $body = $null
 $map = @{
  '/'='index.html'; '/index.html'='index.html'; '/sw.js'='sw.js';
  '/manifest.webmanifest'='manifest.webmanifest'; '/icon-192.png'='icon-192.png'; '/icon-512.png'='icon-512.png'
 }
 if(-not $secure) {
  if($plain -eq '/CE_Audit_Lokale_CA.cer') {
   $body = [System.IO.File]::ReadAllBytes($certPath)
   $contentType = 'application/x-x509-ca-cert'
  } elseif($plain -eq '/' -or $plain -eq '/index.html') {
   $links = (@($ips | ForEach-Object { '<p><a href="https://' + $_ + ':' + $httpsPort + '/">HTTPS-App fuer ' + $_ + '</a></p>' }) -join "`n")
   $page = '<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CE Audit Installation</title><body style="font:16px Arial;max-width:650px;margin:25px auto;padding:0 18px"><h1>CE Audit | Erstinstallation</h1><p><b>1.</b> Lokales Testzertifikat auf diesem iPhone laden: <a href="/CE_Audit_Lokale_CA.cer">Zertifikat herunterladen</a>.</p><p><b>2.</b> Auf dem iPhone: Einstellungen &gt; Profil geladen bzw. Allgemein &gt; VPN &amp; Geraeteverwaltung &gt; Profil installieren.</p><p><b>3.</b> Einstellungen &gt; Allgemein &gt; Info &gt; Zertifikatsvertrauenseinstellungen: volle Vertrauensstellung fuer CE Audit aktivieren.</p><p><b>4.</b> Safari HTTPS-App aufrufen:</p>' + $links + '<p><b>5.</b> In der App auf "Offline bereit" warten, dann Teilen &gt; Zum Home-Bildschirm.</p><p>Nur auf einem privaten Testgeraet. Bei Firmen-iPhones vorab IT-Freigabe einholen. Keine Patientendaten eingeben.</p></body></html>'
   $body = [System.Text.Encoding]::UTF8.GetBytes($page)
   $contentType = 'text/html; charset=utf-8'
  }
 } elseif($map.ContainsKey($plain)) {
  $file = Join-Path $base $map[$plain]
  $body = [System.IO.File]::ReadAllBytes($file)
  switch -Regex ($plain) {
   '\.html$|^/$' {$contentType='text/html; charset=utf-8';break}
   '\.js$' {$contentType='application/javascript; charset=utf-8';break}
   '\.webmanifest$' {$contentType='application/manifest+json; charset=utf-8';break}
   '\.png$' {$contentType='image/png';break}
  }
 }
 if($null -eq $body) { $status='404 Not Found'; $body=[System.Text.Encoding]::UTF8.GetBytes('Nicht gefunden') }
 $cache = if($plain -eq '/sw.js') { 'no-cache' } else { 'no-store' }
 $head = "HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nCache-Control: $cache`r`nConnection: close`r`nX-Content-Type-Options: nosniff`r`n`r`n"
 $bytes = [System.Text.Encoding]::ASCII.GetBytes($head)
 $stream.Write($bytes,0,$bytes.Length)
 $stream.Write($body,0,$body.Length)
 $stream.Flush()
}

function Handle-Client($client,[bool]$secure) {
 $stream=$null
 try {
  $client.ReceiveTimeout=7000; $client.SendTimeout=7000
  $stream=$client.GetStream()
  if($secure) {
   $tls = New-Object System.Net.Security.SslStream($stream,$false)
   $tls.AuthenticateAsServer($serverCert,$false,[System.Security.Authentication.SslProtocols]::Tls12,$false)
   $stream=$tls
  }
  $reader = New-Object System.IO.StreamReader($stream,[System.Text.Encoding]::ASCII,$false,1024,$true)
  $line=$reader.ReadLine()
  if(-not $line){return}
  do { $h=$reader.ReadLine() } while($null -ne $h -and $h.Length -gt 0)
  $parts=$line.Split(' ')
  if($parts.Length -lt 2){return}
  if($parts[0] -ne 'GET' -and $parts[0] -ne 'HEAD'){return}
  Send-Response $stream $parts[1] $secure
 } catch { Write-Host ('Anfrage gescheitert: '+$_.Exception.Message) -ForegroundColor DarkYellow }
 finally { if($stream){$stream.Dispose()};$client.Close() }
}

$httpListener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $httpPort)
$httpsListener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $httpsPort)
try {
 $httpListener.Start(); $httpsListener.Start()
 Write-Host ''
 Write-Host 'CE PROZESSAUDIT | HTTPS Offline-PWA' -ForegroundColor Green
 Write-Host 'Auf dem iPhone in Safari ZUERST die Einrichtungsseite oeffnen:' -ForegroundColor Yellow
 foreach($ip in $ips){Write-Host "  http://${ip}:$httpPort/" -ForegroundColor Cyan}
 Write-Host 'Zertifikat installieren + volles Vertrauen aktivieren, dann HTTPS-Link nutzen.'
 Write-Host 'Nur privates WLAN; keine Patientendaten; nur auf Testgeraeten.'
 Write-Host 'Firewall ausschliesslich fuer privates Netzwerk freigeben.'
 Write-Host 'Beenden: Strg+C oder Fenster schliessen.'
 while($true) {
  if($httpsListener.Pending()) {Handle-Client $httpsListener.AcceptTcpClient() $true}
  if($httpListener.Pending()) {Handle-Client $httpListener.AcceptTcpClient() $false}
  Start-Sleep -Milliseconds 35
 }
} finally {
 $httpListener.Stop(); $httpsListener.Stop()
}
