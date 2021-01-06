#
# FileName  : WikiMain.ps1
# Date      : 10/28/2020
# Author    : Arthur A. Garcia
# Purpose   : This script will 
#             This script is for demonstration only not to be used as production code
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
if($userParameters.OutPutToFile -eq "Yes" )
{
    Set-DirectoryStructure -userParams $userParameters 
}
# generate a file for each build showing build info, work items, and approvals
# for following parameters in ProjectDef. setting param to "" skips it
#    
#    "VSTSMasterAcct" : "fdx-strat-pgm",   
#    "ProjectName"    : "fdx-surround",
#
#    "BuildTags"      : "1.1.0",
#    "WorkItemTypes"  : ["User Story","Bug"],
#    "ParentWiType"   : "User Story",
#    "BuildResults"   : ["Succeeded"],
#
#    "HTTP_preFix"    : "https",
#    "ReleaseFile"    : "BuildTable.txt",
#  
#    "OutPutToFile"   : "Yes",
#    "DirRoot"        : "C:\\TempData",
#    "ReleaseDir"     : "\\BuildNotes\\",
$BuildData = Get-ReleaseNotesByBuildByTag  -userParams $userParameters 

# create wiki page 
# This method will create a wiki page of the release notes found. It will create a page using the
# PublishSub value + the BuildTags value. it will put the page under  the PublishParent page and sub page called PublishSub. the Release
# notes will reside in that page.
#
#    "VSTSMasterAcct" : "fdx-strat-pgm",   
#    "ProjectName"    : "fdx-surround",
#    "PublishWiKi"    : "Name of the Project wiki",
#    "PublishParent"  : "Name of the parent page to publish this release to ie. "Release Notes"
#    "PublishPagePrfx": "Name of Release note page. page name = Project name + "name" + build tag
#    "BuildTags"      : "1.1.0",
#    "PublishBldNote" : "build section notes",
#    "PublishWKItNote": "work item section notes"
#
Set-ReleaseNotesToWiKi  -userParams $userParameters -Data $BuildData
