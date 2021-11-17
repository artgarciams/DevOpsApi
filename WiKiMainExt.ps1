#
# FileName  : WikiMainExt.ps1
# Date      : 07/20/2021
# Author    : Arthur A. Garcia
# Purpose   : This script will generate a Wiki Page of release notes based on build tags.
#             This file will be the interface to the ADO extension and called by the extension.
#             
# last Update: 09/01/2021

$modName = ".\ReleaseNotes.psm1" 
Import-Module -Name $modName

# get parameter data for scripts
$UserDataFile = ".\ProjectDef.json"
$userParameters = Get-Content -Path $UserDataFile | ConvertFrom-Json

# get current running parameters - for local testing   
$org = $Env:SYSTEM_TEAMFOUNDATIONSERVERURI
$org = $org.replace('https://dev.azure.com/','') 
$org = $org.replace('/','')

# get PAT key from input variables.
$key = Get-VstsInput -Name 'PATKEY'    

Write-Host ""   
Write-Host "Running in Orginization :  $org "
Write-Host "Running in Team Project :  $Env:SYSTEM_TEAMPROJECT "
Write-Host "Using PATKEY :  $key "
Write-Host ""



$userParameters.VSTSMasterAcct =$org
$userParameters.ProjectName =  $Env:SYSTEM_TEAMPROJECT  	
$userParameters.userEmail = Get-VstsInput -Name 'userEmail'    
#$userParameters.userEmail = $Env:BUILD_REQUESTEDFOREMAIL        
        
# variables to run apis
$userParameters.HTTP_preFix = "https"
$userParameters.WorkItemTypes = Get-VstsInput -Name 'WorkItemTypes'    
$userParameters.OutPutToFile = "No"

# variables for taging and wiki publish information
$userParameters.PAT =  $key
$useExt = "No"

$userParameters.BuildTags = Get-VstsInput -Name 'BuildTags'
$userParameters.PublishWiKi = Get-VstsInput -Name 'PublishWiKi'
$userParameters.PublishParent = Get-VstsInput -Name 'PublishParent'
$userParameters.PublishPagePrfx = Get-VstsInput -Name 'PublishPageName'

# turn build tag into array input is comma seperated
$slp = $userParameters.BuildTags.Split(',')
$userParameters.BuildTags = $slp

# variables for publish notes section
$userParameters.PublishBldNote = Get-VstsInput -Name 'PublishBldNote'
$userParameters.PublishWKItNote = Get-VstsInput -Name 'PublishWKItNote'
$userParameters.PublishArtfNote = Get-VstsInput -Name 'PublishArtfNote'

# variables for permanent notes
$userParameters.PermNoteTitle = Get-VstsInput -Name 'PermanentNotesTitle'
$userParameters.PermNoteBody = Get-VstsInput -Name 'PermanentNotes'

Write-host "Current Running Environment Override : " $useCurrentEnv
Write-Host "Using Orginization : " $userParameters.VSTSMasterAcct 
Write-Host "Using Project      : " $userParameters.ProjectName
Write-Host "Using Build User   : " $userParameters.userEmail
Write-Host ""
Write-Host "Searching for Build Tags   : " $userParameters.BuildTags
Write-Host "Publishing to Project Wiki : " $userParameters.PublishWiKi
Write-Host "Publishing to Parent Page  : " $userParameters.PublishParent
Write-Host "Publishing to Page         : " $userParameters.PublishPagePrfx

Write-Host ""
Write-Host "Build section notes     : " $userParameters.PublishBldNote
Write-Host "Work Item section notes : " $userParameters.PublishWKItNote
Write-Host "Artifact section notes  : " $userParameters.PublishArtfNote
Write-Host ""

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
$BuildData = Get-ReleaseNotesByBuildByTag  -userParams $userParameters -UsingExtension $useExt

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
Set-ReleaseNotesToWiKi  -userParams $userParameters -Data $BuildData -UsingExtension $useExt
