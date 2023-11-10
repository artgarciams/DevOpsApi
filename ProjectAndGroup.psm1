#
# FileName : ProjectAndGroup.psm1
# Data     : 02/09/2018
# Purpose  : this module will create a project and groups for a project
#           This script is for demonstration only not to be used as production code
#
# last update 10/24/2023

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


function AddVSTSGroupAndUsers() {
    Param(
        [Parameter(Mandatory = $true)]
        $userParams 
    )
        ##############################
        #
        # doc : https://www.visualstudio.com/en-us/docs/integrate/api/graph/groups#create-a-group-at-the-account-level
        ##############################
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

function GetFirstRepoCommitDate()
{
     # this function will list the GIT repos
     Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $outFile
       
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

     # get list of all projects in org
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/_apis/projects?api-version=6.1-preview.4
        $listProJectsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects?api-version=7.1-preview.4"
        $AllProjects = Invoke-RestMethod -Uri $listProJectsUrl -Method Get -ContentType "application/json" -Headers $authorization 
        
        $projectList = @()

        foreach ($prj in $AllProjects.value) 
        {
            # get all repos in project
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/list?view=azure-devops-rest-7.1&tabs=HTTP
            # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=7.1-preview.1

            $listProjReposURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" +  $prj.name + "/_apis/git/repositories?api-version=7.1-preview.1"
            $PrjRepos = Invoke-RestMethod -Uri $listProjReposURL -Method Get -ContentType "application/json" -Headers $authorization 
                                   
            $AuditList = @()
            Write-Host $prj.name

            foreach ($repo in $PrjRepos.value) 
            {
                Write-Host "     Repo: " $repo.name  "   ID: " $repo.id
                try 
                {
                    if($repo.isDisabled -eq $false)
                    {
                        # get repo stats
                        # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/stats/get?view=azure-devops-rest-7.1&tabs=HTTP
                        # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/stats/branches?name={name}&api-version=7.1-preview.1
                        $listReposStatsURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" +  $prj.name + "/_apis/git/repositories/" + $repo.id + "/commits?api-version=7.1-preview.1"
                        $PrjRepoStats = Invoke-RestMethod -Uri $listReposStatsURL -Method Get -ContentType "application/json" -Headers $authorization 
                        
                        foreach ($st  in $PrjRepoStats.value) 
                        {
                            $stat = New-Object -TypeName PSObject -Property @{
                                commitId = $st.commitId
                                commitDate = $st.author.date
                                reponame = $repo.name
                                comment = $st.comment
                                project = $prj.name
                                prjlastUpdate = $prj.lastUpdateTime
                            }
                            $AuditList += $stat
                        }    
                    }
                }
                catch 
                {
                    $ErrorMessage = $_.Exception.Message      
                    Write-Host "Error in gettin commits : " + $ErrorMessage 
                    $stat = New-Object -TypeName PSObject -Property @{
                        commitId = " no commit found"
                        commitDate =  $prj.lastUpdateTime
                        comment = " no commit found"
                        reponame = $repo.name
                        project = $prj.name
                        prjlastUpdate = $prj.lastUpdateTime
                    }
                    $AuditList += $stat
                }

                # sort all commits by earilest commit date among all repos
                $AuditList = $AuditList  | Sort-Object -Property commitDate 
               

            }
            
            # add earilest commit
            $projectList += $AuditList[0]
            $AuditList = @()

            # get earilest commit date
           # $AuditList = $AuditList  | Sort-Object -Property commitDate 
            #$projectList += $AuditList[0]

            # if($AuditList[0].commitDate -ge "2022-01-01T00:00:00Z")
            # {
            #     $projectList += $AuditList[0]
            # }

        }    

         
          Write-Output "Project Name|First Commit Date|Repo Name|Last Update Date|Frrst Commit comment" | Out-File -FilePath $outFile

          foreach ($project in $projectList)                     
          {
              Write-Output $project.project "|" | Out-File -FilePath $outFile -Append -NoNewline  
              Write-Output $project.commitDate "|" | Out-File -FilePath $outFile -Append -NoNewline  
              Write-Output $project.reponame "|" | Out-File -FilePath $outFile -Append -NoNewline  
              Write-Output $project.prjlastUpdate "|" | Out-File -FilePath $outFile -Append -NoNewline  
              Write-Output $project.comment  | Out-File -FilePath $outFile -Append -NoNewline  
              Write-Output "  " | Out-File -FilePath $outFile -Append 

          }
            Write-Output "  " | Out-File -FilePath $outFile -Append
 
           Write-Host $projectList      
    

}

function ListAllProjectsAndRepos() {
    # this function will list the GIT repos
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $outFile
       
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

     # get list of all projects in org
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/_apis/projects?api-version=6.1-preview.4
        $listProJectsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects?api-version=7.1-preview.4"
        $AllProjects = Invoke-RestMethod -Uri $listProJectsUrl -Method Get -ContentType "application/json" -Headers $authorization 
        
        $projectList = @()

        foreach ($prj in $AllProjects.value) 
        {
            # get all repos in project
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/list?view=azure-devops-rest-7.1&tabs=HTTP
            # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=7.1-preview.1

            $listProjReposURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" +  $prj.name + "/_apis/git/repositories?api-version=7.1-preview.1"
            $PrjRepos = Invoke-RestMethod -Uri $listProjReposURL -Method Get -ContentType "application/json" -Headers $authorization 
                                   
            $AuditList = @()
            Write-Host $prj.name

            foreach ($repo in $PrjRepos.value) 
            {
                Write-Host "     Repo: " $repo.name  "   ID: " $repo.id
                try 
                {
                    if($repo.isDisabled -eq $false)
                    {

                    }
                    # get repo stats
                    # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/stats/get?view=azure-devops-rest-7.1&tabs=HTTP
                    # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/stats/branches?name={name}&api-version=7.1-preview.1
                    $listReposStatsURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" +  $prj.name + "/_apis/git/repositories/" + $repo.id + "/commits?api-version=7.1-preview.1"
                    $PrjRepoStats = Invoke-RestMethod -Uri $listReposStatsURL -Method Get -ContentType "application/json" -Headers $authorization 
                    
                    foreach ($st  in $PrjRepoStats.value) 
                    {
                        $stat = New-Object -TypeName PSObject -Property @{
                            commitId = $st.commitId
                            commitDate = $st.author.date
                            comment = $st.comment
                            project = $prj.name
                            prjlastUpdate = $prj.lastUpdateTime
                        }
                        $AuditList += $stat
                    }    
                }
                catch 
                {
                    $ErrorMessage = $_.Exception.Message      
                    Write-Host "Error in gettin commits : " + $ErrorMessage 
                    $stat = New-Object -TypeName PSObject -Property @{
                        commitId = " no commit found"
                        commitDate =  $prj.lastUpdateTime
                        comment = " no commit found"
                        project = $prj.name
                        prjlastUpdate = $prj.lastUpdateTime
                    }
                    $AuditList += $stat
                }

                # sort all commits by earilest commit date among all repos
                $AuditList = $AuditList  | Sort-Object -Property commitDate 
               

            }
            
            # add earilest commit
            $projectList += $AuditList[0]
            $AuditList = @()

            # get earilest commit date
           # $AuditList = $AuditList  | Sort-Object -Property commitDate 
            #$projectList += $AuditList[0]

            # if($AuditList[0].commitDate -ge "2022-01-01T00:00:00Z")
            # {
            #     $projectList += $AuditList[0]
            # }

        }    

         
          Write-Output "Project Name|First Commit Date|Last Update Date|Frrst Commit comment" | Out-File -FilePath $outFile

          foreach ($project in $projectList)                     
          {
              Write-Output $project.project "|" | Out-File -FilePath $outFile -Append -NoNewline  
              Write-Output $project.commitDate "|" | Out-File -FilePath $outFile -Append -NoNewline  
              Write-Output $project.prjlastUpdate "|" | Out-File -FilePath $outFile -Append -NoNewline  
              Write-Output $project.comment  | Out-File -FilePath $outFile -Append -NoNewline  
              Write-Output "  " | Out-File -FilePath $outFile -Append 

          }
            Write-Output "  " | Out-File -FilePath $outFile -Append
 
           Write-Host $projectList

            # &continuationToken={continuationToken}
            # # find git repo
            # # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/list?view=azure-devops-rest-6.1&tabs=HTTP
            # # GET repositories?includeLinks={includeLinks}&includeAllUrls={includeAllUrls}&includeHidden={includeHidden}&api-version=6.1-preview.1
            # $listProviderURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $prj.Name + "/_apis/git/repositories?api-version=6.1-preview.1"
            # $repo = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 
            
            # Write-Output "  " | Out-File -FilePath $outFile -Append
            # Write-Output $repo.count " Repositories found for Project : "  $prj.Name | Out-File -FilePath $outFile -Append -NoNewline
            # Write-Output "  " | Out-File -FilePath $outFile -Append
        
            # foreach ($rp in $repo.value) 
            # {
            #     Write-Output "  " | Out-File -FilePath $outFile -Append
            
            #     try {
                    
            #         # find branches for given repo
            #         # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/refs/list?view=azure-devops-rest-5.0
            #         # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/refs?api-version=5.0
            #         $listProviderURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" +  $prj.Name + "/_apis/git/repositories/" + $rp.Id + "/refs?api-version=5.0"
            #         $branchlist = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 

            #         Write-Output "   Repository Name :  " $rp.name " , Branches found : " $branchlist.count  | Out-File -FilePath $outFile -Append -NoNewline
            #         Write-Output "     Default Branch:  " $rp.defaultBranch " , Last Updated : " $rp.project.lastUpdateTime  | Out-File -FilePath $outFile -Append -NoNewline

            #         foreach ($item in $branchlist.value) {
            #             Write-Host "     Branch : " $item.name 
            #             Write-Output "  " | Out-File -FilePath $outFile -Append
            #             Write-Output '     Branch : ' $item.name  ' -- Creator: ' $item.creator.displayName| Out-File -FilePath $outFile -Append -NoNewline
            #         }  
            #         Write-Output "  " | Out-File -FilePath $outFile -Append

            #     }
            #     catch {
            #         $ErrorMessage = $_.Exception.Message
            #         $FailedItem = $_.Exception.ItemName
            #         Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
            #         Write-Output "   Repository Name :  " $rp.name " , Branches found : 0 "  | Out-File -FilePath $outFile -Append -NoNewline
            #         Write-Output "  " | Out-File -FilePath $outFile -Append
            #     }          
            # }
        
    

}

function ListGitBranches(){

    # this function will list the GIT repos
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        $outFile,
        $GetAllProjects
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

     try {
        
        Write-Output "  " | Out-File -FilePath $outFile 
        if($GetAllProjects -eq "yes")
        {
            # get list of all projects in org
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-6.1
            # GET https://dev.azure.com/{organization}/_apis/projects?api-version=6.1-preview.4
            $listProJectsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects?api-version=6.1-preview.4"
            $AllProjects = Invoke-RestMethod -Uri $listProJectsUrl -Method Get -ContentType "application/json" -Headers $authorization 
            
            foreach ($prj in $AllProjects.value) 
            {
                 # find git repo
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/list?view=azure-devops-rest-5.0
                # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=5.0
                $listProviderURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $prj.Name + "/_apis/git/repositories?api-version=5.0"
                $repo = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 
                
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output $repo.count " Repositories found for Project : "  $prj.Name | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
            
                foreach ($rp in $repo.value) 
                {
                    Write-Output "  " | Out-File -FilePath $outFile -Append
                
                    try {
                        
                        # find branches for given repo
                        # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/refs/list?view=azure-devops-rest-5.0
                        # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/refs?api-version=5.0
                        $listProviderURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" +  $prj.Name + "/_apis/git/repositories/" + $rp.Id + "/refs?api-version=5.0"
                        $branchlist = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 

                        Write-Output "   Repository Name :  " $rp.name " , Branches found : " $branchlist.count  | Out-File -FilePath $outFile -Append -NoNewline
                        Write-Output "     Default Branch:  " $rp.defaultBranch " , Last Updated : " $rp.project.lastUpdateTime  | Out-File -FilePath $outFile -Append -NoNewline

                        foreach ($item in $branchlist.value) {
                            Write-Host "     Branch : " $item.name 
                            Write-Output "  " | Out-File -FilePath $outFile -Append
                            Write-Output '     Branch : ' $item.name  ' -- Creator: ' $item.creator.displayName| Out-File -FilePath $outFile -Append -NoNewline
                        }  
                        Write-Output "  " | Out-File -FilePath $outFile -Append

                    }
                    catch {
                        $ErrorMessage = $_.Exception.Message
                        $FailedItem = $_.Exception.ItemName
                        Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
                        Write-Output "   Repository Name :  " $rp.name " , Branches found : 0 "  | Out-File -FilePath $outFile -Append -NoNewline
                        Write-Output "  " | Out-File -FilePath $outFile -Append
                    }          
                }
            }
        }
        else 
        {
            
            # find git repo
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/list?view=azure-devops-rest-5.0
            # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories?includeLinks={includeLinks}&includeAllUrls={includeAllUrls}&includeHidden={includeHidden}&api-version=6.0
            # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=5.0
            $listProviderURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories?includeLinks=True&includeAllUrls=True&includeHidden=True&api-version=6.0"
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


function GetSecurityCMD_old()
{
    ##############################
    #
    # this function will create the tfssecurity.exe command to change permissions for a given group and area
    #
    ##############################
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

function Get-ProjectMetrics()
{
    Param(
        [Parameter(Mandatory = $false)]
        $userParams
    )

    
    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
    
    # get list of project metrics
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/metrics/get-project-metrics?view=azure-devops-rest-5.0
    # GET https://dev.azure.com/{organization}/{project}/_apis/build/metrics/{metricAggregationType}?api-version=5.0-preview.1
    $listProJectsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" +  $userParams.ProjectName + "/_apis/build/metrics/daily?api-version=5.0-preview.1"
    $PrjMetricsDaily = Invoke-RestMethod -Uri $listProJectsUrl -Method Get -ContentType "application/json" -Headers $authorization 
    
    Write-Host $PrjMetricsDaily


}
function Get-AllAzureServices()
{
    Param(
        [Parameter(Mandatory = $false)]
        $outFile
    )

    #
    # this function will screen scrape the below site to find all azure categories, services within categories and doc url of service
    # https://www.altaro.com/msp-dojo/web-scraping-tool-for-msps/
    #

    $data = invoke-webrequest -uri "https://azure.microsoft.com/en-us/services/"

    $ServiceArray = @()
    $product = ""
    Write-Output "Category,Product,Preview,Url" | Out-File $outFile 

    foreach ($item in $data.ParsedHtml.all ) 
    {
        $preview = ""
        # product categories have a css class name of Product category   
        if($item.classname -eq "product-category")
        {
            $product = $item.innertext.Trim()          
        }

        # services have a class name of text-heading5 under the product categoty
        if ($item.classname -eq "text-heading5" )
        {
            # if "preview" in description this is a service in preview
            if($item.innerText.Contains("Preview") )
            {
                $preview = "Yes"
            }

            if (![string]::IsNullOrEmpty($outFile ) )
            {
                Write-Output $product | Out-File $outFile  -Append -NoNewline
                Write-Output "," $item.innerText.Trim() | Out-File $outFile  -Append -NoNewline
                Write-Output "," $preview  | Out-File $outFile  -Append -NoNewline
                Write-Output "," $item.children[0].href.Replace("about:","https://azure.microsoft.com").Trim() | Out-File $outFile  -Append -NoNewline
                Write-Output " " | Out-File $outFile  -Append 
            }
            
            Write-Host $product
            Write-Host "     - "  $item.innertext
            Write-Host "     - "  $item.children[0].href
            Write-Host " "
            
            $chg = New-Object -TypeName PSObject -Property @{
            Category = $product 
            Preview = $preview
            ServiceName = $item.innerText 
            URL = $item.children[0].href.Replace("about:","https://azure.microsoft.com")
            }
            
            $ServiceArray += $chg
        }
    
    }

    return $ServiceArray
    Write-Host "Done"

}

function Get-AllFields()
{
    Param(
        [Parameter(Mandatory = $false)]
        $userParams
    )

    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        

    # find all fields in work item type need to handle boolean and other fields
    # this is a list of all the fileds in the org
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/fields/get?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/wit/fields?api-version=7.1-preview.2
    $AllFieldsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + '/_apis/wit/fields?$expand=extensionFields&api-version=7.1-preview.2'
    $AllFields = Invoke-RestMethod -Uri $AllFieldsUrl -Method Get -Headers $authorization
    Write-Host $AllFields
    
    return $AllFields

}

function Get-AllFieldsWorkItemType()
{
    Param(
        [Parameter(Mandatory = $false)]
        $userParams,
      
        [Parameter(Mandatory = $true)]      
        $InheritedProcessName,

        [Parameter(Mandatory = $true)]      
        $wkItemName,

        [Parameter(Mandatory = $true)]      
        $OutputFile
    
    )

    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        

    # get all processes
    # GET https://dev.azure.com/{organization}/_apis/work/processes?api-version=7.1-preview.2
    $AllProcessesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes?api-version=7.1-preview.2"     
    $AllProcesses = Invoke-RestMethod -Uri $AllProcessesUrl -Method Get -Headers $authorization
    
    # find inherited process - process to copy
    $inheritProc =  $AllProcesses.value | Where-Object {$_.name -eq $InheritedProcessName}

    $AllWorkItemTypeUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $inheritProc.typeId + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'  
    $AllWorkItemTypes = Invoke-RestMethod -Uri $AllWorkItemTypeUrl -Method Get -Headers $authorization
    $WkItemType = $AllWorkItemTypes.value | Where-Object {$_.name -eq $wkItemName}

    # find all fields in work item type need to handle boolean and other fields
    # this is a list of all the fileds in the org
    $AllFields = Get-AllFields -userParams $userParams
    Write-Host $AllFields

    # initialize output file
    Write-Output "|Page|Group|Field Id|Description|Label|Allowed Values|Outcome" | Out-File -FilePath $OutputFile

    # loop thru all pages in layout
    foreach ($page in $WkItemType.layout.pages) 
    {
        Write-Host $page.label
        # loop thru all sections on each page
        foreach ($section in $page.sections) 
        {
            #Write-Host $section.id
            # loop thru all groups in each section
            foreach ($group in $section.groups) 
            {
                Write-Host $group.label
                # loop thru each control in each group
                foreach ($control in $group.controls) 
                {
                    $fld = $AllFields.value | Where-Object {$_.referenceName -eq $control.id }
                    Write-Host $fld.name

                    if(![string]::IsNullOrEmpty($fld) )
                    {
                        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work-item-types-field/get?view=azure-devops-rest-7.1
                        # GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitemtypes/{type}/fields/{field}?$expand={$expand}&api-version=7.1-preview.3
                        $FieldsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParameters.ProjectName + "/_apis/wit/workitemtypes/" + $WkItemType.referenceName + "/fields/" + $fld.referenceName + '?$expand=all&api-version=7.1-preview.3'
                        $FieldDetail = Invoke-RestMethod -Uri $FieldsUrl -Method Get -Headers $authorization
                       
                        Write-Output "|"  | Out-File -FilePath $OutputFile -Append -NoNewline
                        Write-Output $page.label "|" | Out-File -FilePath $OutputFile -Append -NoNewline
                        #Write-Output $section.id "|" | Out-File -FilePath $OutputFile -Append -NoNewline
                        Write-Output $group.label "|" | Out-File -FilePath $OutputFile -Append -NoNewline

                        Write-Output $fld.name  "|" | Out-File -FilePath $OutputFile -Append -NoNewline
                        Write-Output $fld.description  "|" | Out-File -FilePath $OutputFile -Append -NoNewline

                        Write-Output $fld.referenceName "|" | Out-File -FilePath $OutputFile -Append -NoNewline
                       # Write-Output $fld.type  | Out-File -FilePath $OutputFile -Append -NoNewline
                        
                        # add default values and picklist values
                        Write-Output "|"  | Out-File -FilePath $OutputFile -Append -NoNewline
                        if($FieldDetail.allowedValues.Count -gt 0)
                        {
                            foreach ($item in $FieldDetail.allowedValues)
                            {
                                Write-Output $item ","  | Out-File -FilePath $OutputFile -Append -NoNewline
                            }
                        }
                        else
                        {
                            Write-Output $fld.type  | Out-File -FilePath $OutputFile -Append -NoNewline
                        }
                        Write-Output "|"  | Out-File -FilePath $OutputFile -Append -NoNewline
                        Write-Output "" | Out-File -FilePath $OutputFile -Append 
                       
                    }

                }
            }
        }
    }

}


function CreateWorkItemFromFile()
{
    Param(
        [Parameter(Mandatory = $false)]
        $userParams,
      
        [Parameter(Mandatory = $true)]      
        $TargetProcessName,

        [Parameter(Mandatory = $true)]      
        $TargetWorkItemToCreate,

        [Parameter(Mandatory = $true)]      
        $WorkItemInputFile
    )

    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        

    # get all processes
    # GET https://dev.azure.com/{organization}/_apis/work/processes?api-version=7.1-preview.2
    $AllProcessesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes?api-version=7.1-preview.2"     
    $AllProcesses = Invoke-RestMethod -Uri $AllProcessesUrl -Method Get -Headers $authorization
     
    # find Target process - process to copy into
     $IntoProc =  $AllProcesses.value | Where-Object {$_.name -eq $TargetProcessName}
    
    # if process does not exist add it
    if([string]::IsNullOrEmpty($IntoProc) )
    {
        # create new process
        # POST https://dev.azure.com/{organization}/_apis/work/processes?api-version=7.1-preview.2
        $processJson = @{
            description  =  "New process added with PowerShell"
            name = $DestinationProcess
            parentProcessTypeId = $inheritProc.parentProcessTypeId
        }
        $newProcess = ConvertTo-Json -InputObject $processJson
        $newProcessesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes?api-version=7.1-preview.2"     
        $IntoProc = Invoke-RestMethod -Uri $newProcessesUrl -Method Post -ContentType "application/json" -Headers $authorization -Body $newProcess
    }

     # 
     # now load the process from json file
     $WrkItemFromFile = Get-Content -Raw -Path $WorkItemInputFile |ConvertFrom-Json

     #
     # rename workitme to name entered. one of the input values is name of work item so rename it here
     #
     $WrkItemFromFile.name = $TargetWorkItemToCreate
     Write-Output $WrkItemFromFile

    #
    # now confirm the work item to create does not exist  in process selected 
    #
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=7.1-preview.2
    $findWkProcessUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $IntoProc.typeId + "/workitemtypes" + '?$expand=layout&api-version=7.1-preview.2' 
    $findWkProcess = Invoke-RestMethod -Uri $findWkProcessUrl -Method Get -Headers $authorization 
    $fndWKItem = $findWkProcess.value | Where-Object {$_.name -eq $WrkItemFromFile.name }

    # new process work item type does not exist add it
    if([string]::IsNullOrEmpty($fndWKItem) )
    {
        # create work item type within new precess
        $workitemTypeJson = @{
            color = "f6546a"
            icon = "icon_airplane"
            description = "my powershell induced workitem type copied from json file"
            name = $TargetWorkItemToCreate
            isDisabled = $false       
        }
        # add work item
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/create?view=azure-devops-rest-7.1
        # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=7.1-preview.2
        $newWkJson = ConvertTo-Json -InputObject $workitemTypeJson
        $newWkItemsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $IntoProc.typeId + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'    
        $newWKItem = Invoke-RestMethod -Uri $newWkItemsUrl -Method Post -ContentType "application/json" -Headers $authorization -Body $newWkJson
    }
    
    #
    # now get list of all work items including the one we added if it did not exist
    # https://learn.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/get?view=azure-devops-rest-7.2&tabs=HTTP
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes/{witRefName}?api-version=7.2-preview.2
    $AllWorkItemTypeUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $IntoProc.typeId  + '/workitemtypes?$expand=layout&api-version=7.2-preview.2'      
    $newWKItemList = Invoke-RestMethod -Uri $AllWorkItemTypeUrl -Method Get -Headers $authorization
    # find new work item type
    $newWKItem =  $newWKItemList.value | Where-Object {$_.name -eq $WrkItemFromFile.name}

    # 
    # now load the states from json file
    $statefile = $WorkItemInputFile.Replace(".json","-STATES.json")
    $StatesFromFile = Get-Content -Raw -Path $statefile |ConvertFrom-Json
    Set-StatesForWorkItem -userParams $userParams -inheritProc $IntoProc -proc $IntoProc -newWKItem $newWKItem  -WorkItemType  $newWKItem -StatesValueFromFile $StatesFromFile 

    # 
    # now load the rules from json file
    $ruleFile = $WorkItemInputFile.Replace(".json","-RULE.json")
    $GetRulesFromFile = Get-Content -Raw -Path $ruleFile |ConvertFrom-Json
    Set-RulesForWorkItem -userParams $userParams -IntoProc $IntoProc -newWKItem $newWKItem -GetRulesFromFile $GetRulesFromFile
 
      
}

function Set-RulesForWorkItem()
{
    #
    # this function will set the rulles for the custom work item type
    Param(
        [Parameter(Mandatory = $false)]
        $userParams,
      
        [Parameter(Mandatory = $true)]      
        $IntoProc,

        [Parameter(Mandatory = $true)]      
        $newWKItem,

        [Parameter(Mandatory = $true)]      
        $GetRulesFromFile

    )
    
    
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail       

    # if rules found add new rules
    if(![string]::IsNullOrEmpty($GetRulesFromFile) )
    {
        # find customized rules
        $fndCustomRules =  $GetRulesFromFile.value | Where-Object {$_.customizationType -eq 'custom'}
        Write-Host $fndCustomRules

        foreach ($rules in $fndCustomRules)
        {
            $jSonRules = ""
            
            # you need to get the condition and then the action for each rule
            $jSonRules = @{ name = $rules.name}
            $cond = @()   
            $act = @()           

            # first the condition
            foreach ($cd in $rules.conditions)
            {
                $cd1 = New-Object -TypeName PSObject -Property @{ conditionType = $cd.conditionType
                                   field = $cd.field
                                   value = $cd.value }
                $cond += $cd1
                $cd1 = $null
            }
            $jSonRules += @{ conditions = $cond}

            # now the action
            foreach ($ac in $rules.actions) 
            {
                $ac1 = New-Object -TypeName PSObject -Property @{ actionType = $ac.actionType
                    targetField = $ac.targetField
                    value = $ac.value }
                $act += $ac1
                $ac1 = $null
            }
            $jSonRules += @{ actions = $act}
            $jSonRules += @{isDisabled = $rules.isDisabled }

            $newRules = ConvertTo-Json -InputObject $jSonRules
            #
            # now add the rule to the new process
            # https://learn.microsoft.com/en-us/rest/api/azure/devops/processes/rules/add?view=azure-devops-rest-7.1&tabs=HTTP
            # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/rules?api-version=7.2-preview.2
            $AddRulesURL =  $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $IntoProc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/rules?api-version=7.2-preview.2"
            $AddRules = Invoke-RestMethod -Uri $AddRulesURL -Method Post -Headers $authorization -Body $newRules -ContentType "application/json"
            Write-Host $AddRules
        }        
    }
      
}

function Set-StatesForWorkItem()
{
    #
    # this function will set the states for the custom work item type
    Param(
        [Parameter(Mandatory = $false)]
        $userParams,
      
        [Parameter(Mandatory = $true)]      
        $inheritProc,
        
        [Parameter(Mandatory = $true)]      
        $proc,

        [Parameter(Mandatory = $true)]      
        $newWKItem,

        [Parameter(Mandatory = $true)]      
        $WorkItemType,

        [Parameter(Mandatory = $false)]
        $StatesValueFromFile
    )

    
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail       
    $getAllStates = $null

    if([string]::IsNullOrEmpty($StatesValueFromFile) )
    {
        # get states of work item to copy. this will be used to add states to new work item
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/states/list?view=azure-devops-rest-7.1
        # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/states?api-version=7.1-preview.1
        $getAllStatesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $inheritProc.typeId  + "/workitemtypes/" + $WorkItemType.referenceName + "/states?api-version=7.1-preview.1"
        $getAllStates = Invoke-RestMethod -Uri $getAllStatesUrl -Method Get -Headers $authorization
        Write-Host $getAllStates
    }
    else 
    {
        $getAllStates = $StatesValueFromFile
    }

    # loop thru states of work item to copy and add to new work item
    foreach ($state in $getAllStates.value) 
    {
        switch ($state.name )
        {
            # these are default states the system adds when creating a new workitem type
            # note for this may be different by process type ir scrum, agile.
            "New"    {  Write-Host "State " $state.name " Exists" }
            "Active" {  Write-Host "State " $state.name " Exists" }
            "Closed" {  Write-Host "State " $state.name " Exists" }
            Default 
            {
                $ddState = @{
                    name = $state.name
                    color = $state.color
                    stateCategory = $state.stateCategory
                # order = $state.order
                }
                $newState = ConvertTo-Json -InputObject $ddState
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/states/create?view=azure-devops-rest-7.1
                # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/states?api-version=7.1-preview.1
                $addStateUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/states?api-version=7.1-preview.1"
                $addState = Invoke-RestMethod -Uri $addStateUrl -Method Post -ContentType "application/json" -Headers $authorization -Body $newState
                Write-Host "Added State " $state.name " --- " $addState 
            }
        }
    }

    # now make sure all the states from the work item type to copy from are the same as the copy to
    # will remove any states not in the copy from 
    # get states of work item to copy. this will be used to add states to new work item

    # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/states/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/states?api-version=7.1-preview.1
    $getNewStatesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/states?api-version=7.1-preview.1"
    $NewStates = Invoke-RestMethod -Uri $getNewStatesUrl -Method Get -Headers $authorization
    Write-Host $NewStates

    foreach ($st in $NewStates.value) 
    {
        $fndState =  $getAllStates.value | Where-Object {$_.name -eq $st.name}
        
        # if not found in copy from work item delete it. WHen a work item get created it is given a few default states. If any are deleted in inherited process remove them in new
        if([string]::IsNullOrEmpty($fndState) )
        {
            # stat does not exist in copy from work item so it should be removed from copy to work item.
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/states/delete?view=azure-devops-rest-7.1
            # DELETE https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/states/{stateId}?api-version=7.1-preview.1
            $DelstateURL =  $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/states/" + $st.id + "?api-version=7.1-preview.1"
            $DelStates = Invoke-RestMethod -Uri $DelstateURL -Method Delete -Headers $authorization
            Write-Host "Deleted state " $st.name " from Work item to copy to" $DelStates
        }
    }


}

function SaveWorkItemtoFile()
{
    Param(
        [Parameter(Mandatory = $false)]
        $userParams,
      
        [Parameter(Mandatory = $true)]      
        $InheritedProcessName,

        [Parameter(Mandatory = $true)]      
        $WorkItemToSave,

        [Parameter(Mandatory = $true)]      
        $OutputFile

    )

    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        

    # get all processes
    # GET https://dev.azure.com/{organization}/_apis/work/processes?api-version=7.1-preview.2
    $AllProcessesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes?api-version=7.1-preview.2"     
    $AllProcesses = Invoke-RestMethod -Uri $AllProcessesUrl -Method Get -Headers $authorization
     
    # find inherited process - process to copy
     $inheritProc =  $AllProcesses.value | Where-Object {$_.name -eq $InheritedProcessName}
    
    # get work item types to copy to file
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=7.1-preview.2    
    $AllWorkItemTypeUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $inheritProc.typeId + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'      
    $AllWorkItemTypes = Invoke-RestMethod -Uri $AllWorkItemTypeUrl -Method Get -Headers $authorization

    $WorkItemType =  $AllWorkItemTypes.value | Where-Object {$_.name -eq $WorkItemToSave}

     # copy workitem to json file
     $jsonWrk = ConvertTo-Json -InputObject $WorkItemType -Depth 12
     Write-Output $jsonWrk | Out-File $OutputFile 

    # 
    # get list of all rules from work item to save
    # https://learn.microsoft.com/en-us/rest/api/azure/devops/processes/rules?view=azure-devops-rest-7.2
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/rules/{ruleId}?api-version=7.2-preview.2
    $GetRulesURL =  $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $inheritProc.typeId  + "/workitemtypes/" + $WorkItemType.referenceName + "/rules?api-version=7.2-preview.2"
    $GetRules = Invoke-RestMethod -Uri $GetRulesURL -Method Get -Headers $authorization
    Write-Host $GetRules

     # copy workitem to json file
     $jsonWrk = ConvertTo-Json -InputObject $GetRules -Depth 12
     $rulefile = $OutputFile.Replace(".json","-RULE.json")
     Write-Output $jsonWrk | Out-File $rulefile 

    # get states of work item to copy. this will be used to add states to new work item
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/states/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/states?api-version=7.1-preview.1
    $getAllStatesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $inheritProc.typeId  + "/workitemtypes/" + $WorkItemType.referenceName + "/states?api-version=7.1-preview.1"
    $getAllStates = Invoke-RestMethod -Uri $getAllStatesUrl -Method Get -Headers $authorization
    Write-Host $getAllStates

    $jsonWrk = ConvertTo-Json -InputObject $getAllStates -Depth 12
    $rulefile = $OutputFile.Replace(".json","-STATES.json")
    Write-Output $jsonWrk | Out-File $rulefile 
 
}

function Copy-ProcessAndWorkItemType()
{
    Param(
        [Parameter(Mandatory = $false)]
        $userParams,
      
        [Parameter(Mandatory = $true)]      
        $InheritedProcessName,

        [Parameter(Mandatory = $true)]      
        $DestinationProcess,

        [Parameter(Mandatory = $true)]      
        $WorkItemCopyFrom,

        [Parameter(Mandatory = $true)]      
        $WorkItemToCopy,

        [Parameter(Mandatory = $true)]      
        $OutputFile

    )

    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        

    # get all processes
    # GET https://dev.azure.com/{organization}/_apis/work/processes?api-version=7.1-preview.2
    $AllProcessesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes?api-version=7.1-preview.2"     
    $AllProcesses = Invoke-RestMethod -Uri $AllProcessesUrl -Method Get -Headers $authorization
    
    # find inherited process - process to copy
    $inheritProc =  $AllProcesses.value | Where-Object {$_.name -eq $InheritedProcessName}
    
    # see if new process exists
    $proc =  $AllProcesses.value | Where-Object {$_.name -eq $DestinationProcess}

    # if new process does not exist add it
    if([string]::IsNullOrEmpty($proc) )
    {
        # create new process
        # POST https://dev.azure.com/{organization}/_apis/work/processes?api-version=7.1-preview.2
        $processJson = @{
            description  =  "New process added with PowerShell"
            name = $DestinationProcess
            parentProcessTypeId = $inheritProc.parentProcessTypeId
        }
        $newProcess = ConvertTo-Json -InputObject $processJson
        $newProcessesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes?api-version=7.1-preview.2"     
        $proc = Invoke-RestMethod -Uri $newProcessesUrl -Method Post -ContentType "application/json" -Headers $authorization -Body $newProcess
    }

    #
    # now confirm new process work item exists if not add ite
    #
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=7.1-preview.2
    $findWkProcessUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId + "/workitemtypes" + '?$expand=layout&api-version=7.1-preview.2' 
    $findWkProcess = Invoke-RestMethod -Uri $findWkProcessUrl -Method Get -Headers $authorization 
    $newWKItem = $findWkProcess.value | Where-Object {$_.name -eq $WorkItemToCopy}

    # get work item types to inherit from
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=7.1-preview.2    
    $AllWorkItemTypeUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $inheritProc.typeId + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'      
    $AllWorkItemTypes = Invoke-RestMethod -Uri $AllWorkItemTypeUrl -Method Get -Headers $authorization
    $WorkItemType =  $AllWorkItemTypes.value | Where-Object {$_.name -eq $WorkItemCopyFrom}

    # copy workitem to json file
    $jsonWrk = ConvertTo-Json -InputObject $WorkItemType -Depth 12
    Write-Output $jsonWrk | Out-File $OutputFile 

    # new process work item type does not exist add it
    if([string]::IsNullOrEmpty($newWKItem) )
    {
        # create work item type within new precess
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/create?view=azure-devops-rest-7.1
        # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=7.1-preview.2
        $workitemTypeJson = @{
            color = "f6546a"
            icon = "icon_airplane"
            description = "my first powershell induced workitem type"
            name = $WorkItemToCopy
            isDisabled = $false       
        }
        # add work item
        $newWkJson = ConvertTo-Json -InputObject $workitemTypeJson
        $newWkItemsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'    
        $newWKItem = Invoke-RestMethod -Uri $newWkItemsUrl -Method Post -ContentType "application/json" -Headers $authorization -Body $newWkJson

        # now get list of all work items including the one we added
        $AllWorkItemTypeUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'      
        $newWKItemList = Invoke-RestMethod -Uri $AllWorkItemTypeUrl -Method Get -Headers $authorization
        
        # find new work item type
        $newWKItem =  $newWKItemList.value | Where-Object {$_.name -eq $WorkItemToCopy}

        # get states of work item to copy. this will be used to add states to new work item
        Set-StatesForWorkItem -userParams $userParams -inheritProc $inheritProc -proc $proc -newWKItem $newWKItem -WorkItemType $WorkItemType

    }

    # copy rules from inherited process to new process
    # get list of all rules from inherited process
    # https://learn.microsoft.com/en-us/rest/api/azure/devops/processes/rules?view=azure-devops-rest-7.2
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/rules/{ruleId}?api-version=7.2-preview.2
    $GetRulesURL =  $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $inheritProc.typeId  + "/workitemtypes/" + $WorkItemType.referenceName + "/rules?api-version=7.2-preview.2"
    $GetRules = Invoke-RestMethod -Uri $GetRulesURL -Method Get -Headers $authorization
    Write-Host $GetRules

    #
    # set the rules for the given workitem
    Set-RulesForWorkItem -userParams $userParams -IntoProc $proc -newWKItem $newWKItem -GetRulesFromFile $GetRules

    # get pages from new work item type. needed to add groups to page.
    # each page has 4 sections that arte created on page creation.they are situated left to right on page. section 4 i believe is hidden( not sure yet)
    $newPages = $newWKItem.layout.pages
  
    # find all fields in work item type need to handle boolean and other fields
    # this is a list of all the fileds in the org
    $AllFields = Get-AllFields -userParams $userParams
    Write-Host $AllFields

    # loop thru layout to copy and add pages  to new layout if they dont exist
    foreach ($Curritem in $WorkItemType.layout.pages) 
    {      
        $pgExists = $newPages | Where-Object {$_.label -eq $Curritem.label}

        # if page does not exists. add 
        if([string]::IsNullOrEmpty($pgExists))
        {
            # add page to work item and add all groups , fields and controls
            [pscustomobject]$addPage = @{
                    id = ""
                    label = $Curritem.label.Trim()   
                    order = $null
                    visible = $true
                    pageType = $null                                                      
                }    
            
            $secJson = ConvertTo-Json -InputObject $addPage
            $pageURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + '/layout/pages?api-version=7.1-preview.1'   
            $page = Invoke-RestMethod -Uri $pageURL -Method Post -ContentType "application/json" -Headers $authorization -Body $secJson
            Write-Host $page
        }
    }

    # refresh pages in new work item. when new process is created it has default pages. after we add pages need to get work item type again to get all new pages
    $AllWorkItemTypeUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'      
    $newWKItemList = Invoke-RestMethod -Uri $AllWorkItemTypeUrl -Method Get -Headers $authorization
    $newWKItem =  $newWKItemList.value | Where-Object {$_.name -eq $WorkItemToCopy}

    # get pages from new work item type. needed to add groups to page.
    # each page has 4 sections that arte created on page creation.they are situated left to right on page. section 4 i believe is hidden( not sure yet)
    $newPages = $newWKItem.layout.pages

    # loop thru inherited work item to copy to new work item
    foreach ($Curritem in $WorkItemType.layout.pages) 
    {      
        $pgExists = $newPages | Where-Object {$_.label.Trim() -eq $Curritem.label.Trim()}
        
        # if page exists. add groupd that are missing and add fileds to groups
        if($pgExists -ne $null)
        {
            # if inherited page is visible, add group info  if missing
            if($Curritem.visible -eq $true)
            {
                #  loop thru each section in inherited work item and then loop thru
                # each section in new work item and add groups to new work item if they are not there
                foreach ($currSection in $Curritem.sections) 
                {
                    # loop thru each new section and add groups as needed
                    foreach ($newSection in $pgExists.sections) 
                    {
                        # find inhertited section and go thru groups
                        if( $currSection.id -eq $newSection.id)
                        {                         
                            # loop thru each group in inherited page and add any group that does not exist
                            foreach ($grp in $currSection.groups) 
                            {
                                # special case if we rename system.description need to handle it this way
                                $newGrp = $null
                                $isMultiLine = $false
                                if($grp.controls[0].id -eq "System.Description")
                                {
                                    # does new group exist if its one of the default fields we need to look for them first
                                    $newGrp = $newSection.groups | Where-Object {$_.id -eq $grp.id}        
                                }
                                else
                                {
                                    # does new group exist if its one of the default fields we need to look for them first
                                    $newGrp = $newSection.groups | Where-Object {$_.label.Trim() -eq $grp.label.Trim()}    
                                    
                                        # multi line text fields cannot be inside a group. they are their own group on the UI
                                    if($grp.controls[0].controlType -eq "HtmlFieldControl")
                                    {
                                        $isMultiLine = $true

                                        # first add the field to the work item
                                        $addCtl = @{
                                                referenceName = $grp.controls[0].id
                                                order = "$null"
                                                readOnly = "$false"
                                                label = $grp.label.Trim()
                                                visible = "$true"

                                                # must encapsulate true false in quotes to register
                                                defaultValue = if($fld.type -eq "boolean"){"$false"}else {""}
                                                required = if($fld.type -eq "boolean"){"$true"}else {"$false"}                                                    
                                        }
                                        $ctlJSON = ConvertTo-Json -InputObject $addCtl

                                        # add field to work item type
                                        # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/fields/add?view=azure-devops-rest-7.1
                                        # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/fields?api-version=7.1-preview.2
                                        $field = $null
                                        $fieldURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemTypes/" + $newWKItem.referenceName + "/fields?api-version=7.1-preview.2"
                                        $field = Invoke-RestMethod -Uri $fieldURL -Method Post -ContentType "application/json" -Headers $authorization -Body $ctlJSON
                                        Write-Host $field
                                        
                                        # now add the Multi line field to the page in a group with no name 
                                        $addGroup = @{
                                            Contribution = "$null"    
                                            height = "$null"
                                            id = "$null"
                                            inherited = "$null"
                                            isContribution = "$false"
                                            label = $grp.label.Trim()
                                            visible = "$true"
                                            order = "$null"
                                            overridden = "$null"
                                            controls = @( @{
                                                contribution = "$null"
                                                controlType = "$null"
                                                height = "$null"
                                                id = $grp.controls[0].id
                                                inherited = "$null"
                                                isContribution = "$false"
                                                label = $grp.controls[0].label.Trim()
                                                metadata = "$null"
                                                order = "$null"
                                                overridden = "$null"
                                                visible = "$true"
                                                watermark = "$null"
                                            })
                                                                                        
                                        }
                                        $grpJSON = ConvertTo-Json -InputObject $addGroup
                                        # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups?api-version=7.1-preview.1
                                        $groupURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages/" + $pgExists.id + "/sections/" + $newSection.id + "/groups?api-version=7.1-preview.1"   
                                        $group = Invoke-RestMethod -Uri $groupURL -Method Post -ContentType "application/json" -Headers $authorization -Body $grpJSON
                                        Write-Host "Multi line field " $group
                                        $newGrp = $group

                                    }
                                }     

                                # if group does not exist add it
                                if([string]::IsNullOrEmpty($newGrp) -and $isMultiLine -eq $false )
                                {
                                    $addGroup = @{
                                        id = "$null"
                                        label = $grp.label.Trim()
                                        visible = "$true"
                                        isContribution = "$false"
                                        
                                    }
                                    $grpJSON = ConvertTo-Json -InputObject $addGroup

                                    # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups?api-version=7.1-preview.1
                                    $groupURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages/" + $pgExists.id + "/sections/" + $newSection.id + "/groups?api-version=7.1-preview.1"   
                                    $group = Invoke-RestMethod -Uri $groupURL -Method Post -ContentType "application/json" -Headers $authorization -Body $grpJSON
                                    Write-Host $group

                                    foreach ($grpCtl in $grp.controls) 
                                    {
                                        $fld = $AllFields.value | Where-Object {$_.referenceName -eq $grpCtl.id }
                                        if($fld.type -eq "html")
                                        {
                                            Write-Host $fld
                                        }

                                        # add controls to group 
                                        if($grpCtl.isContribution -eq $true)
                                        {
                                            $addCtl = @{  
                                                referenceName = $grpCtl.contribution.inputs.FieldName                                                    
                                                order = "$null"
                                                readOnly = "$false"
                                                inherited = $grpCtl.inherited
                                                label = $grpCtl.label.Trim()
                                                visible = "$true"

                                                # must encapsulate true false in quotes to register                                                
                                                required = if($grpCtl.controlType -eq "boolean"){"$true"}else {"$false"}  
                                                contribution = @{
                                                    contributionId = $grpCtl.contribution.contributionId
                                                    inputs = @{
                                                        FieldName =  $grpCtl.contribution.inputs.FieldName
                                                        Values = $grpCtl.contribution.inputs.Values
                                                    }
                                                }
                                                isContribution = "$true"
                                            }
                                        }
                                        else
                                        {
                                            $addCtl = @{
                                                referenceName = $grpCtl.id
                                                order = "$null"
                                                readOnly = "$false"
                                                label = $grpCtl.label.Trim()
                                                visible = "$true"
                                                # must encapsulate true false in quotes to register
                                                defaultValue = if($fld.type -eq "boolean"){"$false"}else {""}
                                                required = if($fld.type -eq "boolean"){"$true"}else {"$false"}                                                    
                                            }
                                        }
                                        $ctlJSON = ConvertTo-Json -InputObject $addCtl

                                        # add field to work item type
                                        # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/fields/add?view=azure-devops-rest-7.1
                                        # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/fields?api-version=7.1-preview.2
                                        $field = $null
                                        $fieldURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemTypes/" + $newWKItem.referenceName + "/fields?api-version=7.1-preview.2"
                                        $field = Invoke-RestMethod -Uri $fieldURL -Method Post -ContentType "application/json" -Headers $authorization -Body $ctlJSON
                                        Write-Host $field

                                        # add control to group. add the field to the control
                                        if($grpCtl.isContribution -eq $true)
                                        {
                                            $addCtl = @{

                                                # un documented when adding a contribution control it must have an ID. it has to be unique so i added a guid.
                                                id = New-Guid

                                                # un documented - if adding a contribution field must add reference name - this is the field in the control
                                                referenceName = $grpCtl.contribution.inputs.FieldName

                                                isContribution =  if($grpCtl.isContribution -eq $true){"$true"}else {"$false"}  
                                                height = "$null"
                                                label = $grpCtl.label.Trim()
                                                metadata = "$null"
                                                order = "$null"
                                                overridden = "$null"
                                                readOnly = if($grpCtl.readOnly -eq $true){"$true"}else {"$false"}   
                                                visible = if($grpCtl.visible -eq $true){"$true"}else {"$false"}   
                                                watermark = "$null"
                                                contribution = @{
                                                    contributionId = $grpCtl.contribution.contributionId
                                                    inputs = @{
                                                        FieldName =  $grpCtl.contribution.inputs.FieldName
                                                        Values = $grpCtl.contribution.inputs.Values
                                                    }
                                                }
                                            }
                                        }
                                        else
                                        {
                                            $addCtl = @{
                                                id = $grpCtl.id
                                                isContribution = if($grpCtl.isContribution -eq $true){"$true"}else {"$false"}  
                                                height = "$null"                                                    
                                                label = $grpCtl.label.Trim()
                                                metadata = "$null"
                                                order = "$null"
                                                overridden = "$null"
                                                readOnly = if($grpCtl.readOnly -eq $true){"$true"}else {"$false"}   
                                                visible = if($grpCtl.visible -eq $true){"$true"}else {"$false"}   
                                                watermark = "$null"
                                            }
                                        }

                                        $ctlJSON = ConvertTo-Json -InputObject $addCtl
                                        # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/controls/create?view=azure-devops-rest-7.1
                                        # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/groups/{groupId}/controls?api-version=7.1-preview.1
                                        $controlURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/groups/" + $group.id + "/controls?api-version=7.1-preview.1"    
                                        $control = Invoke-RestMethod -Uri $controlURL -Method Post -ContentType "application/json" -Headers $authorization -Body $ctlJSON
                                        Write-Host $control
                                    }
                                
                                }                                    
                                else 
                                {   
                                    # if this is the system description field, need to update label and visibility
                                    if($grp.controls[0].id -eq "System.Description")
                                    {
                                        $editGrp = @{
                                            id = $newGrp.Id
                                            label = $grp.label.Trim()
                                            visible = if($grp.controls[0].visible -eq "true"){"$true"}else{"$false"}
                                        }

                                        $editJSON = ConvertTo-Json -InputObject $editGrp
                                        # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/groups/update?view=azure-devops-rest-7.1
                                        # PATCH https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups/{groupId}?api-version=7.1-preview.1
                                        $editURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages/" + $pgExists.id + "/sections/" + $newSection.id +  "/groups/" + $grp.id + "?api-version=7.1-preview.1"    
                                        $editGroup = Invoke-RestMethod -Uri $editURL -Method PATCH -ContentType "application/json" -Headers $authorization -Body $editJSON
                                        Write-Host $editGroup

                                    }
                                    else
                                    {
                                        # if not a multi line control then update the group
                                        if($grp.controls[0].controlType -ne "HtmlFieldControl")
                                        {                                            
                                            # group exists update the group deployment and development groups inherited and trying to hide
                                                $editGrp = @{
                                                    id = $newGrp.Id
                                                    label = $grp.label.Trim()
                                                    visible = if($grp.controls[0].visible -eq "true"){"$true"}else{"$false"}
                                                }
                                            $editJSON = ConvertTo-Json -InputObject $editGrp

                                            # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/groups/update?view=azure-devops-rest-7.1
                                            # PATCH https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups/{groupId}?api-version=7.1-preview.1
                                            $editGrp = $null
                                            $editURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages/" + $pgExists.id + "/sections/" + $newSection.id +  "/groups/" + $grp.id + "?api-version=7.1-preview.1"    
                                            $editGroup = Invoke-RestMethod -Uri $editURL -Method PATCH -ContentType "application/json" -Headers $authorization -Body $editJSON
                                            Write-Host $editGroup
                                        }
                                    
                                    }
                                    
                                
                                }
                            }
                        }
                    }
                }
                
            } # group visible
            else
            {
                # page visible is false hide page in new layout
                $editPg = @{
                    id = $pgExists.id
                    label = $pgExists.label.Trim()
                    visible = "$false"
                }
                $editJSON = ConvertTo-Json -InputObject $editPg

                # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/pages/update?view=azure-devops-rest-7.1
                # PATCH https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages?api-version=7.1-preview.1
                $editURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages?api-version=7.1-preview.1"    
                $editPage = Invoke-RestMethod -Uri $editURL -Method PATCH -ContentType "application/json" -Headers $authorization -Body $editJSON
                Write-Host $editPage
            }

        } # page exists
       
    }

}