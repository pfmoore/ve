#New-Venv [name] (no name => .venv)
#Enter-Venv [name] (no name => .venv) # Run a shell in the given venv.
#Enter-TempVenv
#Get-Venv # List venvs
#Remove-Venv # Delete a venv
#Reset-Venv # ?
#Use-Venv { scriptblock }

$env_location = Resolve-Path ~/.virtualenvs

function Resolve-VenvName {
    [CmdletBinding()]
    param([String]$env)

    if (!$env) {
        $env = ".venv"
    } else {
        $try = Join-Path $env_location $env
        if (Test-Path $try -PathType Container) {
            $env = $try
        }
    }

    # Returns PathInfo. Could just reuse $env and return string
    $envpath = Resolve-Path -ErrorAction Ignore $env
    if ($null -eq $envpath) {
        Write-Error "Invalid environment: $env"
        return $null
    }

    $python = Join-Path $envpath "Scripts" "python.exe"
    if (!(Test-Path $python -PathType Leaf)) {
        Write-Error "$env does not contain a Python interpreter"
        return $null
    }

    $cfg = Join-Path $envpath "pyvenv.cfg"
    if (!(Test-Path $cfg -PathType Leaf)) {
        Write-Error "$env does not contain pyvenv.cfg"
        return $null
    }

    # TODO: Move the fllowing to a separate function

    # Double the backslashes as ConvertFrom-StringData treats them
    # as escape characters, but pyvenv.cfg uses raw backslashes in paths
    $raw_config = ((Get-Content $cfg) -Replace '\\', '\\' | ConvertFrom-StringData)
    $TextInfo = (Get-Culture).TextInfo
    $config = @{}
    foreach ($k in $raw_config.keys) {
        # Format keys in Powershell InitCapsFormat
        $newkey = ($TextInfo.ToTitleCase($k) -replace '[-_]','');
        $config[$newkey] = $raw_config.$k
    }

    # Virtualenv sets VersionInfo but not Version
    if ($null -eq $config.Version) {
        $config.Version = ($config.VersionInfo -split '\.')[0..2] -join '.'
    }

    [PSCustomObject]$config
}


function is_pyarg ([String]$arg) {
    $arg -match "^-[23](.\d+)?(-(32|64))?$"
}

# pip install (fn_that_generates_requirements)
# pip install $array

function New-Venv ([String]$Name, [Switch]$NoActivate) {
    # If $Name isn't a path
    $Name = Join-Path $env_location $Name
    # TODO: Have a local copy of virtualenv?
    # TODO: Support -Python pyver
    # TODO: Support -Install r1,r2,...
    # TODO: Support -Requirements reqfile
    virtualenv $Name
    if (!$NoActivate) {
        Use-Venv $Name
    }
}

function Use-Venv ($Name, $ScriptBlock) {
    # If we're only passed a scriptblock, fix the arguments up
    if (($null -eq $ScriptBlock) -and ($Name -is [ScriptBlock])) {
        $ScriptBlock = $Name
        $Name = $null
    }
    $env = Resolve-VenvName $Name

    $scripts = Join-Path $env "Scripts"
    if ($ScriptBlock) {
        # Save the environment, activate the virtualenv, and run the script block
        $oldpath = $env:PATH
        $oldvenv = $env:VIRTUAL_ENV
        try {
            $env:PATH = $scripts + ';' + $env:PATH
            $env:VIRTUAL_ENV = $Name
            & $ScriptBlock
        }
        finally {
            $env:PATH = $oldpath
            $env:VIRTUAL_ENV = $oldenv
        }
    } else {
        & (Get-Process -Id $pid).Path -NoExit {
            param([string]$env)
            Write-Host -ForegroundColor Cyan "Launching nested prompt in virtual environment. Type 'exit' to return."
            & (Join-Path $env "Scripts" "activate.ps1")
        } -args $env
    }
}

function New-TempVenv {
    $Name = Join-Path $env_location (New-Guid)
    virtualenv $Name
    & (Get-Process -Id $pid).Path -NoExit {
        Write-Host -ForegroundColor Cyan "Launching nested prompt in virtual environment. Type 'exit' to return."
        Write-Host -ForegroundColor Cyan "This is a temporary environment and will be deleted on exit."
        $name = $args[0]
        & (Join-Path $name "Scripts" "activate.ps1")
        Register-EngineEvent PowerShell.Exiting { Remove-Item -Recurse $name } | Out-Null
    } -args $name
}

function ve_select ([String]$pattern) {
    if ($pattern -eq "") {
        if ($env:VIRTUAL_ENV) {
            $env:VIRTUAL_ENV
        } else {
            (Resolve-Path -ErrorAction Ignore "./.venv").Path
        }
    } elseif ((Split-Path -Leaf $pattern) -eq $pattern) {
        # If just a leaf is given, assume the venv directory
        (Resolve-Path -ErrorAction Ignore (Join-Path $env_location $pattern)).Path
    } else {
        (Resolve-Path $pattern).Path
    }
}

function Get-Venv {
    Get-ChildItem $env_location | Where-Object { Test-Path (Join-Path $_ "Scripts" "python.exe") -PathType Leaf }
}

function veCommand ([string]$cmd) {
    switch ($cmd) {
        "ls" { Get-Venv $args }
        "path" { Resolve-VenvName $args }
        "new" { New-Venv $args }
        "temp" { New-TempVenv $args }
        "run" { Use-Venv $args }
    }
}
