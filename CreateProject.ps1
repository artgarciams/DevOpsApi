#
# FileName  : CreateProject.ps1
# Date      : 02/08/2018
# Author    : Arthur A. Garcia
# Purpose   : This script will create a project in VSTS and add groups to the
#             project. It will allow you to set security at the user and group level as needed.
#             It will also get security permissions by team or group
#             This script is for demonstration only not to be used as production code
# last Update: 9/30/2020


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

# list of groups and teams in a and permissions for a given namespace note does not include teams
#Get-SecuritybyGroupByNamespace -userParams $userParameters -NamespaceFilter "All" -outFile "C:\temp\dataBuild_groupsAll.txt" -getAllProjects "False"

# get list of members of group in project or all projects by adding -groupname "All"
Get-GroupMembership  -userParams $userParameters -outFile "C:\temp\dataBuild_usersAll.txt" -getAllProjects "True"


#Get-Teams -userParams $userParameters
# get resource group by subscription
# $rgList = Get-ResourceGroupBySubscription -userParams $userParameters

# get list of team permissions
#Get-TeamsAndPermsions  -userParams $userParameters  -NamespaceFilter "Project" -outFile "C:\temp\dataBuild_teamsAll.txt" -Allprojects "True"





#list available branches
# ListGitBranches -userParams $userParameters -outFile "C:\temp\dataBuild_r001.txt"

# add a brance from master
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


