<#
$Metadata = @{
    Title = "Get SharePoint Object Permissions"
	Filename = "Get-SPObjectPermissions.ps1"
	Description = ""
	Tags = ""powershell, sharepoint, function"
	Project = ""
	Author = "Janik von Rotz"
	AuthorContact = "http://janikvonrotz.ch"
	CreateDate = "2013-07-11"
	LastEditDate = "2013-09-16"
	Version = "4.1.0"
	License = @'
This work is licensed under the Creative Commons Attribution-ShareAlike 3.0 Switzerland License.
To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/3.0/ch/ or 
send a letter to Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.
'@
}
#>

function Get-SPObjectPermissions{

<#

.SYNOPSIS
    Get permissions on SharePoint objects.

.DESCRIPTION
	Get permissions on SharePoint objects.
    
.PARAMETER Url
	Url of the SharePoint website.
    
.PARAMETER IncludeChildItems
	Requires Identity, includes the child items of the specified website.
    
.PARAMETER Recursive
	Requires Identity, includes the every sub item of the specified website.
    
.PARAMETER OnlyLists
	Only report list items.
    
.PARAMETER OnlyWebsites
	Only report website items.

.PARAMETER ByUsers
	Report permissions by user rights.

.EXAMPLE
	PS C:\> Get-SPObjectPermissions -Url "http://sharepoint.vbl.ch/Projekte/SitePages/Homepage.aspx" -IncludeChildItems -Recursive -OnlyLists -OnlyWebsites -ByUsers

#>

	param(
		[Parameter(Mandatory=$false)]
		[string]$Url,
		
		[switch]$IncludeChildItems,

		[switch]$Recursive,
        
        [switch]$OnlyLists,
        
        [switch]$OnlyWebsites,
        
        [switch]$ByUsers
	)
    
    #--------------------------------------------------#
    # modules
    #--------------------------------------------------#
    if ((Get-PSSnapin “Microsoft.SharePoint.PowerShell” -ErrorAction SilentlyContinue) -eq $null) {
        Add-PSSnapin “Microsoft.SharePoint.PowerShell”
    }
    Import-Module ActiveDirectory

    #--------------------------------------------------#
    # functions
    #--------------------------------------------------#
    function Get-SPObjectPermissionMemberType{
    
        param(
            [Parameter(Mandatory=$true)]
            $RoleAssignment
        )
        
        #check if type of member ADGroup, SPGroup, ADUser, User
        if($RoleAssignment.Member.IsDomainGroup){
            $MemberType = "ADGroup"                        
        }elseif(($RoleAssignment.Member.LoginName).StartsWith("SHAREPOINT\")){
            $MemberType = "SPUser"  
        }elseif($RoleAssignment.Member.UserToken -ne $null){
            $MemberType = "ADUser"                                          
        }else{
            $MemberType = "SPGroup"
        }
        
        $MemberType
    }


    function Get-SPObjectPermissionMember{
    
        param(
            [Parameter(Mandatory=$true)]
            $RoleAssignment
        )
        
        $Member =  $RoleAssignment.Member.UserLogin -replace ".*\\",""
        if($Member -eq ""){
            $Member =  $RoleAssignment.Member.LoginName
        }
        
        $Member
    }
    
    
    function Get-SPReportItemByUsers{
    
        param(
            [Parameter(Mandatory=$true)]
            $SPReportItem
        )
        
        if($SPReportItem.MemberType -eq "ADGroup"){
            $ADUsers = Get-ADGroupMember -Identity $SPReportItem.Member -Recursive | Get-ADUser -Properties DisplayName
                
        }elseif($SPPermission.MemberType -eq "ADUser"){
            $ADUsers = Get-ADUser -Identity $SPReportItem.Member
            
        }else{
            $ADUsers = $Null
        }
            
        if($ADUsers){
            foreach($ADUser in $ADUsers){
                
                # reset item         
                $SPReportItemByUsers = $SPReportItem.PsObject.Copy()
            
                $SPReportItemByUsers | Add-Member -MemberType NoteProperty -Name "UserName" -Value $ADUser.Name -Force
                $SPReportItemByUsers | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $ADUser.DisplayName -Force
                $SPReportItemByUsers | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $ADUser.UserPrincipalName -Force
                
                $SPReportItemByUsers
            }
        }
        
    }
    
    function New-ObjectSPReportItem{
        param(
            $Name,
            $Url,
            $Member,
            $MemberType,
            $Permission,
            $Type
        )
        New-Object PSObject -Property @{
            Name = $Name
            Url = $Url
            Member = $Member
            MemberType = $MemberType
            Permission = $Permission
            Type = $Type
        }
    }

    #--------------------------------------------------#
    # main
    #--------------------------------------------------#
    
    # array for the website objects
    $SPWebs = @()
    
    # check if url has been passed
    if($Url){
    
        # get url
        [Uri]$SPWebUrl = (Get-CleanSPUrl -Url $Url).WebUrl
                
        if($IncludeChildItems -and -not $Recursive){
        
            # get spweb object and child spweb objects
            $SPWeb = Get-SPWeb -Identity $SPWebUrl.OriginalString
            $SPWebs += $SPWeb
            $SPWebs += $SPWeb.webs            
        
        }elseif($Recursive -and -not $IncludeChildItems){
        
            # get all sp subsites
            $SPWebs = Get-SPWebs -Identity $SPWebUrl.OriginalString
            
        }else{
        
            # only add this website
            $SPWeb = Get-SPWeb -Identity $SPWebUrl.OriginalString
            $SPWebs += $SPWeb
        }        
     }else{
    
        # Get all Webapplictons
        $SPWebApps = Get-SPWebApplication
        
        # Get all sites
        $SPSites = $SPWebApps | Get-SPsite -Limit all 
    
        foreach($SPSite in $SPSites){

            # Get all websites
            $SPWebs += $SPSite | Get-SPWeb -Limit all
    
        }
    }
           
    #Loop through each website and write permissions
    foreach ($SPWeb in $SPWebs){

        Write-Progress -Activity "Read permissions" -status $SPWeb -percentComplete ([int]([array]::IndexOf($SPWebs, $SPWeb)/$SPWebs.Count*100))
            
        if (($SPWeb.permissions -ne $null) -and  ($SPWeb.HasUniqueRoleAssignments) -and -not $OnlyLists){  
                
            foreach ($RoleAssignment in $SPWeb.RoleAssignments){
            
                # get member
                $Member = Get-SPObjectPermissionMember -RoleAssignment $RoleAssignment
                $MemberType = Get-SPObjectPermissionMemberType -RoleAssignment $RoleAssignment

                # get permission definition
                $Permission = $RoleAssignment.roledefinitionbindings[0].Name
                
                # new item in array
                $SPReportItem = New-ObjectSPReportItem -Name $SPWeb.Title -Url $SPWeb.url -Member $Member -MemberType $MemberType -Permission $Permission -Type "Website" 
                
                # extend with user
                if($ByUsers){Get-SPReportItemByUsers -SPReportItem $SPReportItem}else{$SPReportItem}            
            }        
        }
        
        # output list permissions
        if(-not $OnlyWebsites){                
            foreach ($SPlist in $SPWeb.lists){
                
                if (($SPlist.permissions -ne $null) -and ($SPlist.HasUniqueRoleAssignments)){  
                      
                    foreach ($RoleAssignment in $SPlist.RoleAssignments){
                    
                        # set list url
                        [Uri]$SPWebUrl = $SPWeb.url
                        $SPListUrl = $SPWebUrl.Scheme + "://" + $SPWebUrl.Host + $SPlist.DefaultViewUrl -replace "/([^/]*)\.(aspx)",""
                                                    
                        # get member
                        $Member = Get-SPObjectPermissionMember -RoleAssignment $RoleAssignment
                        $MemberType = Get-SPObjectPermissionMemberType -RoleAssignment $RoleAssignment
                                               
                        # get permission definition
                        $Permission = $RoleAssignment.roledefinitionbindings[0].Name   
                                                 
                        # new item in array
                        $SPReportItem = New-ObjectSPReportItem -Name ($SPWeb.Title + " - " + $SPlist.Title) -Url $SPListUrl -Member $Member -MemberType $MemberType -Permission $Permission -Type "List"
                        
                        # extend with user
                        if($ByUsers){Get-SPReportItemByUsers -SPReportItem $SPReportItem}else{$SPReportItem}  
                    }
                }
            }
        }                
    }
}