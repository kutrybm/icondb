[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
  [string]$Path,

  [string]$ScriptPath
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

if (-not $ScriptPath) {
  $ScriptPath = Join-Path $PSScriptRoot 'Update-IconDBCpsSchedule.ts'
}

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { $script:failures.Add($Message) }
}

function Read-ZipEntry {
  param(
    [System.IO.Compression.ZipArchive]$Archive,
    [string]$Name
  )
  $entry = $Archive.Entries | Where-Object FullName -eq $Name | Select-Object -First 1
  if (-not $entry) { return $null }
  $reader = [System.IO.StreamReader]::new($entry.Open())
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
  throw "Office Script source not found: $ScriptPath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedPath)
try {
  $workbookText = Read-ZipEntry -Archive $archive -Name 'xl/workbook.xml'
  $relationsText = Read-ZipEntry -Archive $archive -Name 'xl/_rels/workbook.xml.rels'
  Assert-True ($null -ne $workbookText) 'Workbook package is missing xl/workbook.xml.'
  Assert-True ($null -ne $relationsText) 'Workbook package is missing workbook relationships.'

  if ($workbookText -and $relationsText) {
    [xml]$workbook = $workbookText
    [xml]$relations = $relationsText
    $workbookNs = [System.Xml.XmlNamespaceManager]::new($workbook.NameTable)
    $workbookNs.AddNamespace('m', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
    $relationNs = [System.Xml.XmlNamespaceManager]::new($relations.NameTable)
    $relationNs.AddNamespace('r', 'http://schemas.openxmlformats.org/package/2006/relationships')
    $sheetNames = @($workbook.SelectNodes('//m:sheets/m:sheet', $workbookNs) | ForEach-Object { $_.name })
    foreach ($requiredSheet in @('Project schedule', 'Holidays')) {
      Assert-True ($sheetNames -contains $requiredSheet) "Required worksheet '$requiredSheet' is missing."
    }

    $scheduleNode = $workbook.SelectNodes('//m:sheets/m:sheet', $workbookNs) |
    Where-Object name -eq 'Project schedule' | Select-Object -First 1
    if ($scheduleNode) {
      $relationshipId = $scheduleNode.GetAttribute(
        'id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
      )
      $relationship = $relations.SelectSingleNode("//r:Relationship[@Id='$relationshipId']", $relationNs)
      $target = $relationship.Target
      if ($target -notmatch '^xl/') { $target = 'xl/' + $target.TrimStart('/') }
      $scheduleText = Read-ZipEntry -Archive $archive -Name $target
      Assert-True ($null -ne $scheduleText) 'Project schedule worksheet XML is missing.'
      if ($scheduleText) {
        Assert-True ($scheduleText -match '<dimension ref="A1:(?:[A-Z]{2,3})?\d+"') `
          'Project schedule does not expose the expected populated range.'
        Assert-True ($scheduleText -match 'r="F7"') 'Status header cell F7 is missing.'
        Assert-True ($scheduleText -match 'r="J7"') 'Start header cell J7 is missing.'
        Assert-True ($scheduleText -match 'r="K7"') 'End header cell K7 is missing.'
        Assert-True ($scheduleText -match 'r="L7"') 'Initial duration header cell L7 is missing.'
        Assert-True ($scheduleText -match '<f[^>]*>[^<]*(?:WORKDAY|K\d+-J\d+|J\d+\+)') `
          'Project schedule has no recognizable date/dependency formulas.'
      }
    }
  }
}
finally {
  $archive.Dispose()
}

$scriptText = Get-Content -LiteralPath $ScriptPath -Raw
$requiredLiterals = @(
  '"initialize" | "preview" | "apply"',
  'const ALLOWED_STATUSES = ["Done", "In Progress", "Not Started", "Late"]',
  'if (!input.statusSourceComplete)',
  'Number(row.start) === entry.baselineStart && Number(row.end) === entry.baselineEnd',
  'Duplicate recovery row',
  'Circular dependency detected',
  'dependencyMode === "ANY" ? "MIN" : "MAX"',
  '=WORKDAY(TODAY()-1,1,Holidays!$C:$C)',
  'ExcelScript.InsertShiftDirection.down',
  'ExcelScript.RangeCopyType.all',
  'if (input.mode === "preview")',
  'appendLog(logSheet, result)'
)
foreach ($literal in $requiredLiterals) {
  Assert-True ($scriptText.Contains($literal)) "Office Script contract is missing: $literal"
}

Assert-True (-not ($scriptText -match '(?i)(password|api[_ -]?token|bearer\s+[A-Za-z0-9])\s*[:=]')) `
  'Office Script appears to contain a credential or token.'
Assert-True (-not ($scriptText -match '(?i)fetch\s*\(|XMLHttpRequest|https://jira')) `
  'Office Script must not make direct external HTTP requests.'

if ($failures.Count -gt 0) {
  Write-Error ("IconDB CPS validation FAILED:`n - " + ($failures -join "`n - "))
  exit 1
}

Write-Output "IconDB CPS validation PASSED: workbook structure and Office Script contract are valid."
