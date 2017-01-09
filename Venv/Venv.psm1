<#
.SYNOPSIS
Runs commands with a Python virtualenv active

.DESCRIPTION
The ve command activates a Python virtualenv and runs the specified
script block with that virtualenv activates (so that the python interpreter
and any installed commands in that virtualenv are available on the user's
PATH).

The ve command sets the environment variable $env:VIRTUAL_ENV to the path
of the virtualenv, exactly as the standard "activate" script does.

The powershell prompt is not altered. If you want to display the active
virtualenv in your powershell prompt, you should create a custom prompt
using the $env:VIRTUAL_ENV variable.

.PARAMETER VE
The name of the virtualenv to activate. By default (unless the -Path
parameter is used) all virtualenvs are assumed to be located in the user's
~/.virtualenvs directory.

.PARAMETER Path
The full path to the virtualenv to activate. This must be specified
explicitly to use a virtualenv in an arbitrary location.

.PARAMETER ScriptBlock
The script block to execute with the virtualenv active. If no script block
is specfied, a nested prompt will be opened in the current PowerShell
session. To exit the nested prompt, use "exit" or $host.ExitNestedPrompt()

.PARAMETER Make
If -Make is specified, the virtualenv will be created before executing the
script block. It is an error to specify -Make when the virtualenv already
exists.

.PARAMETER Remove
If -Remove is specified, the virtualenv will be deleted when the script
block completes.

.PARAMETER Temp
Using -Temp creates a temporary virtualenv. This is equivalent to specifying
-Make and -Remove together. No name is needed, a random name is used.

.PARAMETER CWD
The working directory in which to execute the script block. If not
specified, the current working directory will be used.

.EXAMPLE
PS C:\> ve foo { python -V }
Runs the python command in virtualenv ~/.virtualenvs/foo

.EXAMPLE
PS C:\> ve -path C:\bar { python -V }
Runs the python command in virtualenv C:\bar

.EXAMPLE
PS C:\> ve -path bar { pip list }
Runs the pip command in virtualenv .\bar

.EXAMPLE
PS C:\> ve -make foo { powershell }
Creates a new virtualenv in ~/.virtualenvs called foo, and runs a new
instance of powershell with that environment active.

.EXAMPLE
PS C:\> ve foo
Opens a nested prompt with the virtualenv foo active. When the nested prompt
is exited, the original environment will be restored.

.EXAMPLE
PS C:\> ve -Temp foo
Creates a temporary virtualenv named foo, and opens up a nested prompt with
that virtualenv active. When the nested prompt is closed, the virtualenv will
be deleted.

.NOTES
The ve command is a port of the Python vex command, see https://pypi.python.org/pypi/vex.
All credit for the design should be given to the vex project.
#>
function ve {
    [CmdletBinding(DefaultParameterSetName="ByName")]
    Param (

      [Parameter(Position=0, Mandatory=$true, ParameterSetName="ByName")]
      [Parameter(Position=0, Mandatory=$true, ParameterSetName="ByNewName")]
      [String]
      $VE,

      [Parameter(Mandatory=$true, ParameterSetName="ByPath")]
      [Parameter(Mandatory=$true, ParameterSetName="ByNewPath")]
      [String]
      $Path,

      [Parameter(Mandatory=$true, ParameterSetName="Temp")]
      [Switch]$Temp,

      [Parameter(Position=1)]
      [ScriptBlock]$ScriptBlock,

      [Parameter(Mandatory=$true, ParameterSetName="ByNewName")]
      [Parameter(Mandatory=$true, ParameterSetName="ByNewPath")]
      [Switch]$Make,

      [Parameter(ParameterSetName="ByNewName")]
      [Parameter(ParameterSetName="ByNewPath")]
      [Parameter(ParameterSetName="Temp")]
      [Alias("P")]
      [String]$Python,
      [Parameter(ParameterSetName="ByNewName")]
      [Parameter(ParameterSetName="ByNewPath")]
      [Parameter(ParameterSetName="Temp")]
      [String[]]$CreateFlags,

      [Parameter(ParameterSetName="ByName")]
      [Parameter(ParameterSetName="ByPath")]
      [Parameter(ParameterSetName="ByNewName")]
      [Parameter(ParameterSetName="ByNewPath")]
      [Switch]$Remove,

      [String]$CWD
    )

    $venvroot = Join-Path (Resolve-Path ~).Path .virtualenvs

    switch ($PSCmdlet.ParameterSetName) {
        ByName {
            $Path = (Join-Path $venvroot $VE)
            if (! (Test-Path -PathType Container $Path)) {
                throw "The virtualenv $VE does not exist"
            }
        }
        ByPath {
            if (! (Test-Path -PathType Container $Path)) {
                throw "The virtualenv $Path does not exist"
            }
        }
        ByNewName {
            # If $venvroot doesn't exist, create it
            if (! (Test-Path -PathType Container $venvroot)) {
                $null = New-Item -Type Directory $venvroot
            }
            $Path = (Join-Path $venvroot $VE)
            if (Test-Path -PathType Container $Path) {
                throw "The virtualenv $VE (at $Path) already exists"
            }
        }
        ByNewPath {
            if (Test-Path -PathType Container $Path) {
                throw "The virtualenv ($Path) already exists"
            }
        }
        Temp {
            $tmp = [System.IO.Path]::GetTempPath()
            $Path = (
                1..100 |
                ForEach-Object { Join-Path $tmp ("VE-{0}" -f $_) } |
                Where-Object { ! (Test-Path $_) } |
                Select-Object -First 1
            )
        }
    }

    # A temporary VE is made at start and removed at end
    if ($Temp) {
        $Make = $true
        $Remove = $true
    }

    if ($Make) {
        # Make the virtualenv
        # We build the command as a string and use Invoke-Expression
        # because we have a variable set of arguments.
        # The parts are single-quoted to preserve the variable references
        # till the last minute, so that Powershell will auto-quote for us.
        if ($Python -like "2*") {
            # Python 2 doesn't have venv, so we need virtualenv available
            $cmd = 'virtualenv -p $Python $Path'
        } elseif ($Python) {
            $cmd = 'py -$Python -m venv $Path'
        } else {
            $cmd = 'py -m venv $Path'
        }
        if ($CreateFlags) {
            $cmd += ' @CreateFlags'
        }
        Invoke-Expression $cmd
    }

    # Ensure that we have an absolute pathname,
    # and identify the Scripts directory and the location of Python
    $Path = (Resolve-Path $Path).Path
    $scripts = (Join-Path $Path Scripts)
    $python = (Join-Path $scripts python.exe)

    if (! (Test-Path -PathType Leaf $python)) {
        throw "Virtualenv $Path is corrupt (python executable does not exist)"
    }

    # Save the environment, activate the virtualenv, and run the script block
    $oldpath = $env:PATH
    $oldvenv = $env:VIRTUAL_ENV
    if ($CWD) {
        Push-Location -StackName VirtualenvLocations $CWD
    }
    try {
        $env:PATH = $scripts + ';' + $env:PATH
        $env:VIRTUAL_ENV = $Path
        if ($ScriptBlock) {
            & $ScriptBlock
        } else {
            $host.EnterNestedPrompt()
        }
    }
    finally {
        if ($CWD) {
            Pop-Location -StackName VirtualenvLocations 
        }
        $env:PATH = $oldpath
        $env:VIRTUAL_ENV = $oldenv
    }

    # Remove the virtualenv if requested
    if ($Remove) {
        Remove-Item -Recurse -Force $Path
    }
}
