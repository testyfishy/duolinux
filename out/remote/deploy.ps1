#requires -version 5
<#
  deploy.ps1 - push changed files to the Duo safely.

  Every deploy:
    1. tars the files that will be overwritten into /var/backups/deploy-N.tar
    2. extracts the new tree over /
    3. arms a dead-man timer: if I do not confirm within N seconds, it restores
       the backup and reboots
    4. confirms with:  .\deploy.ps1 confirm

  Usage:
    .\deploy.ps1 push  .\rootfs-tree            # tree mirrors / (etc/..., usr/...)
    .\deploy.ps1 confirm
    .\deploy.ps1 sh "systemctl status ssh"
    .\deploy.ps1 reboot
#>
param(
  [Parameter(Position = 0)][string]$Command = "sh",
  [Parameter(Position = 1)][string]$Arg1
)

$ErrorActionPreference = "Stop"
$Repo   = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Key    = Join-Path $Repo "out\duo_ssh_key"
$Target = "duo@10.55.0.1"
$Ssh    = "C:\Windows\System32\OpenSSH\ssh.exe"
$Scp    = "C:\Windows\System32\OpenSSH\scp.exe"
$Opts   = @("-i", $Key, "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ConnectTimeout=10", "-o", "BatchMode=yes")
$Deadman = 240

function Remote([string]$cmd) { & $Ssh @Opts $Target $cmd }

switch ($Command) {
  "sh" { Remote $Arg1 }
  "push" {
    $src = (Resolve-Path $Arg1).Path
    $tmp = Join-Path $env:TEMP "duo-deploy.tar"
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
    tar -cf $tmp -C $src .
    & $Scp @Opts $tmp "${Target}:/tmp/deploy.tar"
    $script = @"
set -e
N=`$(date +%s)
sudo mkdir -p /var/backups/duo
sudo tar -cf /var/backups/duo/deploy-`$N.tar -T <(tar -tf /tmp/deploy.tar | sed 's|^\./||') 2>/dev/null || true
sudo tar -xf /tmp/deploy.tar -C /
sudo systemctl daemon-reload
sudo systemd-run --on-active=$Deadman --unit=duo-deadman /usr/local/sbin/duo-rollback `$N
echo "deployed; confirm within $Deadman s with: .\deploy.ps1 confirm"
"@
    Remote $script
  }
  "confirm" {
    Remote "sudo systemctl stop duo-deadman.timer 2>/dev/null; sudo systemctl reset-failed duo-deadman.timer 2>/dev/null; echo confirmed"
  }
  "reboot" {
    try { Remote "sync; sudo systemctl reboot" } catch { }
    Write-Host "rebooting; waiting for ssh..."
    for ($i = 0; $i -lt 60; $i++) {
      Start-Sleep -Seconds 5
      try { $u = Remote "uptime"; Write-Host "back: $u"; break } catch { }
    }
  }
  default { Get-Help $PSCommandPath }
}
