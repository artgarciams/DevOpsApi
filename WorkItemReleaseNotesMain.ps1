#
# FileName  : WorkItemReleaseNotesMain.ps1
# Date      : 02/22/2022
# Author    : Arthur A. Garcia
# Purpose   : This script will generate release notes from a work item query and move them into a WiKi page.
#             This script is for demonstration only not to be used as production code
# last Update: 12/04/2020

#import modules
$modName = $PSScriptRoot + "\SecurityHelper.psm1" 
Import-Module -Name $modName

$modName = $PSScriptRoot + "\ReleaseNotes.psm1" 
#$modName = $PSScriptRoot + "\ProjectAndGroup.psm1" 
Import-Module -Name $modName

# get parameter data for scripts
$UserDataFile = $PSScriptRoot + "\ProjectDef.json"
$userParameters = Get-Content -Path $UserDataFile | ConvertFrom-Json

Write-host $userParameters.ProjectName
Write-host $userParameters.userEmail
Write-host $userParameters.BuildTags 
Write-Host $userParameters.TagLeads


$slp = $userParameters.BuildTags.Split(',')
$userParameters.BuildTags = $slp


# $userParameters.userEmail =  ${env:USEREMAIL}

# make sure directory structure exists
#    "DirRoot"        : "C:\\TempData",
#    "ReleaseDir"     : "\\BuildNotes\\",
#    "LogDirectory"   : "\\Logs\\",
#    "DumpDirectory"  : "\\RawData\\",
#    "SecurityDir"    : "\\Security\\", 
if($userParameters.OutPutToFile -eq "Yes" )
{
    Set-DirectoryStructure -userParams $userParameters 
}

GeReleaseNotesByQuery -userParams $userParameters


