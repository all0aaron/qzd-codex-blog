param(
    [int]$MaxIterations = 10,
    [string]$ProjectDir = ""
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PrdFile    = Join-Path $ScriptDir "prd.json"
$ProgressFile = Join-Path $ScriptDir "progress.txt"
$PromptFile = Join-Path $ScriptDir "CODEX.md"
$LastBranchFile = Join-Path $ScriptDir ".last-branch"
$ArchiveDir = Join-Path $ScriptDir "archive"

if ([string]::IsNullOrEmpty($ProjectDir)) {
    $ProjectDir = (Get-Location).Path
}

if (-not (Test-Path $PrdFile)) {
    Write-Host "ERROR: prd.json not found at $PrdFile" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $PromptFile)) {
    Write-Host "ERROR: CODEX.md not found at $PromptFile" -ForegroundColor Red
    exit 1
}
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: codex command not found. Please install Codex CLI." -ForegroundColor Red
    exit 1
}

# Archive previous run if branch changed
try {
    $prdData = Get-Content $PrdFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $currentBranch = $prdData.branchName
    if ((Test-Path $LastBranchFile) -and $currentBranch) {
        $lastBranch = (Get-Content $LastBranchFile -Encoding UTF8).Trim()
        if ($lastBranch -and $lastBranch -ne $currentBranch) {
            $date = Get-Date -Format "yyyy-MM-dd"
            $folderName = $lastBranch -replace "^ralph/", ""
            $archiveFolder = Join-Path $ArchiveDir "$date-$folderName"
            Write-Host "[Archive] Previous run: $lastBranch" -ForegroundColor DarkGray
            New-Item -ItemType Directory -Force -Path $archiveFolder | Out-Null
            if (Test-Path $PrdFile)      { Copy-Item $PrdFile $archiveFolder }
            if (Test-Path $ProgressFile) { Copy-Item $ProgressFile $archiveFolder }
            "# Ralph Progress Log"     | Out-File $ProgressFile -Encoding UTF8
            "Started: $(Get-Date)"     | Out-File $ProgressFile -Append -Encoding UTF8
            "---"                      | Out-File $ProgressFile -Append -Encoding UTF8
        }
    }
    if ($currentBranch) { $currentBranch | Out-File $LastBranchFile -Encoding UTF8 }
} catch {}

if (-not (Test-Path $ProgressFile)) {
    "# Ralph Progress Log" | Out-File $ProgressFile -Encoding UTF8
    "Started: $(Get-Date)" | Out-File $ProgressFile -Append -Encoding UTF8
    "---"                  | Out-File $ProgressFile -Append -Encoding UTF8
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Ralph - Auto AI Loop (Codex)" -ForegroundColor Cyan
Write-Host "  Project : $ProjectDir" -ForegroundColor Cyan
Write-Host "  MaxIter : $MaxIterations" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

for ($i = 1; $i -le $MaxIterations; $i++) {
    Write-Host ""
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  Iteration $i / $MaxIterations  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan

    try {
        $prdData = Get-Content $PrdFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Host "ERROR: Failed to read prd.json: $_" -ForegroundColor Red
        exit 1
    }

    $incompleteStories = @($prdData.userStories | Where-Object { $_.passes -eq $false })

    if ($incompleteStories.Count -eq 0) {
        Write-Host ""
        Write-Host "All tasks complete!" -ForegroundColor Green
        exit 0
    }

    $totalStories = $prdData.userStories.Count
    $doneStories  = $totalStories - $incompleteStories.Count
    $current      = $incompleteStories | Sort-Object priority | Select-Object -First 1

    Write-Host "[Progress] $doneStories / $totalStories done" -ForegroundColor Yellow
    Write-Host "[Task]     $($current.id): $($current.title)" -ForegroundColor White
    Write-Host ""

    $promptContent   = Get-Content $PromptFile   -Raw -Encoding UTF8
    $prdContent      = Get-Content $PrdFile       -Raw -Encoding UTF8
    $progressContent = if (Test-Path $ProgressFile) { Get-Content $ProgressFile -Raw -Encoding UTF8 } else { "(no history)" }

    $fullPrompt = @"
$promptContent

---
## Full PRD (prd.json)

$prdContent

---
## Progress History (progress.txt)

$progressContent

---
## Instruction

Complete the user story with the smallest priority number where passes=false.
After finishing, set that story's passes to true and save prd.json.
If ALL stories are passes=true, output: <promise>COMPLETE</promise>
"@

    $tempFile = [System.IO.Path]::GetTempFileName() + ".md"
    [System.IO.File]::WriteAllText($tempFile, $fullPrompt, [System.Text.Encoding]::UTF8)

    Write-Host "[Running] Calling Codex..." -ForegroundColor DarkCyan
    Write-Host ""

    $outputLines = @()
    try {
        $outputLines = Get-Content $tempFile -Raw | & codex exec `
            --dangerously-bypass-approvals-and-sandbox `
            -C $ProjectDir `
            2>&1
        $outputLines | ForEach-Object { Write-Host $_ }
    } catch {
        Write-Host "[Warning] Codex error: $_" -ForegroundColor Yellow
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }

    $outputStr = ($outputLines -join "`n")
    if ($outputStr -match "<promise>COMPLETE</promise>") {
        Write-Host ""
        Write-Host "Ralph completed all tasks at iteration $i!" -ForegroundColor Green
        exit 0
    }

    Write-Host ""
    Write-Host "Iteration $i done. Waiting 3s..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "WARNING: Reached max iterations ($MaxIterations). Tasks may be incomplete." -ForegroundColor Yellow
Write-Host "Check progress.txt or increase -MaxIterations and re-run." -ForegroundColor Yellow
exit 1
