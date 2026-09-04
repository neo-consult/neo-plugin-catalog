[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')]
    [string]$PluginSlug,

    [Parameter(Mandatory)]
    [string]$PluginName,

    [Parameter(Mandatory)]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [string]$MainPluginFile,

    [string]$Description = '',
    [string]$Requires = '6.0',
    [string]$RequiresPhp = '8.1',
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'

function Get-GhExe {
    $candidates = @(
        (Get-Command gh.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        (Get-Command gh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
    ) | Where-Object { $_ }
    if ($candidates) { return $candidates[0] }

    $portableRoot = Join-Path $env:LOCALAPPDATA 'Programs\gh-cli'
    $portable = Get-ChildItem -Path $portableRoot -Recurse -Filter gh.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($portable) { return $portable }

    throw 'GitHub CLI (gh) wurde nicht gefunden. Installiere sie oder füge sie dem PATH hinzu.'
}

function Invoke-Gh {
    param([string[]]$Arguments)
    & $script:GhExe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($Arguments -join ' ') ist fehlgeschlagen."
    }
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

$catalogRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$catalogFile = Join-Path $catalogRoot 'plugins.json'
$workflowTemplate = Join-Path $catalogRoot 'release-workflow.yml'
$source = (Resolve-Path $SourcePath).Path
$mainFile = Join-Path $source $MainPluginFile
$repository = "neo-consult/$PluginSlug"

if (-not (Test-Path -LiteralPath $mainFile -PathType Leaf)) {
    throw "Die Plugin-Hauptdatei wurde nicht gefunden: $mainFile"
}
if (-not (Test-Path -LiteralPath $catalogFile -PathType Leaf) -or -not (Test-Path -LiteralPath $workflowTemplate -PathType Leaf)) {
    throw 'Das Skript muss aus einem vollständigen Checkout von neo-plugin-catalog ausgeführt werden.'
}

$header = Get-Content -LiteralPath $mainFile -Raw
$versionMatch = [regex]::Match($header, '(?m)^\s*\*\s*Version:\s*([^\s]+)')
if (-not $versionMatch.Success) {
    throw 'Im Plugin-Header fehlt eine Version.'
}
$version = $versionMatch.Groups[1].Value
if ($version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
    throw "Die Version '$version' muss das Format 1.2.3 verwenden."
}
$updateUriMatch = [regex]::Match($header, '(?m)^\s*\*\s*Update URI:\s*(.+?)\s*$')
$expectedUpdateUri = "https://github.com/$repository"
if (-not $updateUriMatch.Success -or $updateUriMatch.Groups[1].Value.TrimEnd('/') -ne $expectedUpdateUri) {
    throw "Die Hauptdatei braucht den Header 'Update URI: $expectedUpdateUri'."
}

$catalog = Get-Content -LiteralPath $catalogFile -Raw | ConvertFrom-Json
if ($catalog.plugins | Where-Object { $_.slug -eq $PluginSlug }) {
    throw "Der Katalog enthält bereits '$PluginSlug'."
}

$script:GhExe = Get-GhExe
Invoke-Gh @('auth', 'status')

if (-not $Publish) {
    Write-Host "Prüfung erfolgreich. Mit -Publish wird $repository erstellt, als Entwurf in den Katalog eingetragen und v$version veröffentlicht."
    exit 0
}

& $script:GhExe repo view $repository 2>$null
if ($LASTEXITCODE -eq 0) {
    throw "Das Repository $repository existiert bereits."
}

$secureToken = Read-Host 'Fine-grained Token für neo-plugin-catalog (Contents: Read and write)' -AsSecureString
$tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
try {
    $catalogToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)
    if ([string]::IsNullOrWhiteSpace($catalogToken)) { throw 'Es wurde kein Token eingegeben.' }

    $stageRoot = Join-Path $env:TEMP ("neo-plugin-onboarding-" + [guid]::NewGuid().ToString('N'))
    $repoPath = Join-Path $stageRoot $PluginSlug
    New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $repoPath -Recurse -Force
    Write-Utf8File -Path (Join-Path $repoPath '.gitignore') -Content @"
*.zip
*.backup
.phpunit.result.cache
node_modules/
"@
    $workflowPath = Join-Path $repoPath '.github\workflows'
    New-Item -ItemType Directory -Path $workflowPath -Force | Out-Null
    Copy-Item -LiteralPath $workflowTemplate -Destination (Join-Path $workflowPath 'release.yml') -Force

    Invoke-Gh @('repo', 'create', $repository, '--public', '--disable-wiki', '--description', $PluginName)
    Push-Location $repoPath
    try {
        git init -b main
        git add -A
        git reset -- .github 2>$null
        git add .github
        git commit -m 'Initial plugin release infrastructure'
        git remote add origin "https://github.com/$repository.git"
        git push -u origin main
    } finally {
        Pop-Location
    }

    $catalog.plugins += [pscustomobject][ordered]@{
        slug = $PluginSlug
        plugin_file = "$PluginSlug/$MainPluginFile"
        name = $PluginName
        version = $version
        package = "https://github.com/$repository/releases/download/v$version/$PluginSlug.zip"
        sha256 = ('0' * 64)
        published = $false
        homepage = "https://github.com/$repository"
        requires = $Requires
        requires_php = $RequiresPhp
        description = $Description
    }
    Write-Utf8File -Path $catalogFile -Content (($catalog | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
    Push-Location $catalogRoot
    try {
        git add plugins.json
        git commit -m "Add $PluginSlug as release draft"
        git push origin main
    } finally {
        Pop-Location
    }

    Invoke-Gh @('secret', 'set', 'NEO_CATALOG_TOKEN', '--repo', $repository, '--body', $catalogToken)
    Push-Location $repoPath
    try {
        git tag -a "v$version" -m "Release v$version"
        git push origin "v$version"
    } finally {
        Pop-Location
    }

    Write-Host "Release gestartet: https://github.com/$repository/actions"
    Write-Host 'Der Entwurf wird nach erfolgreichem Workflow automatisch veröffentlicht.'
} finally {
    if ($tokenPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
    }
}
