# DevOpsApi
PowerShell to work with Azure DevOps API
These PowerSHell scripts are designed to facilitate working with the Azure DevOps envorinment using the published API's
</br>
</br>
The scripts contain the following modules:
</br>
</br>
1 - WiKiMain.ps1 - This module will generate release notes and publish them into a given Azure DevOps WiKi.
      By simply tagging a build or builds, these scripts will generate all the changes to a build, all work items checked in,
      a list of builds tagged and any artifacts for the tagged builds.
</br>
</br>
2 - SecurityMain - This will generate a list of all users in a given project or orginization. 
                   It will also generate a list of all groups and teams in the given project or orginization.
                   It will list all the permissions for each group or team and the uesrs in each.
                   
</br>
</br>
3 - CreatMain.ps1 - This will generate a project,team and add users to a team. It will also create environments and default builds.
                    You can also create , List and delete branches in the Git Repos
                   
