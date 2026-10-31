#requires -version 5
<#
  duo-remote.ps1 - drive the Duo Lite over the USB gadget link.

  Usage:
    .\duo-remote.ps1 status            # is the link up? is ssh answering?
    .\duo-remote.ps1 up                # assign 10.55.0.2/24 on the USB adapter
    .\duo-remote.ps1 sh "uptime"       # run a command
    .\duo-remote.ps1 push <local> <remote>
    .\duo-remote.ps1 deploy <dir>      # copy a tree to /home/duo/deploy
    .\duo-remote.ps1 reboot            # reboot and wait for it to come back
    .\duo-remote.ps1 log               # tail duo-diag.txt from the FAT via ssh
#>
param(
  [Parameter(Position = 0)][string]$Command = "status",
  [Parameter(Position = 1)][string]$Arg1,
  [Parameter(Position = 2)][string]$Arg2
)

$ErrorActionPreference = "Stop"
$Repo    = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Key     = Join-Path $Repo "out\duo_ssh_key"
$Device  = "10.55.0.1"
$User    = "duo"
$Ssh     = "C:\Windows\System32\OpenSSH\ssh.exe"
if (-not (Test-Path $Ssh)) { $Ssh = "ssh" }

function Get-UsbAdapter {
  Get-NetAdapter -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceDescription -match 'NCM|RNDIS|Composite|USB' -and $_.Status -eq 'Up' } |
    Select-Object -First 1
}

function Ensure-Link {
  $a = Get-UsbAdapter
  if (-not $a) { throw "No USB network adapter is up. Is the cable connected and the gadget running?" }
  $has = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
           Where-Object { $_.IPAddress -eq '10.55.0.2' }
  if (-not $has) {
    Write-Host "assigning 10.55.0.2/24 to $($a.Name)"
    New-NetIPAddress -InterfaceIndex $a.ifIndex -IPAddress 10.55.0.2 -PrefixLength 24 -ErrorAction Stop | Out-Null
  }
  return $a
}

function Invoke-Duo([string]$cmd) {
  & $Ssh -i $Key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 `
         -o BatchMode=yes "$User@$Device" $cmd
}

switch ($Command) {
  "status" {
    $a = Get-UsbAdapter
    if ($a) { "adapter: $($a.Name) $($a.InterfaceDescription) [$($a.Status)]" } else { "adapter: none" }
    try { $r = Invoke-Duo "uptime; uname -r"; "ssh: $r" } catch { "ssh: not answering ($($_.Exception.Message))" }
  }
  "up" { (Ensure-Link) | Format-Table Name, Status, LinkSpeed }
  "sh" { Ensure-Link | Out-Null; Invoke-Duo $Arg1 }
  "push" {
    Ensure-Link | Out-Null
    & "C:\Windows\System32\OpenSSH\scp.exe" -i $Key -o StrictHostKeyChecking=no `
        $Arg1 "$User@${Device}:$Arg2"
  }
  "deploy" {
    Ensure-Link | Out-Null
    Invoke-Duo "mkdir -p ~/deploy" | Out-Null
    & "C:\Windows\System32\OpenSSH\scp.exe" -r -i $Key -o StrictHostKeyChecking=no $Arg1 "$User@${Device}:~/deploy/"
  }
  "reboot" {
    Ensure-Link | Out-Null
    try { Invoke-Duo "sudo systemctl reboot" } catch { }
    Write-Host "reboot sent; waiting for ssh to return..."
    for ($i = 0; $i -lt 60; $i++) {
      Start-Sleep -Seconds 5
      try { $u = Invoke-Duo "uptime"; Write-Host "back: $u"; break } catch { Write-Host "  ...$($i*5)s" }
    }
  }
  "log" { Ensure-Link | Out-Null; Invoke-Duo "cat /boot/duo-diag.txt 2>/dev/null || sudo cat /mnt/duoboot/duo-diag.txt 2>/dev/null" }
  default { Get-Help $PSCommandPath }
}
