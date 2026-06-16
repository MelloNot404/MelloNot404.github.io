param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot "blog.ps1")
)

$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mellos-blog-test-" + [System.Guid]::NewGuid().ToString("N"))

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "content/posts") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "scripts") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tempRoot "hugo.yaml") -Value 'title: "Test Blog"'
    Copy-Item -LiteralPath $ScriptPath -Destination (Join-Path $tempRoot "scripts/blog.ps1") -Force

    Push-Location $tempRoot
    try {
        & (Join-Path $tempRoot "scripts/blog.ps1") new "测试文章" --slug "test-note" --category "学习记录" --tag "Hugo" --tag "Markdown" --draft
        if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
            throw "blog.ps1 exited with code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }

    $postPath = Join-Path $tempRoot "content/posts/test-note.md"
    Assert-True (Test-Path -LiteralPath $postPath) "Expected post file to be created at content/posts/test-note.md"

    $content = Get-Content -LiteralPath $postPath -Raw
    Assert-True ($content -match 'title: "测试文章"') "Expected generated post to contain the title"
    Assert-True ($content -match 'slug: "test-note"') "Expected generated post to contain the slug"
    Assert-True ($content -match 'draft: true') "Expected generated post to be a draft when --draft is passed"
    Assert-True ($content -match '- 学习记录') "Expected generated post to contain the category"
    Assert-True ($content -match '- Hugo') "Expected generated post to contain the first tag"
    Assert-True ($content -match '- Markdown') "Expected generated post to contain the second tag"

    Write-Host "All blog script tests passed."
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
