param(
  [string] $WorkingDirectory,
  [string] $SqliteExecutable
)

$ErrorActionPreference = 'Stop'

if (-not $WorkingDirectory) {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  $WorkingDirectory = Join-Path $repoRoot 'build'
}
$WorkingDirectory = (Resolve-Path $WorkingDirectory).Path
if ($SqliteExecutable) {
  $SqliteExecutable = (Resolve-Path $SqliteExecutable).Path
}
else {
  $SqliteExecutable = (Get-Command sqlite3.exe -ErrorAction Stop).Source
}
$executable = Join-Path $WorkingDirectory 'bintracker.exe'
$database = Join-Path $WorkingDirectory 'bt.db'
$stdout = Join-Path $env:RUNNER_TEMP 'bintracker-smoke.stdout.txt'
$stderr = Join-Path $env:RUNNER_TEMP 'bintracker-smoke.stderr.txt'
$crashLogsBefore = @{}
Get-ChildItem $WorkingDirectory -Filter 'crash-*.log' | ForEach-Object {
  $crashLogsBefore[$_.FullName] = $_.LastWriteTimeUtc
}

Remove-Item $stdout, $stderr, $database -Force -ErrorAction SilentlyContinue
$process = Start-Process -FilePath $executable `
  -WorkingDirectory $WorkingDirectory `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr `
  -PassThru

function Stop-TestProcess {
  if (-not $process.HasExited) {
    taskkill.exe /PID $process.Id /T /F | Out-Host
    $process.WaitForExit()
  }
}

function Write-CapturedOutput {
  Write-Host '--- stdout ---'
  if (Test-Path $stdout) { Get-Content $stdout }
  Write-Host '--- stderr ---'
  if (Test-Path $stderr) { Get-Content $stderr }
}

try {
  if ($process.WaitForExit(10000)) {
    Write-CapturedOutput
    throw "Bintracker exited during startup with code $($process.ExitCode)."
  }

  $newCrashLogs = @(Get-ChildItem $WorkingDirectory -Filter 'crash-*.log' | Where-Object {
    -not $crashLogsBefore.ContainsKey($_.FullName) -or
      $_.LastWriteTimeUtc -gt $crashLogsBefore[$_.FullName]
  })
  if ($newCrashLogs) {
    foreach ($crashLog in $newCrashLogs) {
      Write-Host "--- $($crashLog.Name) ---"
      Get-Content $crashLog.FullName
    }
    throw 'Bintracker generated a crash log during startup.'
  }

  $expectedMdefCount = @(Get-ChildItem (Join-Path $WorkingDirectory 'mdef') -Directory).Count
  $actualMdefCount = & $SqliteExecutable $database 'SELECT COUNT(*) FROM mdefs;'
  if ($LASTEXITCODE -ne 0) {
    Stop-TestProcess
    Write-CapturedOutput
    throw "Could not inspect the generated MDEF database (sqlite3 exit code $LASTEXITCODE)."
  }
  if ([int]$actualMdefCount -ne $expectedMdefCount) {
    Stop-TestProcess
    Write-CapturedOutput
    throw "Only $actualMdefCount of $expectedMdefCount MDEFs loaded during startup."
  }

  Write-Host "Bintracker remained running and loaded all $actualMdefCount MDEFs; startup smoke test passed."
}
finally {
  Stop-TestProcess
}
