function ve_locations {
    if (Test-Path env:VENV_PATH) {
        $env:VENV_PATH -split ';'
    } else {
        (Resolve-Path "~/.virtualenvs").Path
    }
}

ve_search ([String]$Pattern) {
    Split-Path -Parent (Resolve-Path (Join-Path (ve_locations) "*" "pyvenv.cfg")).Path
}

function ve_data ([String]$venv) {
    # Get a PS object representing the env
    $cfg = Join-Path $venv "pyvenv.cfg"
    if (!(Test-Path $cfg -PathType Leaf)) {
        Write-Error "$env does not contain pyvenv.cfg"
        return $null
    }

    # Double the backslashes as ConvertFrom-StringData treats them
    # as escape characters, but pyvenv.cfg uses raw backslashes in paths
    # The first string is a regex, so \\ matches \. The second is a literal,
    # so the overall effect is to replace \ with \\...
    $raw_config = ((Get-Content $cfg) -Replace '\\', '\\' | ConvertFrom-StringData)
    $TextInfo = (Get-Culture).TextInfo
    $config = @{}
    foreach ($k in $raw_config.keys) {
        # Format keys in Powershell InitCapsFormat rather than dash-separated
        $newkey = ($TextInfo.ToTitleCase($k) -replace '[-_]','');
        $config[$newkey] = $raw_config.$k
    }

    # Virtualenv sets VersionInfo but not Version
    if ($null -eq $config.Version) {
        $config.Version = ($config.VersionInfo -split '\.')[0..2] -join '.'
    }

    [PSCustomObject]$config
}

function ve_installed([String]$venv) {
    $distinfo = Join-Path $venv "Lib" "site-packages" "*.dist-info"
    Get-ChildItem -ErrorAction SilentlyContinue $distinfo |
        ForEach-Object {
            $base = $_.Name -replace '.dist-info$', ''
            $parts = $base -split '-'
            [PSCustomObject]@{ Name=$parts[0]; Version=$parts[1] }
        }
}

function ve_python([String]$venv) {
    $python = Join-Path $venv "Scripts" "python.exe"
    if (Test-Path $python -PathType Leaf) {
        $python
    } else {
        Write-Error "Virtual environment has no Python executable"
    }
}

function ve_pip([String]$venv) {
    $python = Join-Path $venv "Scripts" "pip.exe"
    if (Test-Path $python -PathType Leaf) {
        $python
    } else {
        Write-Error "Pip is not installed in this virtual environment"
    }
}