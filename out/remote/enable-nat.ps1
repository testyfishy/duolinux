# Elevate: give the Duo (10.55.0.0/24 over USB) internet through this PC.
$ErrorActionPreference = "Continue"
$prefix = "10.55.0.0/24"

# Remove any stale NAT with the same name
Get-NetNat -Name "DuoNat" -ErrorAction SilentlyContinue | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue

# Make sure the USB adapter keeps its address and forwards
$usb = Get-NetAdapter -InterfaceAlias "Ethernet 3" -ErrorAction Stop
Set-NetIPInterface -InterfaceIndex $usb.ifIndex -Forwarding Enabled -ErrorAction SilentlyContinue

New-NetNat -Name "DuoNat" -InternalIPInterfaceAddressPrefix $prefix -ErrorAction Stop | Out-Null

# Allow it through Windows Firewall on the USB adapter
New-NetFirewallRule -DisplayName "Duo USB NAT" -Direction Inbound -InterfaceAlias "Ethernet 3" `
  -Action Allow -ErrorAction SilentlyContinue | Out-Null

Get-NetNat | Select-Object Name, InternalIPInterfaceAddressPrefix | Format-Table -AutoSize | Out-File "$env:TEMP\duo-nat.txt"
