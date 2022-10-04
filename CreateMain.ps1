#
# FileName  : CreateMain.ps1
# Date      : 02/08/2018
# Author    : Arthur A. Garcia
# Purpose   : This script will create a project in VSTS and add groups to the
#             project. It will allow you to set security at the user and group level as needed.
#             It will also get security permissions by team or group
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

#$userParameters.ProjectName = "Gov Portfolio"
#Get-AllFieldsWorkItemType -userParams $userParameters -InheritedProcessName "Opportunity Tracking - Master" -wkItemName "Government opportunity"  -OutputFile "C:\\tempdata\fields.txt"

#
# INPUTS:
#          userParams - Projectdef.json file with parameters used by the script.
#          InheritedProcessName - The process to copy work item type from
#          DestinationProcess   - Name of the process to copy the new work item type to
#          WorkItemCopyFrom     - Name of the work item type to copy from
#          WorkItemToCopy       - Name of work item type to copy to
#
Copy-ProcessAndWorkItemType -userParams $userParameters -InheritedProcessName "artgarciavsts Agile" -DestinationProcess "New Agile Process" -WorkItemCopyFrom "Feature" -WorkItemToCopy "New Feature"

#Get-ProjectMetrics -userParams $userParameters

#GetFirstRepoCommitDate -userParams $userParameters -outFile ($userParameters.DirRoot + "\\" + "ProjectList.txt")

# list all projects and repos
#ListAllProjectsAndRepos -userParams $userParameters -outFile ($userParameters.DirRoot + "\\" + "ProjectList.csv")


#list available branches*
#ListGitBranches -userParams $userParameters -outFile ($userParameters.DirRoot + "\\" + $userParameters.GitListFile) -GetAllProjects "no"

# list all azure services 
# $allServices = Get-AllAzureServices -outFile "C:\\tempdata\\services.txt"
# Write-Host $allServices

# add a brance from master*
#AddGitBranchFromMaster -userParams $userParameters -branchToCreate "refs/heads/release/v4"

#delete branch
#DeleteGitBranchByPath -userParams $userParameters -branchPath "refs/heads/release/v4"

# create project    
#CreateVSTSProject -userParams $userParameters

# add teams to project
#AddProjectTeams -userParams $userParameters

# add vsts groups
#AddVSTSGroupAndUsers -userParams $userParameters

# add repo
#$repo = CreateVSTSGitRepo -userParams $userParameters

# create build
#Set-BuildDefinition -userParams $userParameters -repo $repo

# add security to each group 
#$authorization = GetVSTSCredential -Token $userParameters.PAT -userEmail $userParameters.userEmail
#Add-GroupSecurity -ProjectName $userParameters.ProjectName  -VSTSMasterAcct $userParameters.VSTSMasterAcct -authorization $authorization -teamList $userParameters.Teams


