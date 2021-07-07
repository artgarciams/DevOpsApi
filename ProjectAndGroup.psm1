#
# FileName : ProjectAndGroup.psm1
# Data     : 02/09/2018
# Purpose  : this module will create a project and groups for a project
#           This script is for demonstration only not to be used as production code
#
# last update 12/04/2020

function CreateVSTSProject () {
    Param(
        [Parameter(Mandatory = $true)]
        $userParams
    )
      
    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # get process id & variables needed
    $processId = GetVSTSProcesses -userParams $userParams -authorization $authorization
    $name = $userParams.ProjectName
    $description = $userParams.description 

    # json body to create project
    $v1 = @{
        name = $name
        description = $description
        capabilities = @{ versioncontrol = @{ sourceControlType = "Git" } 
            processTemplate = @{ templateTypeId = $processId} 
        }
    }
    $valJson = ConvertTo-Json -InputObject $v1
   
    try {
        # check if project already exists
        $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/defaultcollection/_apis/projects?api-version=2.0-preview"
        $currProjects = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization 

        $fnd = $currProjects.value | Where-Object {$_.name -eq $name}
        IF (![string]::IsNullOrEmpty($fnd)) {
            Write-Host "Project found"
            Return $fnd.name
        } 
        
        # project does not exist, create new one
        $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/defaultcollection/_apis/projects?api-version=2.0-preview"
        $return = Invoke-RestMethod -Uri $projectUri -Method Post -ContentType "application/json" -Headers $authorization -Body $valJson
        return $return
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Project Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}

Function AddProjectTeams() {
    Param(
        [Parameter(Mandatory = $true)]
        $userParams
    )
            
    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
    
    # add / update groups in project
    foreach ( $item in $userParams.Teams) {
        $tmData = @{ name = $item.name
            description = $item.description
        }

        $tmJson = ConvertTo-Json -InputObject $tmData
        $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".VisualStudio.com/DefaultCollection/_apis/projects/" + $userParams.ProjectName + "/teams?api-version=2.2"

        # Add team
        try {
            Invoke-RestMethod -Uri $projectUri -Method Post -ContentType "application/json" -Headers $authorization -Body $tmJson            
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
        }
    }  

}

##############################
#
# doc : https://www.visualstudio.com/en-us/docs/integrate/api/graph/groups#create-a-group-at-the-account-level
##############################
function AddVSTSGroupAndUsers() {
    Param(
        [Parameter(Mandatory = $true)]
        $userParams 
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

   try {

        # first loop thru the teams and add the users to the teams
        foreach ( $item in $userParams.Teams) {
         
            # find the group if it exists
            $fnd = Get-GroupInfo -userParams $userParams -groupname $item.name 
        
            IF (![string]::IsNullOrEmpty($fnd)) {

                Write-Host "Team :" + $fnd.displayName + " Found, Descriptor : " + $fnd.descriptor

                foreach ( $usr in $item.users){

                    # add user to group
                    $userData = @{principalName = $usr}
                    $json = ConvertTo-Json -InputObject $userData

                    $adduserUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/users?groupDescriptors=" + $fnd.descriptor + "&api-version=4.0-preview"
                    $grp =  Invoke-RestMethod -Uri $adduserUri -Method Post -Headers $authorization -ContentType "application/json" -Body $json
                }
            } 
        }

        # now loop thru the VSTS groups and add users and groups as needed
        foreach ($item in $userParams.VSTSGroups)
        {
            # create group header
            $tmData = @{ displayName = $item.name
                description = $item.description
            }
            $tmJson = ConvertTo-Json -InputObject $tmData

            # add / group 
            $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/groups?api-version=4.0-preview"
            $fnd = Invoke-RestMethod -Uri $projectUri -Method Post -Headers $authorization  -ContentType "application/json" -Body $tmJson       
    
            IF (![string]::IsNullOrEmpty($fnd)) {

                Write-Host "Team :" + $fnd.displayName + " Found, Descriptor : " + $fnd.descriptor

                foreach ( $usr in $item.users){

                    # add user to group
                    $userData = @{principalName = $usr}
                    $json = ConvertTo-Json -InputObject $userData

                    $adduserUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/users?groupDescriptors=" + $fnd.descriptor + "&api-version=4.0-preview"
                    $grp =  Invoke-RestMethod -Uri $adduserUri -Method Post -Headers $authorization -ContentType "application/json" -Body $json
                }
            } 
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }

}

function Set-DirectoryStructure()
{
    # this function will setup the directory structure for files that this powershell script will need.
    Param(
        [Parameter(Mandatory = $true)]
        $userParams
    )
 
    # make sure directory structure exists
    if(!(test-path  $userParams.DirRoot))
    {
        New-Item -ItemType directory -Path $userParams.DirRoot
    }

    if(!(test-path  ($userParams.DirRoot + $userParams.SecurityDir) ))
    {
        New-Item -ItemType directory -Path ($userParams.DirRoot + $userParams.SecurityDir)
    }

    if(!(test-path  ($userParams.DirRoot + $userParams.DumpDirectory) ))
    {
        New-Item -ItemType directory -Path ($userParams.DirRoot + $userParams.DumpDirectory)
    }
    
    if(!(test-path  ($userParams.DirRoot + $userParams.LogDirectory) ))
    {
        New-Item -ItemType directory -Path ($userParams.DirRoot + $userParams.LogDirectory)
    }

    if(!(test-path  ($userParams.DirRoot + $userParams.ReleaseDir) ))
    {
        New-Item -ItemType directory -Path ($userParams.DirRoot + $userParams.ReleaseDir)
    }

    
}

function Get-ApprovalsByEnvironment()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $outFile,
        [Parameter(Mandatory = $false)]
        $EnvToReport
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # get list of environments
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/environments/list?view=azure-devops-rest-6.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments?api-version=6.1-preview.1
    $envUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/distributedtask/environments?api-version=6.1-preview.1"
    $allEnvs = Invoke-RestMethod -Uri $envUri -Method Get -Headers $authorization -Verbose
    Write-Host $allEnvs.count
    Write-Output "" | Out-File $outFile 

    # environments to report on null = all
    IF (![string]::IsNullOrEmpty($EnvToReport)) 
    {
        $envMain = $allEnvs.value | Where-Object {$_.name -eq $EnvToReport }
    }
    else
    {
        $envMain = $allEnvs.value 
    }

    foreach ($Env in $envMain)
    {
        Write-Output "" | Out-File $outFile -Append
        Write-Output "Environment : " $Env.name | Out-File $outFile -Append -NoNewline
        Write-Output "" | Out-File $outFile -Append

        # get individual environment with resources if available
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/environments/get?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments/{environmentId}?expands={expands}&api-version=6.1-preview.1
        $envUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/distributedtask/environments/" + $Env.id + "?expands=resourceReferences&api-version=6.1-preview.1"
        $EnvwResources = Invoke-RestMethod -Uri $envUri -Method Get -Headers $authorization -Verbose
        for ($r = 0; $r -lt $EnvwResources.resources.length; $r++) 
        {
            # get the resources for this environment
            switch ($EnvwResources.resources[$r].type )
            {
                "kubernetes" { 
                    # https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/kubernetes/get?view=azure-devops-rest-6.1
                    # GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments/{environmentId}/providers/kubernetes/{resourceId}?api-version=6.1-preview.1
                    $kubUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/distributedtask/environments/" + $Env.id + "/providers/kubernetes/" + $EnvwResources.resources[$r].id + "?api-version=6.1-preview.1"
                    $KubResource = Invoke-RestMethod -Uri $kubUrl -Method Get -Headers $authorization -Verbose
                    
                    Write-Output "     Resource: " $KubResource.name  " Type : " $KubResource.type | Out-File $outFile -Append -NoNewline
                    Write-Output "" | Out-File $outFile -Append

                 }

                 "virtualMachine" {

                 }

                 "virtualMachine"{

                 }

                 "generic"{

                 }

                 "undefined"{

                 }

                Default {}
            }
        }      

        # get environment deployment record - this is a list of deployments
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/environmentdeployment%20records/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments/{environmentId}/environmentdeploymentrecords?api-version=6.1-preview.1
        $envDepUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/distributedtask/environments/" + $Env.id + "/environmentdeploymentrecords?api-version=6.1-preview.1"
        $EnvDeps = Invoke-RestMethod -Uri $envDepUri -Method Get -Headers $authorization -Verbose

        Write-Output " Number of Deployments  :" $EnvDeps.count | Out-File $outFile -Append -NoNewline
        Write-Output "" | Out-File $outFile -Append

        foreach ($Deploy in $EnvDeps.value) 
        {
            $DepBuild = ""
            $BuildTimeLine = ""
            try
            {
                # get build in the deployments
                # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}?api-version=6.1-preview.6
                $DepBuildUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $deploy.owner.id + "?api-version=6.1-preview.6"
                $DepBuild = Invoke-RestMethod -Uri $DepBuildUri -Method Get -Headers $authorization -Verbose

                # get build timeline 
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/timeline/get?view=azure-devops-rest-6.1
                # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/timeline/{timelineId}?api-version=6.1-preview.2
                $BuildTimelineUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $deploy.owner.id + "/timeline?api-version=6.1-preview.2"
                $BuildTimeLine = Invoke-RestMethod -Uri $BuildTimelineUri -Method Get -Headers $authorization -Verbose
            }
            catch 
            {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Write-Host "Security Error : "  $ErrorMessage  " iTEM : " $FailedItem  " Build not found"
            }
           
            # filter timeline by stages,job,tasks, etc
            $tmStages = $BuildTimeLine.records | Where-Object { $_.type -eq "Stage" } | Sort-Object -Property order
            $tmJobs = $BuildTimeLine.records | Where-Object { $_.type -eq "Job" } | Sort-Object -Property order
            $tmTasks = $BuildTimeLine.records | Where-Object { $_.type -eq "Task" } | Sort-Object -Property order
            $tmPhase = $BuildTimeLine.records | Where-Object { $_.type -eq "Phase" } | Sort-Object -Property order

            $tmCheckPoint = $BuildTimeLine.records | Where-Object { $_.type -eq "CheckPoint" } | Sort-Object -Property order        
            $tmCpApproval = $BuildTimeLine.records | Where-Object { $_.type -eq "Checkpoint.Approval" } | Sort-Object -Property order
            $tmCpTaskChk = $BuildTimeLine.records | Where-Object { $_.type -match "Checkpoint.TaskCheck" } | Sort-Object -Property order

            # get stages
            # https://dev.azure.com/<ORG_NAME>/<PROJECT_NAME>/_build/results?buildId=1915&__rt=fps&__ver=2 
            #$stagesUrl = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_build/results?buildId=" + $deploy.owner.id + "&__rt=fps&__ver=2"
            #$stageResults = Invoke-RestMethod -Uri $stagesUrl -Method Get -Headers $authorization 
            #$stageList = $stageResults.fps.dataProviders.data.'ms.vss-build-web.run-details-data-provider'.stages
            
            Write-Host "   Deployment :" $Deploy.owner.name " on " $Deploy.definition.name " Status :" $DepBuild.status " Results : " $DepBuild.result
            Write-Host "        Stage : " $stg.name " Assigned approvers : " $appData.approvals.steps.length

            Write-Output "" | Out-File $outFile -Append            
            Write-Output "   Deployment :" $Deploy.owner.name " on " $Deploy.definition.name " Status :" $DepBuild.status " Results : " $DepBuild.result | Out-File $outFile -Append -NoNewline
            Write-Output "" | Out-File $outFile -Append

            # for each stage find the list of approvers and actual approvers using undocumented API found in f12 of portal
            foreach ($stg in $tmStages) 
            {
                $tmData =  @{
                    contributionIds =  @("ms.vss-build-web.checks-panel-data-provider");
                    dataProviderContext = @{
                        properties = @{
                            buildId =  $deploy.owner.id.ToString();
                            stageIds = $stg.id ;  
                            checkListItemType = 1;   
                            sourcePage = @{
                                url = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_build/results?buildId=" + $deploy.owner.id + "&view=results";
                                routeId = "ms.vss-build-web.ci-results-hub-route";
                                routeValues = @{
                                    project =  $userParams.ProjectName;
                                    viewname = "build-results";
                                    controller = "ContributedPage";
                                }
                            }                     
                        }
                    }
                }
                $acl = ConvertTo-Json -InputObject $tmData -depth 32
            
                # undocumented api call to get list of approvers for a given stage
                # https://dev.azure.com/fdx-strat-pgm/_apis/Contribution/HierarchyQuery/project/633b0ef1-c219-4017-beb0-8eb49ff55c35?api-version=5.0-preview.1
                $approvalURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/Contribution/HierarchyQuery/project/" + $Env.project.id + "?api-version=5.0-preview.1"
                $ApprlResults = Invoke-RestMethod -Uri $approvalURL -Method Post -Headers $authorization  -ContentType "application/json" -Body $acl

                # get the approval data
                $appData = $ApprlResults.dataproviders.'ms.vss-build-web.checks-panel-data-provider'
               
                Write-Output "        Stage : " $stg.name " Assigned approvers : " $appData.approvals.steps.length | Out-File $outFile -Append -NoNewline
                Write-Output "" | Out-File $outFile -Append

                # if approvals exist for this stage get them               
                foreach ($item in $appData.approvals.steps) {
                    Write-Host "    Assigned approver : "  $item.assignedApprover.displayName                  

                    IF (![string]::IsNullOrEmpty($item.actualApprover)) 
                    {
                        # if actual approver is not same as assigned approver 
                        if($item.actualApprover.displayName -ne $item.assignedApprover.displayName )
                        {
                            Write-Output "          Actual approver  : " $item.actualApprover.displayName " : on behalf of :" $item.assignedApprover.displayName " Date : " $item.lastModifiedOn  " Comment : " $item.comment | Out-File $outFile -Append -NoNewline
                            Write-Output "" | Out-File $outFile -Append    
                        }else
                        {
                            Write-Output "          Actual approver  : " $item.actualApprover.displayName " Date : " $item.lastModifiedOn  " Comment : " $item.comment | Out-File $outFile -Append -NoNewline
                            Write-Output "" | Out-File $outFile -Append                                
                        }

                    }
                    else
                    {
                        #Write-Output "         Assigned approver : "  $item.assignedApprover.displayName| Out-File $outFile -Append -NoNewline
                       # Write-Output "" | Out-File $outFile -Append
                    }
                }
            }

        }

    }

    # get list of pipelines
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/pipelines/list?view=azure-devops-rest-6.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/pipelines?api-version=6.1-preview.1
   # $pipelineUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/pipelines?api-version=6.1-preview.1"
   # $allPipelines = Invoke-RestMethod -Uri $pipelineUri -Method Get -Headers $authorization -Verbose
   # Write-Host $allPipelines.count

    # get all runs for a pipeline
    #foreach ($pipeline in $allPipelines.value)
    #{
        # get runs for a pipeline
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/runs/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/pipelines/{pipelineId}/runs?api-version=6.1-preview.1
    #    $runUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/pipelines/" + $pipeline.id + "/runs?api-version=6.1-preview.1"
    #    $allruns = Invoke-RestMethod -Uri $runUri -Method Get -Headers $authorization -Verbose
    #    Write-Host $allruns.count

    #    foreach ($run in $allruns.value) 
    #    {
    #        # get detail of a run 
    #        # https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/runs/get?view=azure-devops-rest-6.1
    #        # GET https://dev.azure.com/{organization}/{project}/_apis/pipelines/{pipelineId}/runs/{runId}?api-version=6.1-preview.1
    #        $runDetailUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/pipelines/" + $pipeline.id + "/runs/" + $run.id + "?api-version=6.1-preview.1"
    #        $runDetail = Invoke-RestMethod -Uri $runDetailUri -Method Get -Headers $authorization -Verbose
    #        Write-Host $runDetail.count
    #
    #    }
    #
    #           
    #}


}

function Get-ReleaseNotesByBuildByTag()
{
    #
    # this function will find all builds with the given tags in the workitems and generate release
    # notes for each build
    #
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $outFile
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
   
    #build table array - list of all builds for this release
    $buildTableArray = @()

    # array for changes to a given build
    $buildChangesArray = @()

    # array for artifacts to a given build
    $buildArtifactArray = @()

    # set log directory
    $runLog = $userParams.DirRoot + $userParams.LogDirectory + "runLog.txt"    

    $now = get-Date
    # if Yes write to file on hard disk. else this may be an automated run and no output required
    if($userParams.OutPutToFile -eq "Yes")
    {
        Write-Output "Run Started :" $now | Out-File $runLog -NoNewline
        Write-Output ""  | Out-File $runLog -Append

        Write-Output "   Run Filters: "  | Out-File $runLog -Append    
        if( $userParams.BuildTags -ne "")
        {
            Write-Output "   Build tags to Include     : "   | Out-File $runLog -Append -NoNewline
            Write-Output $userParams.BuildTags  | Out-File $runLog -Append -NoNewline
            Write-Output ""  | Out-File $runLog -Append
        }

        if($userParams.WorkItemTypes -ne "")
        {
            Write-Output "   Work Item Types to Include: "   | Out-File $runLog -Append -NoNewline
            foreach( $br in $userParams.WorkItemTypes  )
            {
                Write-Output $br " | "  | Out-File $runLog -Append -NoNewline
            }
            Write-Output ""  | Out-File $runLog -Append
        }

        if($userParams.BuildResults -ne "")
        {
            Write-Output "   Results to Include        : "   | Out-File $runLog -Append -NoNewline
            foreach( $br in $userParams.BuildResults  )
            {
                Write-Output $br " | "  | Out-File $runLog -Append -NoNewline
            }
            Write-Output ""  | Out-File $runLog -Append
        }
        else
        {
            Write-Output "   Results to Include: All results included"   | Out-File $runLog -Append -NoNewline
            Write-Output ""  | Out-File $runLog -Append
        }
    
        Write-Output ""  | Out-File $runLog -Append
    }

    # Get a list of all builds with a specific tag
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/list?view=azure-devops-rest-6.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds?definitions={definitions}&queues={queues}&buildNumber={buildNumber}&minTime={minTime}&maxTime={maxTime}&requestedFor={requestedFor}&reasonFilter={reasonFilter}&statusFilter={statusFilter}&resultFilter={resultFilter}&tagFilters={tagFilters}&properties={properties}&$top={$top}&continuationToken={continuationToken}&maxBuildsPerDefinition={maxBuildsPerDefinition}&deletedFilter={deletedFilter}&queryOrder={queryOrder}&branchName={branchName}&buildIds={buildIds}&repositoryId={repositoryId}&repositoryType={repositoryType}&api-version=6.1-preview.6
    $AllBuildswithTags = New-Object System.Collections.ArrayList
    $AllBuildswithTags = [System.Collections.ArrayList]::new()    
    foreach ($tag in $userParams.BuildTags) 
    {
        $AllBuildsUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds?tagFilters=" + $tag + "&api-version=6.1-preview.6"     
        $BuildswithTags = Invoke-RestMethod -Uri $AllBuildsUri -Method Get -Headers $authorization 
        $AllBuildswithTags += $BuildswithTags
    } 

    Write-Host "Builds found :" $AllBuildswithTags.count

    # if Yes write to file on hard disk. else this may be an automated run and no output required
    if($userParams.OutPutToFile -eq "Yes")
    {
        Write-Output "" |  Out-File $runLog -Append 
        Write-Output "Builds found :" $AllBuildswithTags.count |  Out-File $runLog -Append -NoNewline
        Write-Output "" |  Out-File $runLog -Append 
    }

    # work items for all builds found
    $ReleaseWorkItems = New-Object System.Collections.ArrayList
    $ReleaseWorkItems = [System.Collections.ArrayList]::new()

    # loop thru each build in list found
    foreach ($build in $AllBuildswithTags.value) 
    {
        # get work all items for this build
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/get%20build%20work%20items%20refs?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/workitems?api-version=6.1-preview.2
        $workItemUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $build.id + "/workitems?api-version=6.1-preview.2"
        $allBuildWorkItems = Invoke-RestMethod -Uri $workItemUri -Method Get -Headers $authorization 
       
        Write-Host   "   Build Number:" $build.buildNumber " Build Definition :" $build.definition.name "  Results: " $build.result  " Status : " $build.status 
               
        # if Yes write to file on hard disk. else this may be an automated run and no output required
        if($userParams.OutPutToFile -eq "Yes")
        {
            Write-Output "" |  Out-File $runLog -Append 
            Write-Output "   Build Number:" $build.buildNumber " Build Definition :" $build.definition.name " Status: " $build.status " Results: " $build.result  " Build Tags: " $build.Tags |  Out-File $runLog -Append -NoNewline
            Write-Output "" |  Out-File $runLog -Append 
        }

        $buildTitle = $false
        $fndUserStory = $false

        $lm0 = 0
        $lm1 = 0
        $lm2 = 0
        $lm4 = 0
        
        # array of workitems to report on
        $ArrayList = New-Object System.Collections.ArrayList
        $ArrayList = [System.Collections.ArrayList]::new()
    
        # if Yes write to file on hard disk. else this may be an automated run and no output required
        if($userParams.OutPutToFile -eq "Yes")
        {
            Write-Output "     Raw Work Item Data - Number of workItems Found: " $allBuildWorkItems.count  |  Out-File $runLog -Append -NoNewline
            Write-Output "" |  Out-File $runLog -Append 
        }

        # loop thru all workitems get work items and find spacing for report
        foreach ($workItem in $allBuildWorkItems.value)
        {
            # get individual work item
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items/get%20work%20item?view=azure-devops-rest-6.1
            # GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?api-version=6.1-preview.3
            $BuildworkItemUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/wit/workitems/" + $workItem.id + "?$" + "expand=All&api-version=6.1-preview.3" 
            $WItems = Invoke-RestMethod -Uri $BuildworkItemUri -Method Get -Headers $authorization 
            
            $fld = $WItems.fields
            $tg = $fld.'System.Tags'

            $wkType = $fld.'System.WorkItemType'
            $wkAssignto = $fld.'System.AssignedTo'
            $wkState = $fld.'System.State'
            
            # add field to house work item type. this will allow sorting of workitems by type
            $WItems | Add-Member -MemberType NoteProperty -name "WorkItemType" -Value $wkType
            $WItems | Add-Member -MemberType NoteProperty -name "Version" -Value $build.buildNumber
            $WItems | Add-Member -MemberType NoteProperty -name "PipeLine" -Value $build.definition.name

            # save work items into an array to sort if tag was found
            $ArrayList.Add($WItems) | Out-Null
            Write-Host   " WorkItem ID:" $workItem.id " Version : "  $build.buildNumber.ToString()
         
            # for spacing
            if( $WItems.id.ToString().Length -gt $lm0 )
            {
                $lm0 =  $WItems.id.ToString().Length
            }
            if($wkState.length -gt $lm1 )
            {
                $lm1 =  $wkState.length
            }
            if($wkType.length -gt $lm2  )
            {
                $lm2 =  $wkType.length
            }
           
            if($wkAssignto.displayName.length -gt $lm4 )
            {
                $lm4 =  $wkAssignto.displayName.length
            }

            # if Yes write to file on hard disk. else this may be an automated run and no output required
            if($userParams.OutPutToFile -eq "Yes")
            {
                Write-Output "     ID :" $WItems.id "".PadRight(5 ," ") " Status :" $wkState "".PadRight(10 - $wkState.length ," ") " Type :" $wkType "".PadRight(15 - $wkType.length," ") " Assigned to:" $wkAssignto.displayName  "".PadRight(30 - $wkAssignto.displayName.Length, " ") " Title :" $fld.'System.Title' | Out-File $runLog  -Append -NoNewline                            
                Write-Output ""  | Out-File $runLog -Append
            }

        }

        #
        # get all changes for a given build       
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/get%20build%20changes?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/changes?api-version=6.1-preview.2
        $bldChangegUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $Build.id + "/changes?api-version=6.1-preview.2"
        $bldChanges = Invoke-RestMethod -Uri $bldChangegUri -Method Get -Headers $authorization 

         # if Yes write to file on hard disk. else this may be an automated run and no output required
         if($userParams.OutPutToFile -eq "Yes")
         {
            Write-Output ""  | Out-File $outFile -Append
            Write-Output "            Builds changes found for this build: " $bldChanges.count  | Out-File $outFile -Append -NoNewline
            Write-Output ""  | Out-File $outFile -Append
         }

        foreach ($bldChg in $bldChanges.value) 
        {
             # if Yes write to file on hard disk. else this may be an automated run and no output required
             if($userParams.OutPutToFile -eq "Yes")
             {
                Write-Output "            Build Change: " $bldChg.message " Date Changed : " $bldChg.timestamp   "   Changed by: " $bldChg.'author'.DisplayName| Out-File $outFile   -Append -NoNewline
                Write-Output ""  | Out-File $outFile -Append
                Write-Output ""  | Out-File $outFile -Append
             }

            $locationData = Invoke-RestMethod -Uri $bldChg.Location -Method Get -Headers $authorization 
            $loc = $locationData.remoteUrl.Replace(" ", "%20")

            $chg = New-Object -TypeName PSObject -Property @{
                BuildChange = $bldChg.message
                DateChanged = $bldChg.timestamp 
                ChangedBy = $bldChg.'author'.DisplayName   
                Location =   $loc
                type = $bldChg.type 
                Id = $bldChg.Id                    
            }
            $buildChangesArray += $chg

        }

        # get build stages
        # 
        # get build timeline 
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/timeline/get?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/timeline/{timelineId}?api-version=6.1-preview.2
        $BuildTimelineUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $build.id + "/timeline?api-version=6.1-preview.2"
        $BuildTimeLine = Invoke-RestMethod -Uri $BuildTimelineUri -Method Get -Headers $authorization -Verbose

        # get stages for this build
        $tmStages = $BuildTimeLine.records | Where-Object { $_.type -eq "Stage" } | Sort-Object -Property order 
        $buildStagesArray = @()

        foreach ($stages in $tmStages) 
        {
            $stg = New-Object -TypeName PSObject -Property @{
                stageName = $stages.name
                result = $stages.result
                startTime = $stages.startTime
                endTime = $stages.finishTime
                order = $stages.order
                type = $stages.type                     
            }
            $buildStagesArray += $stg            
        }

        # get code coverage for build
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/test/code%20coverage/get%20build%20code%20coverage?view=azure-devops-rest-6.0
        # GET https://dev.azure.com/{organization}/{project}/_apis/test/codecoverage?buildId={buildId}&flags={flags}&api-version=6.0-preview.1
        $codeCvgUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/test/codecoverage?buildId=" + $Build.id + "&api-version=6.0-preview.1"
        $codeCvgForBuild = Invoke-RestMethod -Uri $codeCvgUri -Method Get -Headers $authorization 
        foreach ($codeCv in $codeCvgForBuild.value)
        {
            Write-Host $codecv.length    
        }

        # get plan details
        #
        

        # get all artifacts for this build
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/artifacts/list?view=azure-devops-rest-6.0
        # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/artifacts?api-version=6.0
        $artifactUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $Build.id + "/artifacts?api-version=6.0"
        $allBuildartifacts = Invoke-RestMethod -Uri $artifactUri -Method Get -Headers $authorization 

        Write-Host "    Artifacts Found: " $allBuildartifacts.count 
        Write-host ""  
        
        foreach ($artifact in $allBuildartifacts.value) 
        {
            $stg = New-Object -TypeName PSObject -Property @{
                ArtifactName = $artifact.name 
                type = $res.type 
                                 
            }
            $buildArtifactArray += $stg            
        }
        
        try 
        {
            #get build report
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/report/get?view=azure-devops-rest-6.0
            # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/report?api-version=6.0-preview.2
            $buildReportUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $Build.id + "/report?api-version=6.0-preview.2"
            $buildReport = Invoke-RestMethod -Uri $buildReportUri -Method Get -Headers $authorization     

            $BuildRep = ConvertTo-Json -InputObject $buildReport -Depth 32
            Write-Host $BuildRep
        }
        catch 
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            # Write-Host "Security Error : " + $ErrorMessage + " iTEM : " + $FailedItem    
        }
        
        
        Write-Host $solution " - " $Sequence "- " $release    
        Write-Host "Build ID: " $build.id " - Build Number : " $build.buildNumber    
        Write-Host "    Build Status: " $build.Status " - Result: " $build.result
        $def = $build.definition
        $repo = $build.repository
        
        # get tags
        $buildTag = ""
        foreach ($tg in $build.tags) 
        {
            $buildTag += $tg + " "
        }

        # write build record table . this arraylist will hold all builds found
        # Solution = $Area.ToString()
        $bld = New-Object -TypeName PSObject -Property @{
            Status =  $build.Status
            tag = $buildTag
            Pipeline = $build.definition.name.ToString()
            RequestedBy =  $def.name 
            Started = $build.startTime 
            Finished = $build.finishTime
            Version = $build.buildNumber.ToString()
            Source = $build.sourceBranch 
            Repo = $repo.name
            BuildNumber =  $build.id.ToString()    
            BuildChanges = $buildChangesArray
            BuildStages = $buildStagesArray

        }
        $buildTableArray += $bld

        # to count work items associated with this build
        $workitemsReported = 0
        
        # if Yes write to file on hard disk. else this may be an automated run and no output required
        if($userParams.OutPutToFile -eq "Yes")
        {  
            # create release output file        
            $nme =  $build.definition.name -replace '[\W]','_' 
            $pth = $userParams.DirRoot + $userParams.ReleaseDir + $nme + " _" + $build.buildNumber + ".txt"
            $pth = $pth -replace ' ',''
            $outfile = $pth

            Write-Output "" | Out-File $outfile
        }

        # sort by url( work item type) decending
        $allBuildWorkItemsSorted =  $ArrayList | Sort-Object -Property WorkItemType -Descending
        
        # array list for build table
        $UserStoryList = New-Object System.Collections.ArrayList
        $UserStoryList = [System.Collections.ArrayList]::new()

        # if Yes write to file on hard disk. else this may be an automated run and no output required
        if($userParams.OutPutToFile -eq "Yes")
        {
            Write-Output "      Included in Release Notes " | Out-File $runLog -Append
        }

        # loop thru workitems again and display
        foreach ($workItem in $allBuildWorkItemsSorted)
        {
            # get individual work item from array list
            $WItems = $workItem
           
            $wiRel = $WItems.'relations'
            $fld = $WItems.fields

            $tg = $fld.'System.Tags'
            $EnvName = $fld.'Custom.Environment'

            $wkType = $fld.'System.WorkItemType'
            $wkState = $fld.'System.State'
            $wkAssignto = $fld.'System.AssignedTo'
            $origId =   $fld.'System.Id' 
          
            $noUserStory = ""
            $useRelWkItem = $false
            
            # if not user story find parent user story  "User Story", "Bug"
            if( !$userParams.WorkItemTypes.Contains($wkType) )
            {
                $relAted = $wiRel | Where-Object { ($_.rel -eq "System.LinkTypes.Related") -or ($_.rel -eq "System.LinkTypes.Hierarchy-Reverse")}
                Write-Host $relAted

                # find related (parent work items)
                if( ![string]::IsNullOrEmpty($relAted))
                {
                    foreach ($item in $relAted) 
                    {
                        # get individual work item
                        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items/get%20work%20item?view=azure-devops-rest-6.1
                        # GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?api-version=6.1-preview.3
                        $relworkItemUri = $item.url + "?$" + "expand=All&api-version=6.1-preview.3" 
                        $relWkItem = Invoke-RestMethod -Uri $relworkItemUri -Method Get -Headers $authorization 
                        
                        $fld = $relWkItem.fields
                        $wiType = $fld.'System.WorkItemType'

                        # if its one of the selected types add the relationship
                        if( $userParams.WorkItemTypes.Contains($wiType))
                        {
                            Write-Host $wiType " - " $build.definition.name
                            
                            # if Yes write to file on hard disk. else this may be an automated run and no output required
                            if($userParams.OutPutToFile -eq "Yes")
                            {
                                # for auditing. this will show origional task and the user story parent it found.
                                # output may have multiple tasks with same user story as many tasks can be associated to the same user story or parent
                                Write-Output ""  | Out-File $runLog -Append
                                Write-Output "      -->Origional ID :" $workItem.id "".PadRight(9 ," ") "Type :" $wkType "".PadRight(15," ")  | Out-File $runLog  -Append -NoNewline                            
                                Write-Output ""  | Out-File $runLog -Append

                                Write-Output "      -->Relation ID  :" $fld.'System.Id' "".PadRight(9 ," ") "Type :" $wiType "".PadRight(10," ")  "Relation :" $item.attributes.name  | Out-File $runLog  -Append -NoNewline                            
                                Write-Output ""  | Out-File $runLog -Append
                            }

                            # add field to house work item type. this will allow sorting of workitems by type
                            $relWkItem | Add-Member -MemberType NoteProperty -name "WorkItemType" -Value $wiType
                            $relWkItem | Add-Member -MemberType NoteProperty -name "Version" -Value $build.buildNumber.ToString()
                            $relWkItem | Add-Member -MemberType NoteProperty -name "PipeLine" -Value $build.definition.name

                            $fld = $relWkItem.fields
                            $tg = $fld.'System.Tags'
                            $EnvName = $fld.'Custom.Environment'
    
                            $wkType = $fld.'System.WorkItemType'
                            $wkState = $fld.'System.State'
                            $wkAssignto = $fld.'System.AssignedTo'
                            
                            $noUserStory = ""
                            $useRelWkItem = $true
                            $origId  =  $fld.'System.Id'
                            break 
                        }
                    }
                }
                else
                {
                    # task with no parent user story
                    $noUserStory = "***"    
                }
            }
                                    
            $def = $build.definition
            $repo = $build.repository

            if($buildTitle -eq $false )
            {
                $buildTitle = $true
                $l1 = $def.name.Trim().length - $build.buildNumber.Trim().length 
                $l2 = $build.startTime.Trim().length - $build.Status.Trim().length - 2
                $l3 = ( $def.name.Trim().length  + 13 + $build.startTime.Trim().length ) - $build.sourceBranch.Trim().length

                # if Yes write to file on hard disk. else this may be an automated run and no output required
                if($userParams.OutPutToFile -eq "Yes")
                {
                    Write-Output ""  | Out-File $outFile                             
                    Write-Output ""  | Out-File $outFile -Append
                    Write-Output "Build Number : " $build.buildNumber.Trim()  "".PadRight($l1," ") " Build Status: " $build.Status.Trim() "".PadRight($l2," ") " Result     : " $build.result  | Out-File $outFile   -Append -NoNewline
                    Write-Output ""  | Out-File $outFile -Append
                    Write-Output "Requested by : " $def.name.Trim() " Start Time: " $build.startTime.Trim()  " Finish Time: " $build.finishTime | Out-File $outFile   -Append -NoNewline
                    Write-Output ""  | Out-File $outFile -Append
                    Write-Output "Source Branch: " $build.sourceBranch.Trim() "".PadRight($l3," ")  " Repo       : " $repo.name  | Out-File $outFile   -Append -NoNewline
                    Write-Output ""  | Out-File $outFile -Append
                    Write-Output "Environment  : " $EnvName  | Out-File $outFile   -Append -NoNewline
                    Write-Output ""  | Out-File $outFile -Append

                    Write-Output " "  | Out-File $outFile -Append
                    Write-Output "     Work Items :"  | Out-File $outFile -Append -NoNewline
                    Write-Output " "  | Out-File $outFile -Append
                    Write-Output " "  | Out-File $outFile -Append
                    
                    if($lm2 -lt 0)
                    {
                        $lm2 = 3
                    }
                    # write to output ( build file)
                    Write-Output "      ID" "".PadRight($lm0," ") "Status" "".PadRight($lm1," ") "Type" "".PadRight($lm2," ") "Assigned to" "".PadRight($lm4," ") "Title" | Out-File $outFile   -Append -NoNewline                            
                    Write-Output " "  | Out-File $outFile -Append
                }

            }

            # for spacing "".PadRight($l0," ") this will pad right $l0 number of spaces
            $l0 = ($lm0 + 2) - $origId.ToString().length
            if($l0 -lt 0)
            {
                $l0 = $origId.ToString().length + 1
            }
            $l1 = ($lm1 + 6) - $wkState.length
            if($l1 -lt 0)
            {
                $l1 = $lm1
            }
            $l2 = ($lm2 + 4) - $wkType.length
            if($l2 -lt 0)
            {
                $l2 = $lm2
            }
            $l4 = ($lm4 + 11) - $wkAssignto.displayName.length
            if($l4 -lt 0)
            {
                $l4 = $lm4
            }
            
            $fndUserStory = $UserStoryList.Contains( $fld.'System.Id' )
            # if no user story found display it. this will avoid duplicate user stories in build results. multile tasks may be assiciated to same userstory
            if(!$fndUserStory)
            {
                # only bus and user stories
                if ($noUserStory -eq "")
                {
                    # add work it em to final list
                    if($useRelWkItem)
                    {
                        $ReleaseWorkItems.add($relWkItem) | Out-Null
                        $workitemsReported += 1
                    }else
                    {
                        $ReleaseWorkItems.add($workItem) | Out-Null
                        $workitemsReported += 1
                    }

                    # if Yes write to file on hard disk. else this may be an automated run and no output required
                    if($userParams.OutPutToFile -eq "Yes")
                    {
                        #write to output ( build file)
                        Write-Output "      " $origId  "".PadRight($l0," ")  $wkState "".PadRight($l1," ")  $wkType "".PadRight($l2," ")  $wkAssignto.displayName "".PadRight($l4," ")  $fld.'System.Title' | Out-File $outFile   -Append -NoNewline                            
                        Write-Output ""  | Out-File $outFile -Append

                        # write to log
                        Write-Output "      ID:" $origId  "".PadRight($l0," ") "Status:" $wkState "".PadRight($l1," ") "Type:" $wkType "".PadRight($l2," ") " Assigned to:" $wkAssignto.displayName "".PadRight($l4," ") " Title:" $fld.'System.Title' | Out-File $runLog   -Append -NoNewline                            
                        Write-Output ""  | Out-File $runLog -Append
                    }

                }
            }
           
            $UserStoryList.Add($fld.'System.Id') | Out-Null
        }

        # add count of workitems to report to summary. this will count all reported workitems for this build. 
        # note reported is user stories and bugs. all tasks are rolled up into userstories
        $buildTableArray[$buildTableArray.Length -1]  | Add-Member -MemberType NoteProperty -name "WorkItemCount" -Value $workitemsReported
        Write-Host $workitemsReported

    }

    # generate build release table
    $out = $userParams.DirRoot + $userParams.LogDirectory + $userParams.ReleaseFile
    Get-BuildReleaseTable -userParams $userParams -buildTableArray $buildTableArray -BuildTable $out -ReleaseWorkItems $ReleaseWorkItems

    $now = get-Date
    # if Yes write to file on hard disk. else this may be an automated run and no output required
    if($userParams.OutPutToFile -eq "Yes")
    {
        Write-Output ""  | Out-File $runLog -Append
        Write-Output ""  | Out-File $runLog -Append
        Write-Output "Run Ended :" $now | Out-File $runLog -Append -NoNewline
        Write-Output ""  | Out-File $runLog -Append
    }

    # return build and workitems to add to wiki
    $ReleaseArray = @()
       # write build record table and workitems  . this arraylist will hold all builds found and workitems
       $bld = New-Object -TypeName PSObject -Property @{
        Builds = $buildTableArray
        WorkItems = $ReleaseWorkItems
        Artifacts = $buildArtifactArray
    }
    $ReleaseArray += $bld
    return $ReleaseArray

}


function Get-BuildReleaseTable()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $buildTableArray,
        [Parameter(Mandatory = $true)]
        $BuildTable,
        [Parameter(Mandatory = $true)]
        $ReleaseWorkItems
    )

    # if Yes write to file on hard disk. else this may be an automated run and no output required
    if($userParams.OutPutToFile -eq "Yes")
    {
        #
        # display build release table
        #
        Write-Output "Build Table for Release : "  | Out-File $BuildTable 
        if($userParams.BuildTags -ne "")
        {
            Write-Output "        Build Release Tags: "  $userParams.BuildTags | Out-File $BuildTable -Append -NoNewline       
            Write-Output ""  | Out-File $BuildTable -Append
        }

        # write out build table
        Write-Output ""  | Out-File $BuildTable -Append
        Write-Output "Solution" "".PadRight(12 ," ") "Pipeline" "".PadRight(27 ," ")  "Sequence" "".PadRight(17 ," ") "Version     "  | Out-File $BuildTable -Append -NoNewline
        Write-Output ""  | Out-File $BuildTable -Append
        Write-Output ""  | Out-File $BuildTable -Append
        
        $buildTableArray = $buildTableArray | Sort-Object -Property PipeLine,Version -Descending 
        foreach ($item in $buildTableArray) 
        {       
            Write-Output $item.Solution  "".PadRight(20 - $item.Solution.length ," ")  $item.Pipeline "".PadRight(35 - $item.Pipeline.length ," ") $item.Sequence "".PadRight(25 - $item.Sequence.length ," ") $item.Version    | Out-File $BuildTable -Append -NoNewline
            Write-Output ""  | Out-File $BuildTable -Append
        }

        # get all work items sort by type and remove any duplicates @{Expression={$_.Minor} ;Descending=$true}, @{Expression={$_.Bugfix}; Descending=$true})
        $SortedItems = $ReleaseWorkItems | Sort-Object -Property PipeLine,Version,WorkItemType -Descending 
        Write-Output ""  | Out-File $BuildTable -Append
        Write-Output "Work Items associated with above builds"  | Out-File $BuildTable -Append
        Write-Output ""  | Out-File $BuildTable -Append
        Write-Output "   ID"  "".PadRight(6," ") "Pipeline" "".PadRight(27," ") "Version" "".PadRight(8 ," ")  "Type" "".PadRight(10," ")  "Title " | Out-File $BuildTable   -Append -NoNewline                            
        Write-Output ""  | Out-File $BuildTable -Append
        
        $lstVersion =""
        foreach ($workItem in $SortedItems)
        {
            if($lstVersion -ne $workItem.Version)
            {
                Write-Output ""  | Out-File $BuildTable -Append
            }

            $fld = $workItem.fields
            $wkType = $fld.'System.WorkItemType'
            $wkTitle = $fld.'System.Title'
            $origId  =  $fld.'System.Id'

            $tm1 = 8  - $origId.ToString().length 
            $tm2 = 35 - $workItem.PipeLine.length 
            $tm3 = 15 - $workItem.Version.length
            $tm5 = 15 - $wkType.length

            Write-Output "   " $origId "".PadRight($tm1," ") $workItem.PipeLine "".PadRight($tm2 ," ") $workItem.Version "".PadRight($tm3 ," ")  $wkType "".PadRight($tm5," ") $wkTitle | Out-File $BuildTable   -Append -NoNewline                            
            Write-Output ""  | Out-File $BuildTable -Append
            $lstVersion = $workItem.Version
        }
    }
}

