# DevOpsApi
PowerShell to work with Azure DevOps API
These PowerSHell scripts are designed to facilitate working with the Azure DevOps envorinment using the published API's/
The scripts contain the following modules:
</br>
1 - WiKiMain.ps1 - This module will generate release notes and publish them into a given Azure DevOps WiKi.
      By simply tagging a build or builds, these scripts will generate all the changes to a build, all work items checked in,
      a list of builds tagged and any artifacts for the tagged builds.
</br>
2 - SecurityMain - This will generate a list of all users in a given project or orginization. 
                   It will also generate a list of all groups and teams in the given project or orginization.
                   It will list all the permissions for each group or team and the uesrs in each.
                   
                   
This set of PowerShell scripts will allow the creation of : </br>Azure DevOps Projects 
                                                            Teams </br>
                                                            Build </br>
                                                            Environments </br>
                                                            Add members to teams </br>
                                                            
You can also list all the allow and deny permissions for a given Organization and Project </br> 
using Get-SecurityForGivenNamespaces

You can also create , List and delete branches in the Git Repos
