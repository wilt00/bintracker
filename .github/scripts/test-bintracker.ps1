param(
  [string] $WorkingDirectory
)

$ErrorActionPreference = 'Stop'

if (-not $WorkingDirectory) {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  $WorkingDirectory = Join-Path $repoRoot 'build'
}
$WorkingDirectory = (Resolve-Path $WorkingDirectory).Path
$executable = Join-Path $WorkingDirectory 'bintracker.exe'
$stdout = Join-Path $env:RUNNER_TEMP 'bintracker-smoke.stdout.txt'
$stderr = Join-Path $env:RUNNER_TEMP 'bintracker-smoke.stderr.txt'
$crashLogsBefore = @{}
Get-ChildItem $WorkingDirectory -Filter 'crash-*.log' | ForEach-Object {
  $crashLogsBefore[$_.FullName] = $_.LastWriteTimeUtc
}

Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue
$process = Start-Process -FilePath $executable `
  -WorkingDirectory $WorkingDirectory `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr `
  -PassThru

try {
  if ($process.WaitForExit(10000)) {
    Write-Host '--- stdout ---'
    if (Test-Path $stdout) { Get-Content $stdout }
    Write-Host '--- stderr ---'
    if (Test-Path $stderr) { Get-Content $stderr }
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

  Write-Host 'Bintracker remained running without a crash log for 10 seconds; startup smoke test passed.'
}
finally {
  if (-not $process.HasExited) {
    taskkill.exe /PID $process.Id /T /F | Out-Host
    $process.WaitForExit()
  }
}
