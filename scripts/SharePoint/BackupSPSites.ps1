$snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
if($snapin -eq $null){
	Add-PSSnapin Microsoft.SharePoint.Powershell 
}

$backupPath = "Z:\SharePoint Backup\datfiles";

$err=$NULL
$site=""
$errorMessage = ""

Get-SPWebApplication | foreach {
   $readonly = Get-SPSite -Filter {$_.Lockstate -eq "ReadOnly"}    
   $noaccess = Get-SPSite -Filter {$_.Lockstate -eq "NoAccess"}
   $noadditions = Get-SPSite -Filter {$_.Lockstate -eq "NoAdditions"}

   $_ | Get-SPSite -Limit ALL | ForEach-Object {
	   try 
	   {
			Write-Host "Backing up site "+ $_.Url +"..." -NoNewline
			$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
			$url=$_.URL
			if($url.StartsWith("https")){
				$url = $url.Replace("https://", "")
			}else{
				$url = $url.Replace("http://", "")
			}
			$url = $url.Replace("/", ".") 		
			$FilePath = [System.IO.Path]::Combine($backupPath, $url.Replace("/", ".").Replace(":","-") + "-$timestamp.bak")
			$site = $_.Url
            
                    
			Set-SPSite -Identity $_.url -Lockstate "ReadOnly"
			Backup-SPSite -Identity $_.Url -Path $FilePath -ErrorVariable err -ErrorAction SilentlyContinue
			Set-SPSite -Identity $_.url -Lockstate "Unlock"
		            
            if(-not $?) {
				$errorMessage += "failed to backup site $site reason: $err`n"
				Write-Host "failed" -ForegroundColor red
			} else {
				Write-Host "done" -ForegroundColor yellow
			}
            
		} catch {
			$errorMessage += "failed to backup site $site reason $_`n"
		}
    }
    
    if($readonly){
        foreach ($site in $readonly){
            Set-SPSite -Identity $site -Lockstate "ReadOnly"
        }
    }
    if($noaccess){
        foreach ($site in $noaccess){
            Set-SPSite -Identity $site -Lockstate "NoAccess"
        }
    }
    if($noadditions){
        foreach ($site in $noadditions){
            Set-SPSite -Identity $site -Lockstate "NoAdditions"
        }
    }
}


if($errorMessage -ine  "") {
    $emailFrom = "helpdesk@vbl.ch"
    $emailTo = "helpdesk@vbl.ch"
    $subject = "Backup failed"
    $body = "Errors while backing up sites:`n$errorMessage"
    $smtpServer = "mail.vbl.ch"
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $smtp.Send($emailFrom, $emailTo, $subject, $body)
}