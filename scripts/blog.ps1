$ErrorActionPreference = "Stop"

$AllArgs = @($args)
$Command = "help"
if ($AllArgs.Count -gt 0) {
    $Command = [string]$AllArgs[0]
}

$Rest = @()
if ($AllArgs.Count -gt 1) {
    $Rest = @($AllArgs[1..($AllArgs.Count - 1)])
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

function Write-Info {
    param([string]$Message)
    Write-Host "[blog] $Message"
}

function Write-Usage {
    Write-Host @"
Mello's Blog helper

Usage:
  .\scripts\blog.ps1 new "文章标题" [--slug slug] [--category 分类] [--tag 标签] [--draft] [--math]
  .\scripts\blog.ps1 dev
  .\scripts\blog.ps1 build
  .\scripts\blog.ps1 publish "提交说明"

Examples:
  .\scripts\blog.ps1 new "信号与系统：卷积复盘" --category "信号与系统" --tag "专业课" --math
  .\scripts\blog.ps1 dev
  .\scripts\blog.ps1 publish "post: add convolution review"
"@
}

function Get-HugoCommand {
    $globalHugo = Get-Command "hugo" -ErrorAction SilentlyContinue
    if ($globalHugo) {
        return $globalHugo.Source
    }

    $localCandidates = @(
        (Join-Path $RepoRoot "work/tools/hugo-0.163.1/hugo.exe"),
        (Join-Path $RepoRoot "tools/hugo/hugo.exe")
    )

    foreach ($candidate in $localCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "Hugo was not found. Install Hugo Extended, or keep the verified local copy at work/tools/hugo-0.163.1/hugo.exe."
}

function ConvertTo-Slug {
    param(
        [string]$Text,
        [string]$FallbackPrefix = "post"
    )

    $slug = $Text.ToLowerInvariant()
    $slug = [regex]::Replace($slug, "[^a-z0-9]+", "-")
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = "$FallbackPrefix-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    }

    return $slug
}

function Escape-YamlDoubleQuoted {
    param([string]$Text)
    return ($Text -replace '\\', '\\' -replace '"', '\"')
}

function Get-OptionValues {
    param(
        [string[]]$InputArgs,
        [string[]]$Names
    )

    $values = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $InputArgs.Count; $i++) {
        if ($Names -contains $InputArgs[$i]) {
            if ($i + 1 -ge $InputArgs.Count) {
                throw "Missing value for option $($InputArgs[$i])."
            }
            $values.Add($InputArgs[$i + 1])
            $i++
        }
    }
    return $values.ToArray()
}

function Test-Flag {
    param(
        [string[]]$InputArgs,
        [string[]]$Names
    )

    foreach ($name in $Names) {
        if ($InputArgs -contains $name) {
            return $true
        }
    }
    return $false
}

function New-BlogPost {
    param([string[]]$InputArgs)

    $titleParts = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $InputArgs.Count; $i++) {
        $arg = $InputArgs[$i]
        if ($arg.StartsWith("--") -or $arg.StartsWith("-")) {
            if (@("--slug", "--category", "-c", "--tag", "-t") -contains $arg) {
                $i++
            }
            continue
        }
        $titleParts.Add($arg)
    }

    $title = ($titleParts -join " ").Trim()
    if ([string]::IsNullOrWhiteSpace($title)) {
        throw 'Missing title. Example: .\scripts\blog.ps1 new "我的新文章"'
    }

    $slugOption = @(Get-OptionValues -InputArgs $InputArgs -Names @("--slug"))
    $categories = @(Get-OptionValues -InputArgs $InputArgs -Names @("--category", "-c"))
    $tags = @(Get-OptionValues -InputArgs $InputArgs -Names @("--tag", "-t"))
    $isDraft = Test-Flag -InputArgs $InputArgs -Names @("--draft")
    $hasMath = Test-Flag -InputArgs $InputArgs -Names @("--math")

    $rawSlug = if ($slugOption.Count -gt 0) { $slugOption[0] } else { $title }
    $slug = ConvertTo-Slug -Text $rawSlug -FallbackPrefix "post"
    $postDir = Join-Path $RepoRoot "content/posts"
    New-Item -ItemType Directory -Path $postDir -Force | Out-Null

    $postPath = Join-Path $postDir "$slug.md"
    $suffix = 2
    while (Test-Path -LiteralPath $postPath) {
        $postPath = Join-Path $postDir "$slug-$suffix.md"
        $suffix++
    }

    $finalSlug = [System.IO.Path]::GetFileNameWithoutExtension($postPath)
    $escapedTitle = Escape-YamlDoubleQuoted $title
    $date = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
    $draftText = if ($isDraft) { "true" } else { "false" }
    $mathText = if ($hasMath) { "true" } else { "false" }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("---")
    $lines.Add("title: `"$escapedTitle`"")
    $lines.Add("date: $date")
    $lines.Add("draft: $draftText")
    $lines.Add("slug: `"$finalSlug`"")
    $lines.Add("description: `"`"")
    $lines.Add("categories:")
    if ($categories.Count -eq 0) {
        $lines.Add("  - 学习记录")
    } else {
        foreach ($category in $categories) {
            $lines.Add("  - $(Escape-YamlDoubleQuoted $category)")
        }
    }
    $lines.Add("tags:")
    if ($tags.Count -eq 0) {
        $lines.Add("  - 随笔")
    } else {
        foreach ($tag in $tags) {
            $lines.Add("  - $(Escape-YamlDoubleQuoted $tag)")
        }
    }
    $lines.Add("math: $mathText")
    $lines.Add("showToc: true")
    $lines.Add("---")
    $lines.Add("")
    $lines.Add("## 背景")
    $lines.Add("")
    $lines.Add("## 记录")
    $lines.Add("")
    $lines.Add("## 小结")

    Set-Content -LiteralPath $postPath -Value $lines -Encoding UTF8
    Write-Info "Created $($postPath.Substring($RepoRoot.Length + 1))"
}

function Invoke-HugoBuild {
    $hugo = Get-HugoCommand
    $cacheDir = Join-Path $RepoRoot "work/hugo_cache"
    Push-Location $RepoRoot
    try {
        & $hugo --gc --minify --cleanDestinationDir --cacheDir $cacheDir
        if ($LASTEXITCODE -ne 0) {
            throw "Hugo build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

function Start-HugoServer {
    $hugo = Get-HugoCommand
    $cacheDir = Join-Path $RepoRoot "work/hugo_cache"
    Push-Location $RepoRoot
    try {
        & $hugo server -D --disableFastRender --cacheDir $cacheDir
    }
    finally {
        Pop-Location
    }
}

function Publish-Blog {
    param([string[]]$InputArgs)

    $message = ($InputArgs -join " ").Trim()
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = "blog: update posts"
    }

    Invoke-HugoBuild

    Push-Location $RepoRoot
    try {
        $changes = git status --porcelain
        if ([string]::IsNullOrWhiteSpace(($changes -join ""))) {
            Write-Info "No changes to publish."
            return
        }

        git add .
        git commit -m $message
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed with exit code $LASTEXITCODE."
        }

        git push
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed with exit code $LASTEXITCODE."
        }

        Write-Info "Published. GitHub Actions will deploy the site automatically."
    }
    finally {
        Pop-Location
    }
}

switch ($Command.ToLowerInvariant()) {
    "new" { New-BlogPost -InputArgs $Rest }
    "dev" { Start-HugoServer }
    "server" { Start-HugoServer }
    "build" { Invoke-HugoBuild }
    "publish" { Publish-Blog -InputArgs $Rest }
    "help" { Write-Usage }
    default {
        Write-Usage
        throw "Unknown command: $Command"
    }
}