function Get-BuildApprovers()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $build,
        [Parameter(Mandatory = $true)]
        $outFile

    )
    
    #
    # get approvals. first get timeline for this build
    #
    # get build timeline 
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/timeline/get?view=azure-devops-rest-6.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/timeline/{timelineId}?api-version=6.1-preview.2
    $BuildTimelineUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $build.id + "/timeline?api-version=6.1-preview.2"
    $BuildTimeLine = Invoke-RestMethod -Uri $BuildTimelineUri -Method Get -Headers $authorization -Verbose

    # get stages for this build
    $tmStages = $BuildTimeLine.records | Where-Object { $_.type -eq "Stage" } | Sort-Object -Property order -Descending
    
    Write-Output "" | Out-File $outFile -Append                
    Write-Output "     Approvals:" | Out-File $outFile -Append -NoNewline
    Write-Output "" | Out-File $outFile -Append

    # for each stage find the list of approvers and actual approvers using undocumented API found in f12 of portal
    foreach ($stg in $tmStages) 
    {
        $tmData =  @{
            contributionIds =  @("ms.vss-build-web.checks-panel-data-provider");
            dataProviderContext = @{
                properties = @{
                    buildId =  $build.id.ToString();
                    stageIds = $stg.id ;  
                    checkListItemType = 1;   
                    sourcePage = @{
                        url = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_build/results?buildId=" + $build.id + "&view=results";
                        routeId = "ms.vss-build-web.ci-results-hub-route";
                        routeValues = @{
                            project =  $userParams.ProjectName;
                            viewname = "build-results";
                            controller = "ContributedPage";
                        }
                    }                     
                }
            }
        }
        $acl = ConvertTo-Json -InputObject $tmData -depth 32
    
        # undocumented api call to get list of approvers for a given stage
        # https://dev.azure.com/fdx-strat-pgm/_apis/Contribution/HierarchyQuery/project/633b0ef1-c219-4017-beb0-8eb49ff55c35?api-version=5.0-preview.1
        $approvalURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/Contribution/HierarchyQuery/project/" + $build.project.id + "?api-version=5.0-preview.1"
        $ApprlResults = Invoke-RestMethod -Uri $approvalURL -Method Post -Headers $authorization  -ContentType "application/json" -Body $acl

        # get the approval data
        $appData = $ApprlResults.dataproviders.'ms.vss-build-web.checks-panel-data-provider'
    
        foreach ($stItem in $userParams.Stages) 
        {
            if($stItem -eq $stg.name )
            {
                # if approvals exist for this stage get them               
                foreach ($item in $appData.approvals.steps)
                {
                    Write-Host "    Assigned approver : "  $item.assignedApprover.displayName  
                    IF (![string]::IsNullOrEmpty($item.actualApprover) ) 
                    {
                        Write-Host "    Assigned approver : "  $item.assignedApprover.displayName   |  Out-File $runLog -Append -NoNewline
                        Write-Output "" |  Out-File $runLog -Append    
                        # if actual approver is not same as assigned approver 
                        if($item.actualApprover.displayName -ne $item.assignedApprover.displayName )
                        {
                            Write-Output "       Stage:" $stg.name " Approver:" $item.actualApprover.displayName " : on behalf of :" $item.assignedApprover.displayName " Date:" $item.lastModifiedOn  " Comment:" $item.comment| Out-File $outFile -Append -NoNewline
                            Write-Output "" | Out-File $outFile -Append    
                            
                            Write-Output "       Stage:" $stg.name " Approver:" $item.actualApprover.displayName " : on behalf of :" $item.assignedApprover.displayName " Date:" $item.lastModifiedOn  " Comment:" $item.comment| Out-File $runLog -Append -NoNewline
                            Write-Output "" | Out-File $runLog -Append   
                        }else
                        {
                            Write-Output "       Stage:" $stg.name " Approver:" $item.actualApprover.displayName " Date:" $item.lastModifiedOn  " Comment:" $item.comment | Out-File $outFile -Append -NoNewline
                            Write-Output "" | Out-File $outFile -Append     
                            
                            Write-Output "       Stage:" $stg.name " Approver:" $item.actualApprover.displayName " Date:" $item.lastModifiedOn  " Comment:" $item.comment | Out-File $runLog -Append -NoNewline
                            Write-Output "" | Out-File $runLog -Append    
                        }
                    }
                }
            }
        }
        
    }
}

