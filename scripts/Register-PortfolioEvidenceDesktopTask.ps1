[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$CloudProjectionDirectory,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$CompletedProjectionDirectory,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$CandidateDirectory,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$PreviousStatePath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$PromoteToState,

  [string]$TaskName = 'IconDB Portfolio Evidence Desktop',

  [switch]$Register,

  [switch]$Replace
)

$ErrorActionPreference = 'Stop'
$orchestrator = Join-Path $PSScriptRoot 'Invoke-PortfolioEvidenceDesktop.ps1'
$userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name

function Quote-Argument([string]$Value) { return '"' + $Value.Replace('"', '""') + '"' }

$arguments = @(
  '-NoProfile',
  '-ExecutionPolicy Bypass',
  '-File ' + (Quote-Argument $orchestrator),
  '-CloudProjectionDirectory ' + (Quote-Argument ([IO.Path]::GetFullPath($CloudProjectionDirectory))),
  '-CompletedProjectionDirectory ' + (Quote-Argument ([IO.Path]::GetFullPath($CompletedProjectionDirectory))),
  '-CandidateDirectory ' + (Quote-Argument ([IO.Path]::GetFullPath($CandidateDirectory))),
  '-PreviousStatePath ' + (Quote-Argument ([IO.Path]::GetFullPath($PreviousStatePath))),
  '-PromoteToState ' + (Quote-Argument ([IO.Path]::GetFullPath($PromoteToState)))
) -join ' '

Write-Host "Task: $TaskName"
Write-Host "User: $userId (interactive logon only)"
Write-Host 'Schedule: Monday-Friday at 07:30/07:45, 11:30/11:45, 13:30/13:45, and 14:30/14:45, plus at logon'
Write-Host 'Concurrency: IgnoreNew; missed starts run when available'
if ($Replace -and -not $Register) { throw '-Replace requires -Register.' }
if (-not $Register) {
  Write-Host 'PREVIEW ONLY: no scheduled task was created. Use -Register only after explicit approval.' -ForegroundColor Yellow
  exit 0
}

if (-not (Test-Path -LiteralPath $orchestrator -PathType Leaf)) { throw "Orchestrator not found: $orchestrator" }
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $existing -and -not $Replace) { throw "Scheduled task already exists: $TaskName. Use -Register -Replace to update it explicitly." }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments -WorkingDirectory (Split-Path $PSScriptRoot -Parent)
$weekdayTriggers = @('07:30', '07:45', '11:30', '11:45', '13:30', '13:45', '14:30', '14:45') | ForEach-Object {
  New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Monday, Tuesday, Wednesday, Thursday, Friday -At $_
}
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$triggers = @($weekdayTriggers) + $logonTrigger
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
$task = New-ScheduledTask -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Description 'Completes privacy-minimized portfolio evidence while the user is signed in.'
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force:$Replace | Out-Null
Write-Host "Registered scheduled task: $TaskName" -ForegroundColor Green
