<#
$Metadata = @{
	Title = "Update PowerShell Profile Event Log"
	Filename = "Update-PPEventLog.ps1"
	Description = ""
	Tags = "powershell, profile, function, update, event, log"
	Project = ""
	Author = "Janik von Rotz"
	AuthorContact = "http://janikvonrotz.ch"
	CreateDate = "2013-10-22"
	LastEditDate = "2013-10-22"
	Version = "1.0.0"
	License = @'
This work is licensed under the Creative Commons Attribution-ShareAlike 3.0 Switzerland License.
To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/3.0/ch/ or 
send a letter to Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.
'@
}
#>


function Write-PPEventLog{

<#
.SYNOPSIS
	Updates the windows evenlogs based on the config files in the PowerShell Profile config folder.

.DESCRIPTION
	Updates the windows evenlogs based on the config files in the PowerShell Profile config folder.

.EXAMPLE
	PS C:\> Update-PPEventLog
#>

	param(
	)
	
	#--------------------------------------------------#
	# main
	#--------------------------------------------------#
	Get-PPConfiguration $PSconfigs.EventLog.Filter | %{$_.Content.EventLog} | %{
	
		$EventLog = Get-WmiObject win32_nteventlogfile -filter "filename='$($PSlogs.EventLogName)'"
		if(-not ($EventLog)){
			
			Write-Host "Create event log: $($PSlogs.EventLogName)"
			New-EventLog -LogName $PSlogs.EventLogName -Source $PSlogs.EventLogSources -ErrorAction SilentlyContinue
			
		}else{
			#[System.Diagnostics.EventLog]::CreateEventSource(“MySource”, "Application")
		}
	}
}