function Get-BuildDetailsByProject(){
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $outFile,
        [Parameter(Mandatory = $false)]
        $FolderName
    )
    #
    # this function will list all builds in a given project
    #

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
    
    # get list of folders
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/folders/list?view=azure-devops-rest-6.0
    # GET https://dev.azure.com/{organization}/{project}/_apis/build/folders/{path}?api-version=6.0-preview.2
    $folderUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/folders?api-version=6.0-preview.2"
    $allFlders = Invoke-RestMethod -Uri $folderUri -Method Get -Headers $authorization -Verbose

    # filter by folder if needed
    if (![string]::IsNullOrEmpty($FolderName))
    {
        $allFolders = $allFlders.value | Where-Object { $_.path -match $FolderName}
    }
    else 
    {
        $allFolders = $allFlders.value
    }

    Write-Output "" $Folder.path  | Out-File $outFile 
    Write-Output "Orginization / Project:" $userParams.VSTSMasterAcct " / " $userParams.ProjectName | Out-File $outFile -Append -NoNewline

    # loop thru each folder and get build definitions
    foreach ($Folder in $allFolders) 
    {
        Write-Host "Folder : " $Folder.path 

        Write-Output ""  | Out-File $outFile -Append
        Write-Output "     Folder : " $Folder.path  | Out-File $outFile -Append -NoNewline
        Write-Output ""  | Out-File $outFile -Append

        # get list build definitions by folder
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/build/definitions?name={name}&repositoryId={repositoryId}&repositoryType={repositoryType}&queryOrder={queryOrder}&$top={$top}&continuationToken={continuationToken}&minMetricsTime={minMetricsTime}&definitionIds={definitionIds}&path={path}&builtAfter={builtAfter}&notBuiltAfter={notBuiltAfter}&includeAllProperties={includeAllProperties}&includeLatestBuilds={includeLatestBuilds}&taskIdFilter={taskIdFilter}&processType={processType}&yamlFilename={yamlFilename}&api-version=6.1-preview.7
        $folderUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/definitions?path=" +$Folder.path + "&includeAllProperties=true&includeLatestBuilds=true&api-version=6.1-preview.7"
        $AllDefinitions = Invoke-RestMethod -Uri $folderUri -Method Get -Headers $authorization 
              
        # get builds for each definition
        Write-Host "       Build Definitions found: " $AllDefinitions.count
        Write-Output "     Build Definitions Found : " $AllDefinitions.count  | Out-File $outFile -Append -NoNewline
        Write-Output "" | Out-File $outFile -Append        

        foreach ($BuildDef in $AllDefinitions.value) 
        {
            # get builds for each definition
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/list?view=azure-devops-rest-6.1
            # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds?definitions={definitions}&queues={queues}&buildNumber={buildNumber}&minTime={minTime}&maxTime={maxTime}&requestedFor={requestedFor}&reasonFilter={reasonFilter}&statusFilter={statusFilter}&resultFilter={resultFilter}&tagFilters={tagFilters}&properties={properties}&$top={$top}&continuationToken={continuationToken}&maxBuildsPerDefinition={maxBuildsPerDefinition}&deletedFilter={deletedFilter}&queryOrder={queryOrder}&branchName={branchName}&buildIds={buildIds}&repositoryId={repositoryId}&repositoryType={repositoryType}&api-version=6.1-preview.6
            $BuildUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds?definitions=" + $BuildDef.id + "&queryOrder=startTimeDescending&api-version=6.1-preview.6"
            $allBuilds = Invoke-RestMethod -Uri $BuildUri -Method Get -Headers $authorization 

            Write-Output "" | Out-File $outFile -Append        
            Write-Host $BuildDef.name 
            Write-Output "" | Out-File $outFile -Append
            Write-Output "         Build Definition : "  $BuildDef.name  "   Builds in definition : " $allBuilds.count | Out-File $outFile   -Append -NoNewline
            Write-Output ""  | Out-File $outFile -Append

            Write-Host "        Builds found by definition: " $allBuilds.count
            $latestCompleteBuildInfo = $BuildDef.latestCompletedBuild
            $latest = ""

            # get all work items associated to the build
            for ($b = 0; $b -lt $allBuilds.Count; $b++) {
                
                $build = $allBuilds.value[$b]
                
                # if latest build and we have already displayed the latest build skip
                if( $latestCompleteBuildInfo.id -eq $build.id -and $latest -ne "")
                {
                    continue
                }

                # find latest build and print it first
                if($latest -eq "" )
                {
                    $build = $allBuilds.value | Where-Object { $_.id -match $latestCompleteBuildInfo.id }
                    # if not found ie no latest build use next build in list
                    IF ([string]::IsNullOrEmpty($build))
                    {
                        $build = $allBuilds.value[$b]
                    }else 
                    {
                        Write-Output ""  | Out-File $outFile -Append
                        Write-Output "        ======> Latest Build <======" | Out-File $outFile -Append -NoNewline
                        $latest = $build.id
                    }
                }

                Write-Host "Build ID: " $build.id " - Build Number : " $build.buildNumber    
                Write-Host "    Build Status: " $build.Status " - Result: " $build.result
                $def = $build.definition
                $repo = $build.repository
                $allTags = $build.tags
                $allPlans = $build.plans
    
                Write-Output ""  | Out-File $outFile -Append
                Write-Output "        --->Build ID: " $build.id " - Build Number : " $build.buildNumber | Out-File $outFile -Append -NoNewline
                Write-Output ""  | Out-File $outFile -Append
                Write-Output "            Build Status: " $build.Status " - Result: " $build.result  | Out-File $outFile   -Append -NoNewline
                Write-Output ""  | Out-File $outFile -Append
                Write-Output "            Requested by: " $def.name " - Start Time: " $build.startTime  "  Finish Time: " $build.finishTime | Out-File $outFile   -Append -NoNewline
                Write-Output ""  | Out-File $outFile -Append
                Write-Output "            Source Branch: " $build.sourceBranch " Repo : " $repo.name  | Out-File $outFile   -Append -NoNewline
                Write-Output ""  | Out-File $outFile -Append
               
                # get build changes
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/get%20build%20changes?view=azure-devops-rest-6.1
                # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/changes?api-version=6.1-preview.2
                $bldChangegUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $Build.id + "/changes?api-version=6.1-preview.2"
                $bldChanges = Invoke-RestMethod -Uri $bldChangegUri -Method Get -Headers $authorization 

                Write-Output ""  | Out-File $outFile -Append
                Write-Output "            Builds changes found for this build: " $bldChanges.count  | Out-File $outFile -Append -NoNewline
                Write-Output ""  | Out-File $outFile -Append
                foreach ($bldChg in $bldChanges.value) 
                {
                    Write-Output "            Build Change: " $bldChg.message " Date Changed : " $bldChg.timestamp   "   Changed by: " $bldChg.'author'.DisplayName| Out-File $outFile   -Append -NoNewline
                    Write-Output ""  | Out-File $outFile -Append
                }
                Write-Output ""  | Out-File $outFile -Append

                # list all tags found
                for ($i = 0; $i -lt $allTags.length; $i++) {
                    Write-Output "                Tag : " $allTags[$i]  | Out-File $outFile   -Append -NoNewline
                    Write-Output ""  | Out-File $outFile -Append
                }
              
                # get code coverage for build
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/test/code%20coverage/get%20build%20code%20coverage?view=azure-devops-rest-6.0
                # GET https://dev.azure.com/{organization}/{project}/_apis/test/codecoverage?buildId={buildId}&flags={flags}&api-version=6.0-preview.1
                $codeCvgUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/test/codecoverage?buildId=" + $Build.id + "&api-version=6.0-preview.1"
                $codeCvgForBuild = Invoke-RestMethod -Uri $codeCvgUri -Method Get -Headers $authorization 
                foreach ($codeCv in $codeCvgForBuild.value)
                {
                    Write-Host $codecv.length    
                }

                # get plan details
                #
              

                # get all artifacts for this build
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/artifacts/list?view=azure-devops-rest-6.0
                # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/artifacts?api-version=6.0
                $artifactUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $Build.id + "/artifacts?api-version=6.0"
                $allBuildartifacts = Invoke-RestMethod -Uri $artifactUri -Method Get -Headers $authorization 

                Write-Host "    Build Artifacts : " $allBuildartifacts.count
                Write-Output "            Artifacts Found: " $allBuildartifacts.count | Out-File $outFile   -Append -NoNewline
                Write-Output ""  | Out-File $outFile -Append
                foreach ($artifact in $allBuildartifacts.value) 
                {
                    $res = $artifact.resource
                    Write-Output "            Artifacts Name: " $artifact.name "   Artifacts Type: "  $res.type | Out-File $outFile   -Append -NoNewline
                    Write-Output ""  | Out-File $outFile -Append                    
                }

                try 
                {
                    #get build report
                    # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/report/get?view=azure-devops-rest-6.0
                    # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/report?api-version=6.0-preview.2
                    $buildReportUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $Build.id + "/report?api-version=6.0-preview.2"
                    $buildReport = Invoke-RestMethod -Uri $buildReportUri -Method Get -Headers $authorization     

                    $BuildRep = ConvertTo-Json -InputObject $buildReport -Depth 32
                    Write-Host $BuildRep
                }
                catch 
                {
                    $ErrorMessage = $_.Exception.Message
                    $FailedItem = $_.Exception.ItemName
                    # Write-Host "Security Error : " + $ErrorMessage + " iTEM : " + $FailedItem    
                }
                
                # get work all itemsfor this build
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/get%20build%20work%20items%20refs?view=azure-devops-rest-6.1
                # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/workitems?api-version=6.1-preview.2
                $workItemUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $Build.id + "/workitems?api-version=6.1-preview.2"
                $allBuildWorkItems = Invoke-RestMethod -Uri $workItemUri -Method Get -Headers $authorization 
                
                Write-Host "            Work Items found in Build: " $allBuildWorkItems.count
                Write-Output "" | Out-File $outFile -Append
                Write-Output "             Work Items Found: " $allBuildWorkItems.count  | Out-File $outFile   -Append -NoNewline
                Write-Output "" | Out-File $outFile -Append

                # get individual work items assiciated to the build
                foreach ($workItems in $allBuildWorkItems.value) 
                {
                    # get individual work item
                    # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items/get%20work%20item?view=azure-devops-rest-6.1
                    # GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?api-version=6.1-preview.3
                    $BuildworkItemUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/wit/workitems/" + $workItems.id + "?api-version=6.1-preview.3" 
                    $WItems = Invoke-RestMethod -Uri $BuildworkItemUri -Method Get -Headers $authorization 
                    
                    $fld = $WItems.fields
                    $tg = $fld.'System.Tags'
                    
                    $cls = $fld.'Microsoft.VSTS.Common.ClosedBy'
                    $ast = $fld.'System.AssignedTo'

                    Write-Host "        Work Item : " $fld.'System.Title'    $cls.displayName 
                    
                    Write-Output "" | Out-File $outFile -Append
                    
                    if (![string]::IsNullOrEmpty($tg)) 
                    {
                        Write-Output "               Tag:" $tg " Work Item Id: " $WItems.id   "   Status : " $fld.'System.State'   "  Name : "  $fld.'System.Title' | Out-File $outFile   -Append -NoNewline
                        Write-Host $tg
                    }
                    else
                    {
                        Write-Output "               Work Item Id: " $WItems.id   "   Status : " $fld.'System.State'   "  Name : "  $fld.'System.Title' | Out-File $outFile   -Append -NoNewline
                    }

                    Write-Output "" | Out-File $outFile -Append
                    Write-Output "               Area Path : " $fld.'System.AreaPath' "  Iteration : " $fld.'System.IterationPath' | Out-File $outFile -Append -NoNewline
                    Write-Output "" | Out-File $outFile -Append
                    Write-Output "               Assigned To : " $ast.displayName  "  Type : " $fld.'System.WorkItemType' | Out-File $outFile -Append -NoNewline
                    Write-Output "" | Out-File $outFile -Append
                    Write-Output "               Closed by : " $cls.displayName   " Date Closed: " $fld.'Microsoft.VSTS.Common.ClosedDate' | Out-File $outFile -Append -NoNewline
                    Write-Output "" | Out-File $outFile -Append
                    Write-Output "               Origional Estimate : " $fld.'Microsoft.VSTS.Scheduling.OrigionalEstimate'   " Actual: " $fld.'Microsoft.VSTS.Scheduling.CompletedWork' | Out-File $outFile -Append -NoNewline
                    Write-Output "" | Out-File $outFile -Append
                }
                
            }


        }
           
        
    }
    
   

}

