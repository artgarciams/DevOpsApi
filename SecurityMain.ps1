#
# FileName  : SecurityMain.ps1
# Date      : 02/08/2018
# Author    : Arthur A. Garcia
# Purpose   : 
#             It will get security permissions by team or group
#    This script is for demonstration only not to be used as production code
# last Update: 12/04/2020

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
Set-DirectoryStructure -userParams $userParameters 


# get list of members of group in project or all projects by adding -groupname "All"
#       "VSTSMasterAcct" : "",
#       "userEmail"      : "arthur.garcia.osv@fedex.com",
#       "PAT"            : "",       
#       "ProjectName"    : "fdx-surround",
#       "HTTP_preFix"    : "https",
#       "AllProjects"    : "True"
#       "UserFileName"   : "Get-AllUSerMembership-12-2.txt",
Get-AllUSerMembership  -userParams $userParameters -outFile $userParameters.UserFileName  -getAllProjects $userParameters.AllProjects


# Get all groups and there permissions
#       "VSTSMasterAcct" : "", 
#       "userEmail"      : "arthur.garcia.osv@fedex.com",
#       "PAT"            : "",       
#       "ProjectName"    : "",
#       "HTTP_preFix"    : "https",
#       "Namespaces"     : ["Analytics","Tagging","Project","AnalyticsViews","AuditLog","BuildAdministration","Server","VersionControlPrivileges","Process","Collection"]
#       "AllProjects"    : "True"
#       "GroupFileName"  : "Get-SecuritybyGroupByNamespace-12-2.txt",
#       "rawDataFile"    : "rawdump.txt"
Get-SecuritybyGroupByNamespace -userParams $userParameters  -rawDataDump $userParameters.rawDataFile  -getAllProjects $userParameters.AllProjects  -outFile $userParameters.GroupFileName


