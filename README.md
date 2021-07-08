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
Variables Required

        In order to run the Release Notes generation script you will need to set a few variables. These variables are found in the ProjectDef.json file. 
        Following are the variable you will need to review prior to running the script. NOTE only replace data within the quotes. DO NOT REMOVE any of the COMMAs.

        "VSTSMasterAcct" : "Org name",
        "userEmail"      : "your email address",
        "PAT"            : "this is where you add your Personal access token (PAT) ",       
        "ProjectName"    : "project name",      - THIS IS THE NAME OF THE PROJECT YOU WANT TO REPORT ON

        "BuildTags"      : "Release:1.1.0",     - THIS IS THE RELEASE YOU WANT TO REPORT ON. NOTE IT MUST BE IN THE FORMAT SHOWN
                                                    :Release:x.x.x 

        "PublishWiKi"    : "lumina.wiki",           - THIS IS THE NAME OF THE WIKI TO PUBLISH TO 
        "PublishParent"  : "Release Notes",         - THIS IS THE PARENT PAGE THE PAGE WILL BE PLACED UNDER
        "PublishPagePrfx": "System Release ",       - THIS IS THE NAME YOU WANT FOR THE PAGE. NAME WIIL BE PROJECT NAME + THIS TAG 
                                                        + THE RELEASE NUMBER IE : fdx-surround - System Release - Release:1.1.0
        "PublishBldNote" : "Build section Notes",   - THIS IS ANY NOTES YOU WANT TO ADD TO THE BUILD SECTION
        "PublishWKItNote": "Work Item section note",- THIS IS ANY NOTES YOU WANT IN THE WORK ITEM SECTION
          
        "WorkItemTypes"  : ["User Story","Bug"],    - THESE ARE THE WORK ITEM TYPES TO REPORT ON . DO NOT CHANGE
        "BuildResults"   : ["Succeeded"],           - THIS IS THE BUILD STATUS TO REPORT ON. DO NOT CHANGE
        
        "HTTP_preFix"    : "https",                 - THIS IS THE SECURITY TO USE IN THE API CALL . DO NOT CHANGE
        "OutPutToFile"   : "No",                    - THIS IS IF YOU WANT LOGS GENERATED TO AUDIT WHAT GETS CREATED

        The above parameters are the only ones needed to run thr release notes. The file they reside in contains other parameters. PLEASE do not attemt to change any other parameters without discussing it with the developer of this script.
      
</br>
</br>
2 - SecurityMain - This will generate a list of all users in a given project or orginization. 
                   It will also generate a list of all groups and teams in the given project or orginization.
                   It will list all the permissions for each group or team and the uesrs in each.
                   
</br>
</br>
3 - CreatMain.ps1 - This will generate a project,team and add users to a team. It will also create environments and default builds.
                    You can also create , List and delete branches in the Git Repos
                   