function Set-ReleaseNotesToWiKi()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $Data
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
    
    # get all wiki for given org
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/wikis/list?view=azure-devops-rest-6.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis?api-version=6.1-preview.2
    $wikiUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis?api-version=6.1-preview.2"
    $allWiki = Invoke-RestMethod -Uri $wikiUri -Method Get -Headers $authorization 

    # find wiki to publish to
    $wiki  = $allWiki.value | Where-Object { ($_.name -eq $userParams.PublishWiKi ) }
    Write-Host $wiki

    # create subpages if not exists
    # create a page under Release Notes 
    #                  Release number - this is the tags used in the build
    #      then add a page  "System Generated Release Notes" and add data to it.
    
    # Release Notes / Release number or tag
    $landingPg = $userParams.PublishParent + "/" + $userParams.BuildTags
        
    try 
    {  
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/pages/create%20or%20update?view=azure-devops-rest-6.1
        # PUT https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis/{wikiIdentifier}/pages?path={path}&api-version=6.1-preview.1
        $CreatePageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $wiki.Id + "/pages?path=" + $landingPg + "&api-version=6.1-preview.1" 
        $CreatePage = Invoke-RestMethod -Uri $CreatePageUri -Method Put -ContentType "application/json" -Headers $authorization  
        Write-Host $CreatePage
    }
    catch 
    {
        # page exists
        Write-Host "Page exists - Script terminated, Please review page " $landingPg    
        continue
    }

    # create project page in wiki
    # $landingPg = $userParams.PublishParent + "/" + $userParams.ProjectName # +  "/" + $userParams.PublishPagePrfx 

    try 
    {
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/pages/create%20or%20update?view=azure-devops-rest-6.1
        # PUT https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis/{wikiIdentifier}/pages?path={path}&api-version=6.1-preview.1
        $CreatePageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $wiki.Id + "/pages?path=" + $landingPg + "&api-version=6.1-preview.1" 
        $CreatePage = Invoke-RestMethod -Uri $CreatePageUri -Method Put -ContentType "application/json" -Headers $authorization  
        Write-Host $CreatePage
                        
    }
    catch {
        
    }

    # build content
    # sort by sequence number
    $contentData = "[[_TOC_]]" + $([char]13) + $([char]10) 

    # count number of changes
    $chgCount = 0
    foreach ($item in $Data.builds) 
    {
        $chgCount += $Data.Builds.BuildChanges.count
    }
      
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  "#Build Summary" + $([char]13) + $([char]10) 
    $contentData += "|Summary Item|Count" + $([char]13) + $([char]10) 
    $contentData += "|:---------|:---------|" + $([char]13) + $([char]10) 
    $contentData += "|" + "Builds in this Release" + "|" + $Data.builds.count + "|" + $([char]13) + $([char]10) 
    $contentData += "|" + "Builds Changes in this Release" + "|" + $chgCount + "|" + $([char]13) + $([char]10) 
    $contentData += "|" + "Work Items(user stories,bugs,features) in this release" + "|" + $Data.WorkItems.count + "|" + $([char]13) + $([char]10) 

    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  "#Build Details" + $([char]13) + $([char]10) 
    if($userParams.PublishBldNote -ne "")
    {
        $contentData +=   $userParams.PublishBldNote + $([char]13) + $([char]10) 
    }

    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 
    $contentData += "|Tag|Build|Pipeline|Requestor|Start|Finish|Source|Repo|Work Items|Changes" + $([char]13) + $([char]10) 
    $contentData += "|:---------|:---------|:---------|:---------|:---------|:---------|:---------|:---------|:---------|:---------|" + $([char]13) + $([char]10) 
    $buildBySeq = $Data.builds | Sort-Object -Property Solution,Sequence
    foreach ($item in $buildBySeq) 
    {
        $pjName = $userParams.ProjectName.Replace(" ","%20")
        $url =  "(" + $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $pjName + "/_build/results?buildid=" + $item.BuildNumber + "&view=results" + ")"
        $contentData += "|" + $item.tag + "|" + " [" + $item.Version + "]" + $url + " |"  +  $item.Pipeline + "|"  + $item.RequestedBy + "|" + $item.Started + "|" + $item.Finished + "|" + $item.Source + "|"  + $item.Repo + "|" + $item.WorkItemCount + "|" + $item.BuildChanges.Count + "|" + $([char]13) + $([char]10)         
    }

    # stages and approvers - later
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  "#Build Stages" + $([char]13) + $([char]10) 
    $contentData += $([char]13) + $([char]10) 
    $contentData += "|Build Link |Stage |Order|Status|" + $([char]13) + $([char]10) 
    $contentData += "|:---------|---------|---------|---------|---------|" + $([char]13) + $([char]10) 
    foreach ($bld in $Data.Builds) 
    {
        $pjName = $userParams.ProjectName.Replace(" ","%20")
        $url =  "(" + $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $pjName + "/_build/results?buildid=" + $bld.BuildNumber + "&view=results" + ")"
        foreach ($stage in $bld.BuildStages) 
        {
            $contentData += "|" + " [" + $bld.Version + "]" + $url + " |"  +  $stage.stageName + "|"  + $stage.order + "|" + $stage.result + "|" + $([char]13) + $([char]10)         
        }
    }

    
    # add work items 
    $contentData += $([char]13) + $([char]10) 
    $contentData += "#Work Items Associated in This Release" + $([char]13) + $([char]10) 
    if($userParams.PublishWKItNote -ne "")
    {
        $contentData +=   $userParams.PublishWKItNote + $([char]13) + $([char]10) 
    }

    $contentData += "|Id|Pipeline|Build|Type|Title|" + $([char]13) + $([char]10) 
    $contentData += "|:---------|:---------|---------:|---------:|:---------|" + $([char]13) + $([char]10) 
    foreach ($item in $Data.WorkItems) 
    {
        $pjName = $userParams.ProjectName.Replace(" ","%20")
        $url = "(" + $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $pjName + "/_workitems/edit/" + $item.id + ")"
        $contentData += "|" + " [" + $item.id + "]" + $url  + " |" + $item.Pipeline + "|" +  $item.Version +  "|" + $item.WorkItemType + "|"  + $item.fields.'System.Title' + "|" +$([char]13) + $([char]10) 
    }


     # add changes to build
     $contentData += $([char]13) + $([char]10) 
     $contentData += "#Changes Associated With each Build" + $([char]13) + $([char]10) 
     $contentData += "|Change|Build Link |Change|Changed By|Date Changed|" + $([char]13) + $([char]10) 
     $contentData += "|:---------|---------|---------|---------|---------|" + $([char]13) + $([char]10) 
     foreach ($item in $Data.Builds) 
     {
         $url =  "(" + $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $pjName + "/_build/results?buildid=" + $item.BuildNumber + "&view=results" + ")"
         foreach ($bldChg in $Data.Builds.BuildChanges) 
         {
             $chid = $bldChg.Id.substring($bldChg.Id.Length -7,7)
             $contentData += "|" + " [" + $chid + "]" + "(" + $bldChg.Location + ")" + " |" +  " [" + $item.Version + "]" + $url + " |" + $bldChg.BuildChange + "|" +  $bldChg.ChangedBy +  "|" + $bldChg.DateChanged + "|" + $([char]13) + $([char]10) 
         }
     }

    # add Artifacts section
    $contentData += $([char]13) + $([char]10) 
    $contentData += "#Artifacts in each Build" + $([char]13) + $([char]10) 
    if($userParams.PublishArtfNote -ne "")
    {
        $contentData +=   $userParams.PublishArtfNote + $([char]13) + $([char]10) 
    }
    $contentData += $([char]13) + $([char]10) 
    $contentData += "Artifacts" + $([char]13) + $([char]10) 
    $contentData += "|Name|Type|" + $([char]13) + $([char]10) 
    $contentData += "|:---------|:---------|" + $([char]13) + $([char]10)    
    
    foreach ($bldArt in $Data.buildArtifactArray) 
    {
        $chid = $bldChg.Id.substring($bldChg.Id.Length -7,7)
        $contentData += "|" + $bldChg.Name + "|" +  $bldChg.Type + "|" + $([char]13) + $([char]10) 
    }

    $contentData += $([char]13) + $([char]10) 
    $contentData += $([char]13) + $([char]10) 
        
    <# 
        $contentData += $([char]13) + $([char]10) 
        $contentData += "#Backout Plan" + $([char]13) + $([char]10) 
        $contentData += "|Solution|Pipeline|Sequence|Version|" + $([char]13) + $([char]10) 
        $contentData += "|:---------|:---------|:---------|:---------|" + $([char]13) + $([char]10)      
    #>

    $tmData = @{
         content  = $contentData
    }
    $tmJson = ConvertTo-Json -InputObject $tmData

    # get page version number to update must use Invoke-WebRequest to get e-tag. needed to do an update to the page
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/pages/get%20page?view=azure-devops-rest-6.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis/{wikiIdentifier}/pages?path=/SamplePage973&api-version=6.1-preview.1
    #
    # https://stackoverflow.com/questions/57056375/azure-devops-how-to-edit-wiki-page-via-rest-api
       
    # get wiki page to find etag
    #$landingPg = $userParams.PublishParent + "/" + $userParams.ProjectName + "/" + $userParams.PublishPagePrfx 
    $getPageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $wiki.Id + "/pages?path=" + $landingPg + "&recursionLevel=Full&api-version=6.1-preview.1"
    $GetPage = Invoke-WebRequest -Uri $getPageUri -Method Get -ContentType "application/json" -Headers $authorization -UseBasicParsing
    
    # add etag to the header. for update to work, must have etag in header
    # Base64-encodes the Personal Access Token (PAT) appropriately + etag used to allow update to wiki page
    Write-Host $GetPage.Headers.ETag
    $authorization =GetVSTSCredentialWithEtag -Token $userParams.PAT -userEmail $userParams.userEmail -eTag $GetPage.Headers.ETag

    # update or create page if it does not exist
    $AddPageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $wiki.Id + "/pages?path=" + $landingPg + "&api-version=6.1-preview.1"
    $AddPage = Invoke-RestMethod -Uri $AddPageUri -Method Put -ContentType "application/json" -Headers $authorization -Body $tmJson   

    Write-Host $AddPage

    # work on editting parts of the page
    # maybe find section in page and remove it and replace with new one?
    $pageJson = ConvertTo-Xml -InputObject $AddPage 
    Write-host $pageJson
    $secStart = $AddPage.IndexOf("#Build Stages")
    $secEnd = $AddPage.IndexOf("#Work Items Associated")

    $secReplace = ""
     # add Artifacts section
     $secReplace += $([char]13) + $([char]10) 
     $secReplace += "#Added new edit to Page" + $([char]13) + $([char]10) 
     if($userParams.PublishArtfNote -ne "")
     {
         $secReplace +=   $userParams.PublishArtfNote + $([char]13) + $([char]10) 
     }
     $secReplace += $([char]13) + $([char]10) 
     $secReplace += "Artifacts" + $([char]13) + $([char]10) 
     $secReplace += "|Name|Type|" + $([char]13) + $([char]10) 
     $secReplace += "|:---------|:---------|" + $([char]13) + $([char]10)    
     
     $sec = $AddPage

}


