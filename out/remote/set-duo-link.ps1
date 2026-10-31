# Elevate once: put 10.55.0.2/24 on the Duo's USB network adapter.
$name = "Ethernet 3"
$existing = Get-NetIPAddress -InterfaceAlias $name -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -eq "10.55.0.2" }
if (-not $existing) {
  Get-NetIPAddress -InterfaceAlias $name -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -like "169.254.*" } |
    ForEach-Object { Remove-NetIPAddress -InterfaceAlias $name -IPAddress $_.IPAddress -Confirm:$false -ErrorAction SilentlyContinue }
  New-NetIPAddress -InterfaceAlias $name -IPAddress 10.55.0.2 -PrefixLength 24 -ErrorAction Stop | Out-Null
}
Get-NetIPAddress -InterfaceAlias $name -AddressFamily IPv4 |
  Select-Object IPAddress, PrefixLength, InterfaceAlias | Format-Table -AutoSize |
  Out-File -FilePath "$env:TEMP\duo-link.txt"
