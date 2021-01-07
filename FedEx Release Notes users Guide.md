# FedEx Release Notes users Guide

    This document will help to describe the automated generation of Release notes for a given Release.
    We will discuss the pre-requisits, variables required, taging of builds, and the process of how to execute the scripts.

    Pre-requisits

        In order to run these scripts you will need to run these PowerShell scripts on your PC.

        To run PowerShell it was determined you will need to disconnect from the FedEx VPN. Th FedEx firewall is blocking the Azure DevOps calls from Powershell and this will allow it to proceed. Remember to reconnect after you are done running the scripts.

        You will also need access to Azure DevOps API's by creating a Personal Access Token(PAT). See the Word document
        in the repo and follow the steps outlined. NOTE:You must copy the token before you leave the page. it will not be accessable after.
        
    Variables Required
            In order to run the Release Notes generation script you will need to set a few variables. These variables are found in the ProjectDef.json file. 
            Following are the variable you will need to review prior to running the script.NOTE only replace data within the quotes. DO NOT REMOVE any of the COMMAs.

            "VSTSMasterAcct" : "fdx-strat-pgm",
            "userEmail"      : "your email address",
            "PAT"            : "this is where you add your Personal access token (PAT) ",       
            "ProjectName"    : "fdx-surround",      - THIS IS THE NAME OF THE PROJECT YOU WANT TO REPORT ON

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


    Tagging of Azure DevOps artifacts. 

            In order for this script to work you must tag the builds you want included in the release notes. Each build you want to include in the Release Notes must have a tag with the release number. This should be in the format of Release:x.x.x. Note PLEASE make sure that there are no spaces before or after any of the peroids and before and after the :

            Next you will need a sequence number. This will designate the order the builds will be applied to prodction. THIS is for documentation purposes only. If you choose not to use the sequence, the script will place a 0 for the sequence number. To use the Sequence Number please use the following format Sequence:x Again no spaces before or after the :

            Next is the Solution area for the build selected. This is in the format Solution:aaaaaaa
            This will show up in the build table of the release notes.

            In summary the following tags must be present in each build you want in the release notes.
                Release:x.x.x
                Sequence:x
                Solution:aaaaaaaaa

    Execution process

            Step 1:
                Download all the files from the Release Notes repo to your local machine.
                The Repo can be found here: https://dev.azure.com/fdx-strat-pgm/common/_git/Release%20Notes?version=GBmain
                Make sure they are all in the same directory.
            
            Step 2:
                Verify the Tags have been added to the builds. You will need the Release tag so the scripts can find the builds tagged.

            Step 3: 
                Obtain a valid Personal Access Token. Refer to the documentation provided in the word doc on how to generate a token. It is important that the token be a FULL Access token. Next add this token to the ProjectDef.Json file.

            Step 4:
                Modify the parameters for your project and release conditions. See (Variables Required above)
                We will begin by modifing the ProjectDef.json file as stated above in the Variables Required section. This file contains the parameters needed to run the scripts. Review and modify each parameter as required making sure you do not remove any COMMAS or Quotation marks.

            Step 5:
                You need to open "Windows PowerShell ISE" as administrator.
                Open the script file WiKiMain.ps1. This is the file that you wil execute to generate the Release Notes. 
                                          
            Step 6:
                Run the script. IF the page already exists the script will stop and generate an error message at the bottom of the page.
                the error will be : Page exists - Script terminated, Please review page