function Get-AllUSerMembership(){
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $outFile,
        [Parameter(Mandatory = $false)]
        $getAllProjects
    )

    #
    # this function will get a list of users from a given group using the identity api
    #

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # set output directory for data
    $outFile = $userParams.DirRoot + $userParams.SecurityDir + $outFile

    # get all teams in org. need to see if group is a team or group
    # GET https://dev.azure.com/{organization}/_apis/teams?api-version=6.1-preview.3
    $teamUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/teams?api-version=6.1-preview.3"
    $allTeams = Invoke-RestMethod -Uri $teamUri -Method Get -Headers $authorization 

    # find groups in all ado projects
    $projectUri = $userParams.HTTP_preFix  + "://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/groups?subjectTypes=vssgp&api-version=6.0-preview.1"
    $vssGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 

    $projectUri = $userParams.HTTP_preFix  + "://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/groups?subjectTypes=aadgp&api-version=6.0-preview.1"
    $aadGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 
   
    $allGroups = @()
    $allGroups += $vssGroups.value
   
    # find groups for the current project
    if($getAllProjects -ne "True"){
        $fnd = $allGroups | Where-Object {$_.principalName -match  $userParams.ProjectName }
    }else {
        $fnd = $allGroups 
    }

    # add in the aad groups
    $fnd += $aadGroups.value

    Write-Output 'Project|Group Name|Type|Relationship|User Name|Email Address|Alias ID' | Out-File -FilePath $outFile
    #Write-Output " " | Out-File -FilePath $outFile -Append 

    foreach ($item in $fnd) {
        # find group memberships frm identity api
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/ims/identities/read%20identities?view=azure-devops-rest-6.1#examples
        
        # search by name and get direct membership: need to use direct here and in the following query to get all direct members and member of
        # to mimic whats in ADO
        # GET https://vssps.dev.azure.com/fabrikam/_apis/identities?searchFilter=General&filterValue=jtseng@vscsi.us&queryMembership=None&api-version=6.1-preview.1
        #
        $grpMemberUrl = $userParams.HTTP_preFix  + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?searchFilter=General&filterValue="  + $item.principalName + "&queryMembership=direct&api-version=6.1-preview.1"
        $allGrpMembers = Invoke-RestMethod -Uri $grpMemberUrl -Method Get -Headers $authorization 

        Write-Host $item.principalName 

        # is this a team or group
        $prName = $item.principalName.Split('\')
        $projectName =  $prName[0].substring(1,$prname[0].length-2)
        $tm = $prName[1]

        $isTeam = $allTeams.value | Where-Object {($_.name -eq  $tm) -and ($_.projectName -eq $projectName)}
        $teamGroup = ""
        if ([string]::IsNullOrEmpty($isTeam)) 
        {
            $teamGroup = "Group"
        }else {
            $teamGroup = "Team"
        }

        if($allGrpMembers.value[0].members -ne 0)
        {        
            # get members this user is a member of
            foreach ($member in $allGrpMembers.value[0].memberOf ) {

                # now search by descriptor. sisnce we have all the direct members of the group  value[0].members
                $memberUrl = $userParams.HTTP_preFix  + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?descriptors="  + $member + "&queryMembership=direct&api-version=6.1-preview.1"            
                $curUser = Invoke-RestMethod -Uri $memberUrl -Method Get -Headers $authorization 
                                                    
                Write-Host $item.principalName 
                
                # get project name
                $prj1 = $item.principalName.SPlit('\')
                $prjName = $prj1[0].substring(1,$prj1[0].length-2)

                Write-Output $prjName"|" | Out-File -FilePath $outFile -Append -NoNewline                      
                Write-Output $item.displayName "|" | Out-File -FilePath $outFile -Append -NoNewline  
                Write-Output $teamGroup "|" | Out-File -FilePath $outFile -Append -NoNewline  
                Write-Output  "Member-Of|" | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output $curUser.value[0].providerDisplayName "|" | Out-File -FilePath $outFile -Append -NoNewline
                
                $email = $curUser.value[0].properties.Account.'$value'
                $fnd = $email | Select-String -Pattern '.com' -SimpleMatch
                IF ([string]::IsNullOrEmpty($fnd)) {
                    $email = " Group - No Email listed"
                }

                Write-Output $email "|" | Out-File -FilePath $outFile -Append -NoNewline 
                Write-Output $curUser.value[0].properties.DirectoryAlias.'$value' | Out-File -FilePath $outFile -Append -NoNewline 
                Write-Output " " | Out-File -FilePath $outFile -Append                   
            }   
            
            # get members this user is a direct member
            foreach ($member in $allGrpMembers.value[0].members ) {
                # now search by descriptor. sisnce we have all the direct members of the group  value[0].members
                $memberUrl = $userParams.HTTP_preFix  + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?descriptors="  + $member + "&queryMembership=direct&api-version=6.1-preview.1"            
                $curUser = Invoke-RestMethod -Uri $memberUrl -Method Get -Headers $authorization 
                
                # get list to additional memberships
                Write-Host $curUser.value[0].providerDisplayName
                Write-Host $item.principalName 

                # get project name
                $prj1 = $item.principalName.SPlit('\')
                $prjName = $prj1[0].substring(1,$prj1[0].length-2)
 
                Write-Output $prjName"|" | Out-File -FilePath $outFile -Append -NoNewline                      
                Write-Output $item.displayName "|" | Out-File -FilePath $outFile -Append -NoNewline  
                Write-Output $teamGroup "|" | Out-File -FilePath $outFile -Append -NoNewline  
                Write-Output  "Member|" | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output $curUser.value[0].providerDisplayName  "|" | Out-File -FilePath $outFile -Append -NoNewline
                
                $email = ""
                $email = $curUser.value[0].properties.Account.'$value'
                $fnd = $email | Select-String -Pattern '.com' -SimpleMatch
                IF ([string]::IsNullOrEmpty($fnd)) {
                    $email = " Group - No Email listed"
                }else 
                {
                    #GET https://vsaex.dev.azure.com/{organization}/_apis/userentitlements/{userId}?api-version=5.1-preview.2
                    ## get user info . need last access date, create date and license type
                    #$userUrl = "https://vsaex.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/userentitlements/"  + $curUser.value[0].id + "?api-version=6.0-preview.3"            
                    #$UserDetails = Invoke-RestMethod -Uri $userUrl -Method Get -Headers $authorization 
                }
                
                Write-Output $email "|" | Out-File -FilePath $outFile -Append -NoNewline 
                Write-Output $curUser.value[0].properties.DirectoryAlias.'$value' | Out-File -FilePath $outFile -Append -NoNewline 
                Write-Output " " | Out-File -FilePath $outFile -Append                     
            
            }   
        }
        else {
            
            # get project name
            $prj1 = $item.principalName.SPlit('\')
            $prjName = $prj1[0].substring(1,$prj1[0].length-2)

            Write-Output $prjName"|" | Out-File -FilePath $outFile -Append -NoNewline                      
            Write-Output $item.displayName "|" | Out-File -FilePath $outFile -Append -NoNewline  
            Write-Output $teamGroup "|" | Out-File -FilePath $outFile -Append -NoNewline  
            Write-Output  "Member|" | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output   "No Members Found|" | Out-File -FilePath $outFile -Append -NoNewline            
            Write-Output  "|" | Out-File -FilePath $outFile -Append -NoNewline 
            Write-Output " " | Out-File -FilePath $outFile -Append                     
        
        }
    }


}


function Get-GroupInfo() {
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $groupname
    )
    
    try {
        
        # Base64-encodes the Personal Access Token (PAT) appropriately
        $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

        # find groups
        $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/groups?api-version=4.0-preview"
        $allGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 
    
        $fnd = $allGroups.value | Where-Object {$_.displayName -eq $groupname }
        IF (![string]::IsNullOrEmpty($fnd)) {
           if($fnd.LongLength -ne 1)
           {
               foreach($item in $fnd)
               {
                   if($item.principalName -eq "[" + $userParams.ProjectName + "]\" + $groupname)
                   {
                       return $item;
                   }
               }
           }
            return $fnd;
        }

    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}

function ListGitBranches(){

    # this function will list the GIT repos
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        $outFile
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

     try {
             
        # find git repo
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/list?view=azure-devops-rest-5.0
        # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=5.0
        $listProviderURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories?api-version=5.0"
        $repo = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 
        
        Write-Output "  " | Out-File -FilePath $outFile 
        Write-Output $repo.count " Repositories found for Project : "  $userParams.ProjectName | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
       
        foreach ($rp in $repo.value) 
       {
            Write-Output "  " | Out-File -FilePath $outFile -Append
           
            try {
                
                # find branches for given repo
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/refs/list?view=azure-devops-rest-5.0
                # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/refs?api-version=5.0
                $listProviderURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories/" + $rp.Id + "/refs?api-version=5.0"
                $branchlist = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 

                Write-Output "   Repository Name :  " $rp.name " , Branches found : " $branchlist.count | Out-File -FilePath $outFile -Append -NoNewline

                foreach ($item in $branchlist.value) {
                    Write-Host "Branch : " $item.name 
                    Write-Output "  " | Out-File -FilePath $outFile -Append
                    Write-Output '    Branch : ' $item.name  ' -- Creator: ' $item.creator.displayName| Out-File -FilePath $outFile -Append -NoNewline
                }  
                Write-Output "  " | Out-File -FilePath $outFile -Append

            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
            }          
       }
        
    
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
       
}

function AddGitBranchFromMaster(){

    # https://github.com/microsoft/azure-devops-dotnet-samples/tree/master/ClientLibrary/Samples/Git
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/refs/update%20refs?view=azure-devops-rest-5.0
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/refs/update%20refs?view=azure-devops-rest-5.0#create/update/delete_a_ref_by_repositoryid
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/source%20providers/list%20branches?view=azure-devops-rest-5.0
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/source%20providers/list%20repositories?view=azure-devops-rest-5.0

    # this function add a branch from the master branch
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $branchToCreate
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

     try {
             
        # find git repo
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/list?view=azure-devops-rest-5.0
        # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=5.0
        $listProviderURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories?api-version=5.0"
        $repo = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 
       
        try {
            
            # find branches for given repo
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/refs/list?view=azure-devops-rest-5.0
            # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/refs?api-version=5.0
            $URL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories/" + $repo.value[0].Id + "/refs?api-version=5.0"
            $branchlist = Invoke-RestMethod -Uri $URL -Method Get -ContentType "application/json" -Headers $authorization 

            # need the repo id of master to create or delete branches
            $Masterid  = ($branchlist.value | Where-Object {$_.name -eq "refs/heads/master"}).objectId
            Write-Host "Master repo " $Masterid

            # create new branch payload newObjectId is the Object id of the master branch
            # to add new branch, oldObjectid = 40 0's
            $payload = @( @{
                        name = $branchToCreate 
                        oldObjectId = "0000000000000000000000000000000000000000"
                        newObjectId = $Masterid                        
                     })    
            $tmJson = ConvertTo-Json -InputObject $payload   
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/refs/update%20refs?view=azure-devops-rest-5.0
            # POST https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/refs?api-version=5.0                     
            $newBranch = Invoke-RestMethod -Uri $URL -Method Post -ContentType "application/json" -Headers $authorization -Body $tmJson  
            
            $outData = ConvertTo-Json -InputObject $newBranch    
            Write-Host  $outData

        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
        }          
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
       
}

function DeleteGitBranchByPath(){

    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $branchPath
    )

    try {
        
            # Base64-encodes the Personal Access Token (PAT) appropriately
            $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

            # find git repo
            $listProviderURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories?api-version=5.0"
            $repo = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 
       
            # get master branch id
            $URL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories/" + $repo.value[0].Id + "/refs?api-version=5.0"
            $branchlist = Invoke-RestMethod -Uri $URL -Method Get -ContentType "application/json" -Headers $authorization 

            # need the repo id of master to create or delete branches
            $Masterid  = ($branchlist.value | Where-Object {$_.name -eq "refs/heads/master"}).objectId
            Write-Host "Master repo " $Masterid

            # delete branch  
            # newObjectid is 40 o's old Objectid is object id master branch
            $payload = @( @{
                name = $branchPath
                newObjectId = "0000000000000000000000000000000000000000"
                oldObjectId = $Masterid                     
            })    
            
            $tmJson = ConvertTo-Json -InputObject $payload
            $delBranch = Invoke-RestMethod -Uri $URL -Method Post -ContentType "application/json" -Headers $authorization -Body $tmJson  
          
            $outData = ConvertTo-Json -InputObject $delBranch    
            Write-Host  $outData

    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}

function CreateVSTSGitRepo() {
    Param(
        [Parameter(Mandatory = $true)]
        $userParams
    )
    
	# Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # get project id
    $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".VisualStudio.com/DefaultCollection/_apis/projects/" + $userParams.ProjectName +"?api-version=1.0"
    $return = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization 

    IF ([string]::IsNullOrEmpty($return)) {
        $projId = $return.id

        # create json body for request
        $repo = @{name = $userParams.RepositoryName
            project = @{id = $projId}
        }
        $tmJson = ConvertTo-Json -InputObject $repo

        # REST call to create Git Repo
        $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".VisualStudio.com/DefaultCollection/_apis/git/repositories?api-version=1.0"

        try {

            $return = Invoke-RestMethod -Uri $projectUri -Method Post -ContentType "application/json" -Headers $authorization -Body $tmJson
            return $return
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
        }
    }
    else {
        return $return
    }
}

function AddUsersToGroup() {
    Param(
        [Parameter(Mandatory = $true)]
        $vstsAccount,
        [Parameter(Mandatory = $true)]
        $userEmail,
        [Parameter(Mandatory = $true)]
        $GroupName,
        [Parameter(Mandatory = $true)]
        $authorization
    )

    #find Group descriptor
    $groupUri = $userParams.HTTP_preFix + "://" + $vstsAccount + ".vssps.visualstudio.com/_apis/graph/groups?api-version=4.0-preview"
    $returnValue = Invoke-RestMethod -Uri $groupUri -Method Get -ContentType "application/json" -Headers $authorization
    Write-Host $returnValue

}

function GetVSTSProcesses() {
    Param(
        $userParams ,
        $authorization
    )
   
    try {
        $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/process/processes?api-version=1.0"
        $returnValue = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization
        $id = ($returnValue.value).Where( {$_.name -eq $userParams.ProcessType})
        return $id.id
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
  
}

function GetVSTSCredential () {
    Param(
        $userEmail,
        $Token
    )

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $userEmail, $token)))
    return @{Authorization = ("Basic {0}" -f $base64AuthInfo)}
}


function GetVSTSCredentialWithEtag () {
    Param(
        $userEmail,
        $Token,
        $eTag
    )

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $userEmail, $token)))
    return @{Authorization = ("Basic {0}" -f $base64AuthInfo) 
            'If-Match' = $etag
            }
}

# Adds a single user to a single team project within the specified TFS Group
function Add-TfsGroupMemberToTeamProjectGroup {
    param(
        [string]$TeamProject,
        [string]$TeamProjectGroupName,
        [string]$User,
        [pscustomobject]$TeamFoundationUserId)

    # Retrieve the list of groups within this TFS Team Project
    $readScopedGroupsUri = "$($globaltfs.root_url)/$TeamProject/_api/_identity/ReadScopedGroupsJson?__v=5"
    $params = @{ Uri = $readScopedGroupsUri; Method = 'Get' }
    $response = invoke_rest $params
	
    $grp = (($response | Select -ExpandProperty identities) | Where { $_.FriendlyDisplayName -eq $TeamProjectGroupName -and $_.IdentityType -eq "group" })

    # If we find the group then add the user here
    if ($grp -ne $null) {
        Write-Host "Found requested group $($grp.DisplayName) with ID $($grp.TeamFoundationId)"
        Write-Host "Verifying we can add to this group"

        # Verify we can add members to this group by calling the "CanAddMemberToGroup" api
        $uri = "$($globaltfs.root_url)/$TeamProject/_api/_identity/CanAddMemberToGroup?__v=5&groupId=$($grp.TeamFoundationId)"
        $params = @{ Uri = $uri; Method = 'Get' }
        $workerResponse = invoke_rest $params
		
        if ($workerResponse.canEdit -eq $true) {
            # Double check and ensure the user is not already a member of this group by reading it's members with the "ReadGroupMembers" API
            Write-Host "'Add' is supported for this group"
            Write-Host "Verifying '$User' is not already a member of this group"
			
            $uri = "$($globaltfs.root_url)/$TeamProject/_api/_identity/ReadGroupMembers?__v=5&scope=$($grp.TeamFoundationId)&readMembers=true"
            $params = @{ Uri = $uri; Method = 'Get' }
            $workerResponse = invoke_rest $params

            # Iterate through results and see if we find our user
            $existingUser = (($workerResponse | Select -ExpandProperty identities)  | Where { $_.TeamFoundationId -eq $TeamFoundationUserId.TeamFoundationId })

            # If the user doesn't exist then let's add them
            if ($existingUser -eq $null) {
                # Create a FORM body to be sent by POST to the "AddIdentities" API with the retrieved '__RequestVerificationToken' **We NEED this token!!**
                Write-Host "User '$user' does not exist. Adding to group..."
                $uri = "$($globaltfs.root_url)/$TeamProject/_api/_identity/AddIdentities?__v=5"
                $body = @{ newUsersJson = "[] "; `
                        existingUsersJson = "[`"$($TeamFoundationUserId.TeamFoundationId)`"]"; `
                        groupsToJoinJson = "[`"$($grp.TeamFoundationId)`"]"; `
                        __RequestVerificationToken = "$($globalSessionTokens.Tokens.RequestVerificationToken)" 
                }

                $params = @{ Uri = $uri; Method = 'Post'; ContentType = "application/x-www-form-urlencoded"; WebSession = $globalSessionTokens.TfsSession }
                $params.Add("Body", $body)

                $workerResponse = invoke_rest_with_response $params
				
                # Verify the response we get back from the API call to ensure it was successful. If not then write out the response with errors
                $json = ConvertFrom-Json -InputObject $workerResponse
                if ($json -ne $null) {
                    if ($json.HasErrors -eq $true) {
                        Write-Error ($json | Format-Table | Out-String)
                    }
                    else {
                        Write-Host "Successfully added user '$user' to group '$($grp.DisplayName)' in project '$TeamProject'"
                    }
                }
                else {
                    Write-Error "Failed to add user '$user' to group '$($grp.DisplayName)' in project '$TeamProject'. Please verify the server error reported."
                }
            }
            else {
                Write-Warning "User '$User' already exists within group '$TeamProjectGroupName' in project '$TeamProject'"
            }
        }
        else {
            Write-Error "Adding is NOT supported for group '$($grp.DisplayName)' in team project '$TeamProject'"
        }
    }
    else {
        Write-Warning "Could not find group '$TeamProjectGroupName' in Team Project '$TeamProject'"
    }
}


