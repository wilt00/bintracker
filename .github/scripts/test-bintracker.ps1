param(
  [string] $WorkingDirectory,
  [string] $SqliteExecutable,
  [int] $StartupTimeoutSeconds = 120
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
  $expectedMdefCount = @(Get-ChildItem (Join-Path $WorkingDirectory 'mdef') -Directory).Count
  $actualMdefCount = 0
  $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)

  while ([DateTime]::UtcNow -lt $deadline -and $actualMdefCount -ne $expectedMdefCount) {
    if ($process.HasExited) {
      Write-CapturedOutput
      throw "Bintracker exited during startup with code $($process.ExitCode)."
    }

    if (Test-Path $database) {
      $queryResult = & $SqliteExecutable $database 'SELECT COUNT(*) FROM mdefs;' 2>$null
      if ($LASTEXITCODE -eq 0 -and $queryResult -match '^\d+$') {
        $actualMdefCount = [int]$queryResult
      }
    }

    if ($actualMdefCount -ne $expectedMdefCount) {
      Start-Sleep -Seconds 1
    }
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

  if ($actualMdefCount -ne $expectedMdefCount) {
    Stop-TestProcess
    Write-CapturedOutput
    throw "Only $actualMdefCount of $expectedMdefCount MDEFs loaded within $StartupTimeoutSeconds seconds."
  }

  Write-Host "Bintracker remained running and loaded all $actualMdefCount MDEFs; startup smoke test passed."
}
finally {
  Stop-TestProcess
}
