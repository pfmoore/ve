function ve-temp {
    [CmdletBinding(DefaultParameterSetName="ByName")]
    Param (
    )

    # Need to expand ~
    $name = Join-Path (Resolve-Path "~/.virtualenvs") (New-Guid)
    virtualenv $name
    & (Get-Process -Id $pid).Path -NoExit {
        Write-Host -ForegroundColor Cyan "Launching nested prompt in virtual environment. Type 'exit' to return."
        $name = $args[0]
        echo (Join-Path $name "Scripts/activate.ps1")
        & (Join-Path $name "Scripts/activate.ps1")
    } -args $name
    Remove-Item -Recurse $name
}

function ve-ls {
    dir (Resolve-Path ~/.virtualenvs)
}

function ve {
    $cmd = $args[0]
    $args = $args[1..$args.Count]
    echo $cmd
    echo $args
    & "ve-$cmd" @args
}
