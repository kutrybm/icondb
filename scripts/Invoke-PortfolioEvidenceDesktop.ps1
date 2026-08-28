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

  [string]$PromoteToState,

  [string]$PythonPath,

  [string]$CloudFilePattern = 'portfolio-evidence-projection-cloud-*.json',

  [ValidateRange(0.01, 24)]
  [double]$MaxAgeHours = 3
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($PythonPath)) {
  $PythonPath = Join-Path (Split-Path $PSScriptRoot -Parent) '.venv\Scripts\python.exe'
}
$collector = Join-Path $PSScriptRoot 'Collect-OutlookPortfolioMetadata.py'
$builder = Join-Path $PSScriptRoot 'ConvertTo-PortfolioEvidenceDelta.ps1'
$lockPath = Join-Path ([IO.Path]::GetFullPath($CompletedProjectionDirectory)) 'desktop-orchestration.lock'
$lockStream = $null
$completedProjectionPath = $null
$candidatePath = $null
$createdCompletedProjection = $false
$createdCandidate = $false

function Write-Stage([string]$Stage, [string]$Status) {
  Write-Host "$([DateTimeOffset]::Now.ToString('o')) [$Stage] $Status"
}

try {
  foreach ($requiredPath in @($PythonPath, $collector, $builder, $PreviousStatePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { throw "Required file not found: $requiredPath" }
  }
  foreach ($directory in @($CloudProjectionDirectory, $CompletedProjectionDirectory, $CandidateDirectory)) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($directory)) | Out-Null
  }

  try {
    $lockStream = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  }
  catch [IO.IOException] { throw "Another desktop portfolio orchestration is active: $lockPath" }

  $cloudFiles = @(Get-ChildItem -LiteralPath $CloudProjectionDirectory -Filter $CloudFilePattern -File | Sort-Object Name)
  $pending = @()
  foreach ($cloudFile in $cloudFiles) {
    $completedName = $cloudFile.Name -replace '-cloud-', '-complete-'
    if (-not (Test-Path -LiteralPath (Join-Path $CompletedProjectionDirectory $completedName))) { $pending += $cloudFile }
  }
  if ($pending.Count -eq 0) {
    Write-Stage 'discovery' 'no pending cloud projection'
    exit 0
  }

  $cloudProjection = $pending[0]
  $completedName = $cloudProjection.Name -replace '-cloud-', '-complete-'
  if ($completedName -eq $cloudProjection.Name) { throw "Cloud filename does not contain the required -cloud- marker: $($cloudProjection.Name)" }
  $completedProjectionPath = Join-Path $CompletedProjectionDirectory $completedName
  $projectionMetadata = Get-Content -LiteralPath $cloudProjection.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
  $candidateName = [IO.Path]::GetFileName([string]$projectionMetadata.run.candidatePath)
  if ([string]::IsNullOrWhiteSpace($candidateName) -or $candidateName -notmatch '^portfolio-evidence-delta-.+\.json$') {
    throw 'Cloud projection run.candidatePath has an invalid candidate filename.'
  }
  $candidatePath = Join-Path $CandidateDirectory $candidateName
  if (Test-Path -LiteralPath $completedProjectionPath) { throw "Completed projection already exists: $completedProjectionPath" }
  if (Test-Path -LiteralPath $candidatePath) { throw "Candidate already exists: $candidatePath" }

  Write-Stage 'outlook-collection' 'started'
  $createdCompletedProjection = $true
  & $PythonPath $collector --cloud-projection $cloudProjection.FullName --output-projection $completedProjectionPath
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $completedProjectionPath -PathType Leaf)) {
    throw 'Outlook metadata collection did not produce a completed projection.'
  }
  Write-Stage 'outlook-collection' 'complete'

  Write-Stage 'delta-build' 'started'
  $createdCandidate = $true
  $builderArguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $builder,
    '-ProjectionPath', $completedProjectionPath,
    '-PreviousStatePath', $PreviousStatePath,
    '-OutputPath', $candidatePath,
    '-MaxAgeHours', [string]$MaxAgeHours
  )
  if (-not [string]::IsNullOrWhiteSpace($PromoteToState)) {
    $builderArguments += @('-PromoteToState', $PromoteToState)
  }
  & powershell @builderArguments
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
    throw 'The strict delta builder did not produce a candidate.'
  }
  Write-Stage 'delta-build' 'complete'

  if (-not [string]::IsNullOrWhiteSpace($PromoteToState)) {
    Write-Stage 'state-promotion' 'complete'
  }

  Write-Stage 'orchestration' 'complete'
}
catch {
  if ($createdCandidate -and $null -ne $candidatePath) { Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue }
  if ($createdCompletedProjection -and $null -ne $completedProjectionPath) { Remove-Item -LiteralPath $completedProjectionPath -Force -ErrorAction SilentlyContinue }
  Write-Error "Desktop portfolio orchestration failed: $($_.Exception.Message)"
  exit 1
}
finally {
  if ($null -ne $lockStream) {
    $lockStream.Dispose()
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
  }
}

exit 0
