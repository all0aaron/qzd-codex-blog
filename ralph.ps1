# Ralph for Windows - Codex CLI 版本
# 用法: .\ralph.ps1 [-MaxIterations 20] [-ProjectDir "D:\你的项目"]
# 作用: 循环调用 Codex 自动完成 prd.json 中的所有任务

param(
    [int]$MaxIterations = 10,
    [string]$ProjectDir = ""
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PrdFile = Join-Path $ScriptDir "prd.json"
$ProgressFile = Join-Path $ScriptDir "progress.txt"
$PromptFile = Join-Path $ScriptDir "CODEX.md"
$LastBranchFile = Join-Path $ScriptDir ".last-branch"
$ArchiveDir = Join-Path $ScriptDir "archive"

# 如果没有指定项目目录，使用当前目录
if ([string]::IsNullOrEmpty($ProjectDir)) {
    $ProjectDir = (Get-Location).Path
}

# 检查必要文件
if (-not (Test-Path $PrdFile)) {
    Write-Host "[错误] 找不到 prd.json，请先创建任务清单！" -ForegroundColor Red
    Write-Host "参考格式：prd.json.example" -ForegroundColor Yellow
    exit 1
}
if (-not (Test-Path $PromptFile)) {
    Write-Host "[错误] 找不到 CODEX.md 提示词文件！" -ForegroundColor Red
    exit 1
}

# 检查 codex 是否可用
$codexCheck = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codexCheck) {
    Write-Host "[错误] 未找到 codex 命令，请确认已安装 Codex CLI！" -ForegroundColor Red
    exit 1
}

# 归档上一次运行（如果分支变了）
try {
    $prdData = Get-Content $PrdFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $currentBranch = $prdData.branchName
    
    if ((Test-Path $LastBranchFile) -and $currentBranch) {
        $lastBranch = Get-Content $LastBranchFile -Encoding UTF8
        if ($lastBranch -and $lastBranch -ne $currentBranch) {
            $date = Get-Date -Format "yyyy-MM-dd"
            $folderName = $lastBranch -replace "^ralph/", ""
            $archiveFolder = Join-Path $ArchiveDir "$date-$folderName"
            
            Write-Host "[归档] 上次运行: $lastBranch" -ForegroundColor DarkGray
            New-Item -ItemType Directory -Force -Path $archiveFolder | Out-Null
            if (Test-Path $PrdFile) { Copy-Item $PrdFile $archiveFolder }
            if (Test-Path $ProgressFile) { Copy-Item $ProgressFile $archiveFolder }
            
            "# Ralph Progress Log" | Out-File $ProgressFile -Encoding UTF8
            "Started: $(Get-Date)" | Out-File $ProgressFile -Append -Encoding UTF8
            "---" | Out-File $ProgressFile -Append -Encoding UTF8
        }
    }
    if ($currentBranch) { $currentBranch | Out-File $LastBranchFile -Encoding UTF8 }
} catch {}

# 初始化进度文件
if (-not (Test-Path $ProgressFile)) {
    "# Ralph Progress Log" | Out-File $ProgressFile -Encoding UTF8
    "Started: $(Get-Date)" | Out-File $ProgressFile -Append -Encoding UTF8
    "---" | Out-File $ProgressFile -Append -Encoding UTF8
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Ralph - 自主 AI 任务循环 (Codex版)       ║" -ForegroundColor Cyan
Write-Host "║  项目目录: $ProjectDir" -ForegroundColor Cyan
Write-Host "║  最大迭代: $MaxIterations 次                                ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 读取 API 配置（从 ralph 目录的 .env 文件，可选）
$envFile = Join-Path $ScriptDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
    Write-Host "[配置] 已加载 .env 环境变量" -ForegroundColor DarkGray
}

for ($i = 1; $i -le $MaxIterations; $i++) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  第 $i / $MaxIterations 次迭代  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    # 重新读取 prd.json（每次迭代后可能已更新）
    try {
        $prdData = Get-Content $PrdFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Host "[错误] 读取 prd.json 失败: $_" -ForegroundColor Red
        exit 1
    }
    
    # 检查是否还有未完成的任务
    $incompleteStories = $prdData.userStories | Where-Object { $_.passes -eq $false }
    
    if (-not $incompleteStories -or $incompleteStories.Count -eq 0) {
        Write-Host ""
        Write-Host "✅ 所有任务已完成！" -ForegroundColor Green
        Write-Host "完成于第 $i 次迭代（共 $MaxIterations 次）" -ForegroundColor Green
        exit 0
    }
    
    # 显示当前任务进度
    $totalStories = $prdData.userStories.Count
    $doneStories = $totalStories - $incompleteStories.Count
    $currentStory = $incompleteStories | Sort-Object priority | Select-Object -First 1
    
    Write-Host "[进度] $doneStories / $totalStories 个任务已完成" -ForegroundColor Yellow
    Write-Host "[任务] $($currentStory.id): $($currentStory.title)" -ForegroundColor White
    Write-Host ""
    
    # 读取提示词模板和进度文件
    $promptContent = Get-Content $PromptFile -Raw -Encoding UTF8
    $prdContent = Get-Content $PrdFile -Raw -Encoding UTF8
    $progressContent = if (Test-Path $ProgressFile) { Get-Content $ProgressFile -Raw -Encoding UTF8 } else { "（无历史记录）" }
    
    # 构建完整提示词
    $fullPrompt = @"
$promptContent

---
## 当前 PRD 完整内容（prd.json）

$prdContent

---
## 历史进度记录（progress.txt）

$progressContent

---
## 本次任务说明

请完成 prd.json 中 priority 最小（最高优先级）且 passes=false 的那个用户故事。
完成后务必将该故事的 passes 改为 true 并更新 prd.json 文件。
如果所有故事都是 passes=true，请在回复末尾输出：<promise>COMPLETE</promise>
"@
    
    # 写入临时提示词文件
    $tempFile = [System.IO.Path]::GetTempFileName()
    $fullPrompt | Out-File $tempFile -Encoding UTF8
    
    Write-Host "[运行] 正在调用 Codex..." -ForegroundColor DarkCyan
    Write-Host ""
    
    # 执行 codex exec（非交互模式）
    $outputLines = @()
    try {
        $output = Get-Content $tempFile -Raw | & codex exec `
            --dangerously-bypass-approvals-and-sandbox `
            -C $ProjectDir `
            2>&1
        $outputLines = $output
        $output | ForEach-Object { Write-Host $_ }
    } catch {
        Write-Host "[警告] Codex 执行出错: $_" -ForegroundColor Yellow
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
    
    # 检查是否有完成信号
    $outputStr = ($outputLines -join "`n")
    if ($outputStr -match "<promise>COMPLETE</promise>") {
        Write-Host ""
        Write-Host "🎉 Ralph 完成所有任务！" -ForegroundColor Green
        Write-Host "完成于第 $i 次迭代" -ForegroundColor Green
        exit 0
    }
    
    Write-Host ""
    Write-Host "第 $i 次迭代完成，等待 3 秒后继续..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "⚠️  Ralph 已达到最大迭代次数 ($MaxIterations)，仍有未完成任务。" -ForegroundColor Yellow
Write-Host "请检查 progress.txt 查看状态，或增加 -MaxIterations 参数后重新运行。" -ForegroundColor Yellow
exit 1
