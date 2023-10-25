#
# FileName  : WorkItemCreateMain.ps1
# Date      : 11/12/2023
# Author    : Arthur A. Garcia
# Purpose   : This script will copy workitems, save work items to file for versioning.
#             Create work item from a file
# last Update: 10/12/2023

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

#$userParameters.ProjectName = "Gov Portfolio"
#Get-AllFieldsWorkItemType -userParams $userParameters -InheritedProcessName "Opportunity Tracking - Master" -wkItemName "Government opportunity"  -OutputFile "C:\\tempdata\fields.txt"


#
# this will find an existing workitem type in a given process and copy it to json file. this
# will allow you to save the process and subject it to version control
# INPUTS:
#          userParams - Projectdef.json file with parameters used by the script.
#          InheritedProcessName     - The process to copy work item type into
#          WorkItemToSave           - Name to give the WorkItem in the targetPorcess
#          OutputFile               - Name of the file where the process was saved to. include path
# OUTPUT:
#         This function will generate 3 files.
#               1 - path \ OutputFile.json         - this is the work item detail including pages and controls
#               2 - path \ OutputFile-RULE.json    - This is the rules if any were created
#               3 - path \ OutputFile-STATES.json  - This is the states in the work item
#
# SaveWorkItemtoFile -userParams $userParameters -InheritedProcessName "WITSource" -WorkItemToSave "OnePDM Request" -OutputFile ($userParameters.DirRoot + "\\" + "OnePDM_Request.json")


#
# this code will read a workitemtype from a json file and create it in another process.
# INPUTS:
#          userParams - Projectdef.json file with parameters used by the script.
#          TargetProcessName        - The process to copy work item type into
#          TargetWorkItemToCreate   - Name to give the WorkItem in the targetPorcess
#          WorkItemInputFile        - Name of the file where the process was saved to. include path
#
CreateWorkItemFromFile -userParams $userParameters -TargetProcessName "WITSource" -TargetWorkItemToCreate "aagOnePDM fromFile1"  -WorkItemInputFile ($userParameters.DirRoot + "\\" + "OnePDM_Request.json")

#
# INPUTS:
#          userParams - Projectdef.json file with parameters used by the script.
#          InheritedProcessName - The process to copy work item type from
#          DestinationProcess   - Name of the process to copy the new work item type to
#          WorkItemCopyFrom     - Name of the work item type to copy from
#          WorkItemToCopy       - Name of work item type to copy to
#
#Copy-ProcessAndWorkItemType -userParams $userParameters -InheritedProcessName "WITSource" -DestinationProcess "WITSource" -WorkItemCopyFrom "OnePDM Request" -WorkItemToCopy "aagOnePDM Request1" -OutputFile ($userParameters.DirRoot + "\\" + "ProjectList.json")
