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

# get a list of approvers for the project selected. EnvToReport will report for a given environment or all if ""
# this uses an undocumented api to find approvers
#Get-ApprovalsByEnvironment -userParams $userParameters -outFile "C:\temp\Approvals_11_10_2020.txt"  -EnvToReport ""

# get details for all builds based on folder given. if no folder for all folders in project
# Get-BuildDetailsByProject -userParams $userParameters -outFile "C:\temp\Build_Details_11_11_2020_2.txt" 

# generate a file for each build showing build info, work items, and approvals
# for following parameters in ProjectDef. setting param to "" skips it
#   "Folder"         : "",
#    "Tags"           : ["v1.1","v1.0.1"],
#    "Stages"         : ["Deploy to FDXQA", "Deploy to PROD" ],
#    "BuildResults"   : ["Succeeded"],
#    "BuildNumber"    : "",
Get-ReleaseNotesByTag  -userParams $userParameters 