##############################
#
# this function will create the tfssecurity.exe command to change permissions for a given group and area
#
##############################
function GetSecurityCMD_old()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        $area,
        $actionType,
        $groupName,
        $permission
    )
     
    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
   
    # get project id and then token
    $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"
    $allPrjects = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
    $fnd = $allPrjects.value | Where-Object {$_.name -eq $userParams.ProjectName}

    $tkn +=  "$" + "PROJECT:vstfs:///Classification/TeamProject/" + $fnd.id  

    # $tmData =  @{ token =$tkn ;
    #     inheritPermissions = "false";
    #     acesDictionary = @( @{
    #         descriptor = "Microsoft.TeamFoundation.Identity;" +  [guid]::NewGuid();
    #         allow = 1;
    #         deny = 0;           
    #     })    
    #   }

    # $acl = ConvertTo-Json -InputObject $tmData
    # $acl = $acl -replace """{}""", '{}'
    
    # find group in security namespaces
    # $secURL = " https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/securitynamespaces/00000000-0000-0000-0000-000000000000/?api-version=1.0"
    # $namespaces = Invoke-RestMethod -Uri $secURL -Method Get -Headers $authorization -ContentType "application/json" 
    # $fnd = $namespaces.value | Where-Object {$_.name -eq $area}

    # get access control lists for given area = what to secure ie project, build, etc
    # $nmURL = " https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/_apis/accesscontrollists/" + $fnd.namespaceId + "?api-version=1.0"
    # $sec = Invoke-RestMethod -Uri $nmURL -Method Get -Headers $authorization -ContentType "application/json" 

    # $js =ConvertTo-Json -InputObject $sec.value
    # Out-File -FilePath "C:\temp\projectacl.json"  -InputObject $js 

    #find project id
    # $projectUri = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"
    # $allPrjects = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
    # $fnd = $allPrjects.value | Where-Object {$_.name -eq $userParams.ProjectName}

    $pth = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\TFSSecurity.exe "
    $cmd = ""
    switch ($area) 
    {
        "Project" { $cmd += " /a+ Project " +  '"' + $tkn + '"'  } 
        "Build"   { $cmd += " /a+ Build " +  '"' + $tkn + '"' }
    } 

    # add action
    $cmd += " " +  $actionType 
   
    # add group to secure
    $cmd +=  " n:" + $([char]34) + "[" + $userParams.ProjectName + "]\" + $groupName + $([char]34) 
   
    # add permission  and collection
    $cmd += " $permission /collection:https://" + $userParams.VSTSMasterAcct + ".visualstudio.com"
    Write-Host $cmd

    Start-Process $pth -ArgumentList $cmd -NoNewWindow
    
}

