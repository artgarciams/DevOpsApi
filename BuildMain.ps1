#
# FileName  : BuildMain.ps1
# Date      : 10/28/2020
# Author    : Arthur A. Garcia
# Purpose   : This script will 
#             It will also get build information
#             This script is for demonstration only not to be used as production code
# last Update: 10/28/2020

#import modules
$modName = $PSScriptRoot + "\SecurityHelper.psm1" 
Import-Module -Name $modName

$modName = $PSScriptRoot + "\ProjectAndGroup.psm1" 
Import-Module -Name $modName

# get parameter data for scripts
$UserDataFile = $PSScriptRoot + "\ProjectDef.json"
$userParameters = Get-Content -Path $UserDataFile | ConvertFrom-Json

Write-Output $userParameters.ProjectName
Write-Output $userParameters.Description

Get-BuildDetailsByProject -userParams $userParameters -outFile "C:\temp\Build_surround_common.txt" -FolderName "surround-common"
