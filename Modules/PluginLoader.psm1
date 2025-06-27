function Import-Plugins {
    param([string]$PluginsPath)
    if (Test-Path $PluginsPath) {
        Get-ChildItem $PluginsPath -Filter '*.psm1' | 
            ForEach-Object { Import-Module $_.FullName -Force }
    }
}
Export-ModuleMember -Function Import-Plugins
