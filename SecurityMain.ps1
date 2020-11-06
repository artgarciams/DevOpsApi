#
# FileName  : SecurityMain.ps1
# Date      : 02/08/2018
# Author    : Arthur A. Garcia
# Purpose   : 
#             It will get security permissions by team or group
#             This script is for demonstration only not to be used as production code
# last Update: 10/07/2020

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

# Get all groups and there permissions
Get-SecuritybyGroupByNamespace -userParams $userParameters  -rawDataDump ""  -getAllProjects "False" -outFile "Get-SecuritybyGroupByNamespace-11-03.txt" 

# get list of members of group in project or all projects by adding -groupname "All"
Get-AllUSerMembership  -userParams $userParameters -outFile "Get-AllUSerMembership-10-28-2.txt" -getAllProjects "True"
