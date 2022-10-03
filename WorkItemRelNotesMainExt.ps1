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
Import-Module -Name $modName

# get parameter data for scripts
$UserDataFile = $PSScriptRoot + "\ProjectDef.json"
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
$userParameters.OutPutToFile = "No"

# variables for taging and wiki publish information
$userParameters.PAT =  $key
$useExt = "No"

$userParameters.TagLeads = Get-VstsInput -Name 'tagLeads'
$userParameters.PublishWiKi = Get-VstsInput -Name 'PublishWiKi'
$userParameters.PublishParent = Get-VstsInput -Name 'PublishParent'
$userParameters.PublishPagePrfx = Get-VstsInput -Name 'PublishPageName'

# variables for publish notes section
$userParameters.WhatsNewComment = Get-VstsInput -Name 'WhatsNewComment'
$userParameters.CurrentWitemQry = Get-VstsInput -Name 'CurrentSprintQuery'
$userParameters.FutureWitemQry = Get-VstsInput -Name 'FutureSprintQuery'
$userParameters.CurrentQryText = Get-VstsInput -Name 'CurrentQueryText'
$userParameters.FutureQryText = Get-VstsInput -Name 'FutureQueryText'

Write-host "Current Running Environment Override : " $useCurrentEnv
Write-Host "Using Orginization : " $userParameters.VSTSMasterAcct 
Write-Host "Using Project      : " $userParameters.ProjectName
Write-Host "Using Build User   : " $userParameters.userEmail
Write-Host "Tag leads          : " $userParameters.TagLeads

Write-Host ""
Write-Host "Searching for Build Tags   : " $userParameters.BuildTags
Write-Host "Publishing to Project Wiki : " $userParameters.PublishWiKi
Write-Host "Publishing to Parent Page  : " $userParameters.PublishParent
Write-Host "Publishing to Page         : " $userParameters.PublishPagePrfx

Write-Host ""
Write-Host "Whats New Comments      : " $userParameters.WhatsNewComment
Write-Host ""
Write-Host "Title for Current Query : " $userParameters.CurrentQryText 
Write-Host "Current Sprint query    : " $userParameters.CurrentWitemQry
Write-Host ""
Write-Host "Title for Future Query  : " $userParameters.FutureQryText 
Write-Host "Future Sprint query     : " $userParameters.FutureWitemQry

Write-Host ""

GetWorkItemsByField -userParams $userParameters -UsingExtension $useExt


