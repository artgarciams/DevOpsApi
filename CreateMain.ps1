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

$userParameters.ProjectName = "Gov Portfolio"
Get-AllFieldsWorkItemType -userParams $userParameters -InheritedProcessName "Opportunity Tracking - Master" -wkItemName "Government opportunity"  -OutputFile "C:\\tempdata\fields.txt"

Copy-ProcessAndWorkItemType -userParams $userParameters -InheritedProcessName "Opportunity Tracking - Master" -DestinationProcess "Opportunity Tracking - Master" -NewWorkItemName "Master Opportunity" -WorkItemToCopy "Government opportunity"


#Get-ProjectMetrics -userParams $userParameters

#list available branches*
##ListGitBranches -userParams $userParameters -outFile ($userParameters.DirRoot + "\\" + $userParameters.GitListFile) -GetAllProjects "no"

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


