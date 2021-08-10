#
# FileName  : WikiMain.ps1
# Date      : 10/28/2020
# Author    : Arthur A. Garcia
# Purpose   : This script will generate release notes and move them into a WiKi page.
#             This script is for demonstration only not to be used as production code
# last Update: 12/04/2020

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
Write-host $userParameters.BuildTags 

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

#Get-BuildDetailsByProject -userParams $userParameters  -outFile "C:\temp\buildprj.txt"

# generate a file for each build showing build info, work items, and approvals
# for following parameters in ProjectDef. setting param to "" skips it
#    
#      "VSTSMasterAcct" : "fdx-strat-pgm",
#      "userEmail"      : "your email address",
#      "PAT"            : "this is where you add your Personal access token (PAT) ",       
#      "ProjectName"    : "fdx-surround",      - THIS IS THE NAME OF THE PROJECT YOU WANT TO REPORT ON
#      "BuildTags"      : "Release:1.1.0",     - THIS IS THE RELEASE YOU WANT TO REPORT ON. NOTE IT MUST BE IN THE FORMAT SHOWN
#                                                    :Release:x.x.x 
#      "PublishWiKi"    : "lumina.wiki",           - THIS IS THE NAME OF THE WIKI TO PUBLISH TO 
#      "PublishParent"  : "Release Notes",         - THIS IS THE PARENT PAGE THE PAGE WILL BE PLACED UNDER
#      "PublishPagePrfx": "System Release ",       - THIS IS THE NAME YOU WANT FOR THE PAGE. NAME WIIL BE PROJECT NAME + THIS TAG 
#                                                        + THE RELEASE NUMBER IE : fdx-surround - System Release - Release:1.1.0
#      "PublishBldNote" : "Build section Notes",   - THIS IS ANY NOTES YOU WANT TO ADD TO THE BUILD SECTION
#      "PublishWKItNote": "Work Item section note",- THIS IS ANY NOTES YOU WANT IN THE WORK ITEM SECTION
#      "PublishTestNote": "Testing Notes",         - THIS IS ANY NOTES YOU WANT IN THE TESTING SECTION
#      "WorkItemTypes"  : ["User Story","Bug"],    - THESE ARE THE WORK ITEM TYPES TO REPORT ON . DO NOT CHANGE
#      "BuildResults"   : ["Succeeded"],           - THIS IS THE BUILD STATUS TO REPORT ON. DO NOT CHANGE
#      "HTTP_preFix"    : "https",                 - THIS IS THE SECURITY TO USE IN THE API CALL . DO NOT CHANGE
#      "OutPutToFile"   : "No",                    - THIS IS IF YOU WANT LOGS GENERATED TO AUDIT WHAT GETS CREATED
#
$BuildData = Get-ReleaseNotesByBuildByTag  -userParams $userParameters 


# create wiki page 
# This method will create a wiki page of the release notes found. It will create a page using the
# PublishSub value + the BuildTags value. it will put the page under  the PublishParent page and sub page called PublishSub. the Release
# notes will reside in that page.
#
#      "VSTSMasterAcct" : "fdx-strat-pgm",
#      "userEmail"      : "your email address",
#      "PAT"            : "this is where you add your Personal access token (PAT) ",       
#      "ProjectName"    : "fdx-surround",      - THIS IS THE NAME OF THE PROJECT YOU WANT TO REPORT ON
#      "BuildTags"      : "Release:1.1.0",     - THIS IS THE RELEASE YOU WANT TO REPORT ON. NOTE IT MUST BE IN THE FORMAT SHOWN
#                                                    :Release:x.x.x 
#      "PublishWiKi"    : "lumina.wiki",           - THIS IS THE NAME OF THE WIKI TO PUBLISH TO 
#      "PublishParent"  : "Release Notes",         - THIS IS THE PARENT PAGE THE PAGE WILL BE PLACED UNDER
#      "PublishPagePrfx": "System Release ",       - THIS IS THE NAME YOU WANT FOR THE PAGE. NAME WIIL BE PROJECT NAME + THIS TAG 
#                                                        + THE RELEASE NUMBER IE : fdx-surround - System Release - Release:1.1.0
#      "PublishBldNote" : "Build section Notes",   - THIS IS ANY NOTES YOU WANT TO ADD TO THE BUILD SECTION
#      "PublishWKItNote": "Work Item section note",- THIS IS ANY NOTES YOU WANT IN THE WORK ITEM SECTION
#      "PublishTestNote": "Testing Notes",         - THIS IS ANY NOTES YOU WANT IN THE TESTING SECTION
#      "WorkItemTypes"  : ["User Story","Bug"],    - THESE ARE THE WORK ITEM TYPES TO REPORT ON . DO NOT CHANGE
#      "BuildResults"   : ["Succeeded"],           - THIS IS THE BUILD STATUS TO REPORT ON. DO NOT CHANGE
#      "HTTP_preFix"    : "https",                 - THIS IS THE SECURITY TO USE IN THE API CALL . DO NOT CHANGE
#      "OutPutToFile"   : "No",                    - THIS IS IF YOU WANT LOGS GENERATED TO AUDIT WHAT GETS CREATED
#
Set-ReleaseNotesToWiKi  -userParams $userParameters -Data $BuildData