function GetResources()
{

    Param(
        [Parameter(Mandatory = $true)]
        $FileName
      
    )

    Connect-AzureRmAccount     
    $rmResources = Get-AzureRmResource 

    Write-Output "Resource|Type|Resource Group|Subscription Id|Location" | Out-File $FileName  -NoNewline
    Write-Output "" | Out-File $FileName -Append

    foreach ($item in $rmResources) 
    {
        Write-Output $item.name "|" $item.ResourceType "|" $item.ResourceGroupName "|" $item.SubscriptionId "|" $item.Location | Out-File $FileName -Append -NoNewline
        Write-Output "" | Out-File $FileName -Append
    }


}

function Set-BuildDefinition()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        $repo
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
   
    # find queue
    $queueCreateUrl = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/" + $userParams.ProjectName + "/_apis/distributedtask/queues?api-version=3.0-preview.1"
    $createBuild = Invoke-RestMethod -Uri $queueCreateUrl -Method Get -Headers $authorization  -ContentType "application/json"  
    $prjid = ""

    # if not found create it
    IF ($createBuild.count -eq 0) {
        
        $qDef = @{
            name = "My Queue";
            pool = @{ id = 1};
        }
        $qdefJson = ConvertTo-Json -InputObject $qDef
        $createqueue = Invoke-RestMethod -Uri $queueCreateUrl -Method Post -Headers $authorization  -ContentType "application/json"  -Body $qdefJson
        $prjid = $createqueue.id
    }
    else {
        $queueId  = ($createBuild.value | Where-Object {$_.name -eq $userParams.AgentQueue}).id
    }
    

    # $buildDef = @{
    #     name = $userParams.BuildName;
    #     type = "build";
    #     id = 0;
    #     quality = "definition";
    #     queue =  @{ id =  $prjid };
    #     build =  @(@{ 
    #         enabled = "true";   
    #         continueOnError = "false";
    #         displayName = "Build solution **\\*.sln";
    #         task = @{ id = (New-Guid).Guid ; versionSpec = "*" };
            
    #         inputs =  @{
    #             solution = "**\\*.sln";
    #             msbuildArgs = "";
    #             platform = "$" + "(platform)";
    #             configuration = "$" + "(config)";
    #             clean = "false";
    #             restoreNugetPackages = "true";
    #             vsLocationMethod = "version";
    #             vsVersion = "latest";
    #             vsLocation = "";
    #             msbuildLocationMethod = "version";
    #             msbuildVersion = "latest";
    #             msbuildArchitecture = "x86";
    #             msbuildLocation = "";
    #             logProjectEvents = "true"}; 
    #         };
    #         @{ 
    #         enabled = "true";
    #         continueOnError = "false";
    #         displayName = "Test Assemblies **\*test*.dll;-:**\obj\**";
    #         task = @{ id = New-Guid  ; versionSpec = "*" };

    #         inputs =  @{
    #             testAssembly = "**\*test*.dll;-:**\obj\**";
    #             testFiltercriteria = "";
    #             runSettingsFile = "";
    #             codeCoverageEnabled = "true";
    #             otherConsoleOptions = "";
    #             vsTestVersion = "14.0";
    #             pathtoCustomTestAdapters = ""};
    #         }                       
    #     )
    #     repository = @{
    #         id = $repo.id;
    #         type = "tfsgit";
    #         name =  $userParams.RepositoryName;
    #         localPath = "$" + "(sys.sourceFolder)/MyGitProject";
    #         defaultBranch = "/master";
    #         url = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/" + $userParams.ProjectName + "/_git/" + $userParams.RepositoryName;
    #         clean = "false";
    #     }
    #     options = @(@{
    #         enabled = "true";
    #         definition = @{ id = "1"};
    #         };
    #         @{
    #             inputs = @{ parallel = "false"; multipliers = "[\config\platform\]";}
    #         }
    #         );
    #     variables = @{
    #         forceClean = @{ value = "false"; allowOverride = "true";};
    #         config = @{ value = "debug, release"; allowOverride = "true";};
    #         platform = @{value = "any cpu"; allowOverride = "true";};
    #     }
    #     triggers = @();
    #     comments = "My first build definition";
    # }

    $buildTasks =  @(@{ 
        enabled = "true";
        continueOnError = "false";
        displayName = "Build solution **\\*.sln";
        task = @{ id = (New-Guid).Guid ; versionSpec = "*" };
        
        inputs =  @{
            solution = "**\\*.sln";
            msbuildArgs = "";
            platform = "$" + "(platform)";
            configuration = "$" + "(config)";
            clean = "false";
            restoreNugetPackages = "true";
            vsLocationMethod = "version";
            vsVersion = "latest";
            vsLocation = "";
            msbuildLocationMethod = "version";
            msbuildVersion = "latest";
            msbuildArchitecture = "x86";
            msbuildLocation = "";
            logProjectEvents = "true"}; 
        };
        @{ 
        enabled = "true";
        continueOnError = "false";
        displayName = "Test Assemblies **\*test*.dll;-:**\obj\**";
        task = @{ id = New-Guid  ; versionSpec = "*" };

        inputs =  @{
            testAssembly = "**\*test*.dll;-:**\obj\**";
            testFiltercriteria = "";
            runSettingsFile = "";
            codeCoverageEnabled = "true";
            otherConsoleOptions = "";
            vsTestVersion = "14.0";
            pathtoCustomTestAdapters = ""};
        }                       
    )

    $buildDefinition = @{
        "name"       = $userParams.RepositoryName
        "type"       = "build"
        "quality"    = "definition"
        "queue"      = @{
            "id" =  $queueId
        }
        "process"      = $BuildTasks
        "repository" = @{
            "id"            = $repo.id
            "type"          = "tfsgit"
            "name"          =  $userParams.RepositoryName
            "defaultBranch" = "refs/heads/master"
            "url"           = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/" + $userParams.ProjectName + "/_git/" + $userParams.RepositoryName
            "clean"         = $false
        }
        "options"    = @(
            @{
                "enabled"    = $true
                "definition" = @{
                    "id" = (New-Guid).Guid
                }
                "inputs"     = @{
                    "parallel"  = $false
                    multipliers = '["config","platform"]'
                }
            }
        )
        "variables"  = @{
            "system.debug" = @{
                "value"         = $false
                "allowOverride" = $true
            }
            "BuildConfiguration"     = @{
                "value"         = "release"
                "allowOverride" = $true
            }
            "BuildPlatform"   = @{
                "value"         = "any cpu"
                "allowOverride" = $true
            }
        }
        "triggers"   = @()
    }

    $buildjson = ConvertTo-Json -InputObject $buildDefinition -Depth 42
    Write-Host $buildjson

    # create build definition
    $buildUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/" + $userParams.ProjectName + "/_apis/build/definitions?api-version=4.1-preview"
    $buildDef = Invoke-RestMethod -Uri $buildUri -Method Post -Headers $authorization  -ContentType "application/json"  -Body $buildjson
   
    Write-Host $buildDef


   
}

function Get-ResourceGroupBySubscription()
{
    #
    # this function will return the resource groups by azure subscriptions
    #
    Param(
        [Parameter(Mandatory = $true)]
        $userParams        
    )

    # connect to selected subscription
    Connect-AzureRmAccount -Subscription $userParams.Subscription

    $rg = Get-AzureRmResourceGroup
    $rgJson = ConvertTo-Json $rg
    Write-Host $rgJson
    
    $rd = Get-AzureRmRoleDefinition
    $rdJson = ConvertTo-Json $rd
    Write-Host $rdJson
    
    return $rg

}