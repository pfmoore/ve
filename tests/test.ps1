# Very simple tests, just run various scenarios.
#
# Maybe at some stage investigate "real" testing packages for Powershell

$info_script = (Resolve-Path (Join-Path $PSScriptRoot python_info.py)).Path

ve -temp { python $info_script }
ve -temp -CreateFlags "--no-setuptools" { python -c "import sys, os; print(os.listdir(os.path.dirname(sys.executable)))" }
ve -temp -Python 2.7 { python $info_script }
ve -path ./foo -Make { python $info_script }
if (!(Test-Path foo)) { Write-Host -Fore Red "Directory foo wasn't created" }
ve -path ./foo { python $info_script }
ve -path ./foo -Remove { python $info_script }
if (Test-Path foo) { Write-Host -Fore Red "Directory foo wasn't removed" }
ve bar -Make { python $info_script }
if (!(Test-Path ~/.virtualenvs/bar)) { Write-Host -Fore Red "Directory bar wasn't created" }
ve bar { python $info_script }
ve bar -Remove { python $info_script }
if (Test-Path ~/.virtualenvs/bar) { Write-Host -Fore Red "Directory bar wasn't removed" }
