#
# FileName  : WorkItemReleaseNotesMain.ps1
# Date      : 02/22/2022
# Author    : Arthur A. Garcia
# Purpose   : This script will generate release notes from a work item query and move them into a WiKi page.
#             This script is for demonstration only not to be used as production code
# last Update: 10/03/2022

#import modules
$modName = $PSScriptRoot + "\SecurityHelper.psm1" 
Import-Module -Name $modName

$modName = $PSScriptRoot + "\ReleaseNotes.psm1" 
Import-Module -Name $modName

# get parameter data for scripts
$UserDataFile = $PSScriptRoot + "\ProjectDef.json"
$userParameters = Get-Content -Path $UserDataFile | ConvertFrom-Json

Write-host $userParameters.ProjectName
Write-host $userParameters.userEmail
Write-host $userParameters.CurrentWitemQry 
Write-Host $userParameters.FutureWitemQry

GeReleaseNotesByQuery -userParams $userParameters


