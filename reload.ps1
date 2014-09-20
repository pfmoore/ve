remove-module -ea 0 venv
del -ea 0 -rec ~/WindowsPowerShell/Modules/Venv
copy -rec Venv ~/WindowsPowerShell/Modules/Venv
import-module venv
