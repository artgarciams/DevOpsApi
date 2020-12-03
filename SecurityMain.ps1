#
# FileName  : SecurityMain.ps1
# Date      : 02/08/2018
# Author    : Arthur A. Garcia
# Purpose   : 
#             It will get security permissions by team or group
#             
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

# make sure directory structure exists
#    "DirRoot"        : "C:\\TempData",
#    "ReleaseDir"     : "\\BuildNotes\\",
#    "LogDirectory"   : "\\Logs\\",
#    "DumpDirectory"  : "\\RawData\\",
#    "SecurityDir"    : "\\Security\\",
#    
Set-DirectoryStructure -userParams $userParameters 

# Get all groups and there permissions
#       "VSTSMasterAcct" : "fdx-strat-pgm",
#       "userEmail"      : "arthur.garcia.osv@fedex.com",
#       "PAT"            : "",       
#       "ProjectName"    : "fdx-surround",
#       "HTTP_preFix"    : "https",
Get-SecuritybyGroupByNamespace -userParams $userParameters  -rawDataDump "rawdump.txt"  -getAllProjects "True" -outFile "Get-SecuritybyGroupByNamespace-12-2.txt" 

# get list of members of group in project or all projects by adding -groupname "All"
#       "VSTSMasterAcct" : "fdx-strat-pgm",
#       "userEmail"      : "arthur.garcia.osv@fedex.com",
#       "PAT"            : "",       
#       "ProjectName"    : "fdx-surround",
#       "HTTP_preFix"    : "https",
Get-AllUSerMembership  -userParams $userParameters -outFile "Get-AllUSerMembership-12-2.txt" -getAllProjects "True"
