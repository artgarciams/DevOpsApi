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

#GetReleaseNotesByQuery -userParams $userParameters


# following are used to get history data out of ADO for processing
# old ADO
$userParameters.VSTSMasterAcct = "csefy19"
$userParameters.ProjectName = "CSEng"
$userParameters.ParentFolder = "Shared Queries/Industry - Government/ISV/"
$userParameters.PAT = ""
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "Old_ISVs_Manufacturing" -outFile "C:\\tempdata\AllCombine.txt"   -CombineFile "yes"
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "Old_ISVs_Retail" -outFile "C:\\tempdata\AllCombine.txt"   -CombineFile "yes"
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "Old_Non_ISVs_Manufacturing" -outFile "C:\\tempdata\AllCombine.txt"   -CombineFile "yes"
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "Old_Non_ISVs_Retail" -outFile "C:\\tempdata\AllCombine.txt"   -CombineFile "yes"

# new ADO
$userParameters.VSTSMasterAcct = "IndustrySolutions"
$userParameters.ProjectName = "IS Engagements"
$userParameters.ParentFolder = "Shared Queries/ISV/ISD/"
$userParameters.PAT = ""

Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "Non_ISVs_All_Industries_ISD" -outFile "C:\\tempdata\ISDCombine.txt"   -CombineFile "yes"

$userParameters.ParentFolder = "Shared Queries/ISV/ISV versus Non-ISV Subjective Exercise/"
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "ISVs_All_Industries" -outFile "C:\\tempdata\AllCombine.txt"   -CombineFile "yes"
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "NoN_ISVs_All_Industries" -outFile "C:\\tempdata\AllCombine.txt"   -CombineFile "yes"
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "ISVs_Manufacturing" -outFile "C:\\tempdata\AllCombine.txt"   -CombineFile "yes"
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "Non_ISVs_Manufacturing" -outFile "C:\\tempdata\AllCombine.txt"   -CombineFile "yes"
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "ISVs_Retail" -outFile "C:\\tempdata\AllCombine.txt"   -CombineFile "yes"
Get-WorkItemHistoryByQuery -userParams $userParameters  -QueryName "Non_ISVs_Retail" -outFile "C:\\tempdata\Combine.txt"   -CombineFile "yes"



