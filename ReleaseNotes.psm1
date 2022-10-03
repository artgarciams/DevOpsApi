#
# FileName : ProjectAndGroup.psm1
# Data     : 02/09/2018
# Purpose  : this module will create a project and groups for a project
#           This script is for demonstration only not to be used as production code
#
# last update 12/04/2020

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
function GetAuditLogs()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $outFile,
        [Parameter(Mandatory = $false)]
        $UsingExtension
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately    
    if($UsingExtension -eq "yes")
    {
        $authorization  = GetADOToken
    }else {
        $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        
    }

    #build table array - list of all builds for this release
    $AuditLogArray = @()

    # GET https://auditservice.dev.azure.com/{organization}/_apis/audit/auditlog?api-version=6.1-preview.1
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/audit/audit-log/audit-log-query?view=azure-devops-rest-6.1
    $AuditUrl  = $userParams.HTTP_preFix + "://auditservice.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/audit/auditlog?api-version=6.1-preview.1"     
    $AuditLogs = Invoke-RestMethod -Uri $AuditUrl -Method Get -Headers $authorization 
    
    while ($AuditLogs.hasMore -eq $true) 
    {
        $token = $AuditLogs.continuationToken
        $AuditUrl  = $userParams.HTTP_preFix + "://auditservice.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/audit/auditlog?continuationToken=" + $AuditLogs.continuationToken + "&api-version=6.1-preview.1"     

        foreach ($item in $AuditLogs.decoratedAuditLogEntries) 
        {
            $AuditLogArray += $item    
        }
        $AuditLogs = Invoke-RestMethod -Uri $AuditUrl -Method Get -Headers $authorization 
        # GET LAST SET OF LOG ENTRIES
        if($AuditLogs.HasMore -eq $false)
        {
            foreach ($item in $AuditLogs.decoratedAuditLogEntries) 
            {
                $AuditLogArray += $item    
            }
        }
    }

    $AccessLogs = $AuditLogArray.Where( { $_.category -eq "access" } )| Sort-Object -Property order
    $CreateLogs = $AuditLogArray.Where( { $_.category -eq "create" } )| Sort-Object -Property order
    $ExecuteLogs = $AuditLogArray.Where( { $_.category -eq "execute" } )| Sort-Object -Property order
    $ModifyLogs = $AuditLogArray.Where( { $_.category -eq "modify" } )| Sort-Object -Property order
    $RemoveLogs = $AuditLogArray.Where( { $_.category -eq "remove" } )| Sort-Object -Property order
    $UnKnownLogs = $AuditLogArray.Where( { $_.category -eq "unknown" } )| Sort-Object -Property order

    Write-Output "  " | Out-File -FilePath $outFile
    Write-Output "Total Log Count  : " $AuditLogArray.count | Out-File -FilePath $outFile -Append

    Write-Output "  " | Out-File -FilePath $outFile -Append
    Write-Output "Access Log Count  : " $AccessLogs.count  | Out-File -FilePath $outFile -Append -NoNewline
    Write-Output "  " | Out-File -FilePath $outFile -Append
    foreach ($item in $AccessLogs) 
    {
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Details " $item.Details | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  User    " $item.actorDisplayName | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Area    " $item.area | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        foreach ($Event in $item.data.EventSummary) 
        {
            Write-Output "     Event Timestamp :" $Event  | Out-File -FilePath $outFile -Append  -NoNewline 
            Write-Output "  " | Out-File -FilePath $outFile -Append
        }
    }

    Write-Output "  " | Out-File -FilePath $outFile -Append
    Write-Output "Create Log Count  : " $CreateLogs.count | Out-File -FilePath $outFile -Append -NoNewline
    Write-Output "  " | Out-File -FilePath $outFile -Append
    foreach ($item in $CreateLogs) 
    {
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Details " $item.Details | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  User    " $item.actorDisplayName | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Area    " $item.area | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        switch ($item.area) 
        {
            "Release" 
            { 
                Write-Output "      Release Data" | Out-File -FilePath $outFile -Append
                Write-Output "      Pipeline Id   " $item.data.PipelineId | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Pipeline Name " $item.data.PipelineName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Release Name  " $item.data.ReleaseName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
            }
            "Git" 
            { 
                Write-Output "      Git Data" | Out-File -FilePath $outFile -Append
                Write-Output "      Project Name   " $item.data.ProjectName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Repo Name      " $item.data.RepoName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
               
            }
            "Policy" 
            { 
                Write-Output "      Policy Data" | Out-File -FilePath $outFile -Append
                Write-Output "      Policy Name   " $item.data.PolicyTypeDisplayName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
            }
            "Pipelines" 
            { 
                Write-Output "      Pipeline Data" | Out-File -FilePath $outFile -Append
                Write-Output "      Pipeline Id   " $item.data.PipelineId | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Pipeline Name " $item.data.PipelineName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Release Name  " $item.data.ReleaseName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
            }
            "Library"
            {
                Write-Output "      Library Data" | Out-File -FilePath $outFile -Append
                Write-Output "      Authentication Type  " $item.data.AuthenticationType | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Connection Name " $item.data.ConnectionName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Connection Type " $item.data.ConnectionType | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
            }
            "Extension" 
            {
                Write-Output "      Extension Data" | Out-File -FilePath $outFile -Append
                Write-Output "      Publisher Name  " $item.data.PublisherName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Extension Name  " $item.data.ExtensionName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Version         " $item.data.Version | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
            }
            "Token" 
            {
                Write-Output "      Token Data" | Out-File -FilePath $outFile -Append
                Write-Output "      Token  Type   " $item.data.TokenType | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Display Name " $item.data.DisplayName | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Valid From   " $item.data.ValidFrom | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output "      Valid To     " $item.data.ValidTo | Out-File -FilePath $outFile -Append -NoNewline
                Write-Output "  " | Out-File -FilePath $outFile -Append
                foreach ($scope in $item.data.Scopes) 
                {
                    Write-Output "           Scope    " $scope | Out-File -FilePath $outFile -Append -NoNewline
                    Write-Output "  " | Out-File -FilePath $outFile -Append
                }
                Write-Output "  " | Out-File -FilePath $outFile -Append

            }
            Default {}
        }
    }

    Write-Output "  " | Out-File -FilePath $outFile -Append
    Write-Output "Execute Log Count : " $ExecuteLogs.count  | Out-File -FilePath $outFile -Append -NoNewline
    Write-Output "  " | Out-File -FilePath $outFile -Append
    foreach ($item in $ExecuteLogs) 
    {
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Details " $item.Details | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  User    " $item.actorDisplayName | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Area    " $item.area | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append

    }

    Write-Output "  " | Out-File -FilePath $outFile -Append
    Write-Output "Modify Log Count  : " $ModifyLogs.count | Out-File -FilePath $outFile -Append -NoNewline
    Write-Output "  " | Out-File -FilePath $outFile -Append
    foreach ($item in $ModifyLogs) 
    {
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Details " $item.Details | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  User    " $item.actorDisplayName | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Area    " $item.area | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
    }

    Write-Output "  " | Out-File -FilePath $outFile -Append
    Write-Output "Remove Log Count  : " $RemoveLogs.count | Out-File -FilePath $outFile -Append -NoNewline
    Write-Output "  " | Out-File -FilePath $outFile -Append
    foreach ($item in $RemoveLogs) 
    {
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Details " $item.Details | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  User    " $item.actorDisplayName | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Area    " $item.area | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append

    }

    Write-Output "  " | Out-File -FilePath $outFile -Append
    Write-Output "Unknown Log Count : " $UnKnownLogs.count | Out-File -FilePath $outFile -Append -NoNewline
    Write-Output "  " | Out-File -FilePath $outFile -Append
    foreach ($item in $UnKnownLogs) 
    {
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Details " $item.Details | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  User    " $item.actorDisplayName | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append
        Write-Output "  Area    " $item.area | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "  " | Out-File -FilePath $outFile -Append

    }


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
        $outFile,
        [Parameter(Mandatory = $false)]
        $UsingExtension
    )
    

     # Base64-encodes the Personal Access Token (PAT) appropriately    
     if($UsingExtension -eq "yes")
     {
         Write-Host " Using System Access Token"
         $authorization  = @{Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"} 

         $usr =  [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
         $getcur = [System.Security.Principal.WindowsIdentity]::GetCurrent()
         $gp =   ConvertTo-Json  -InputObject $getcur.groups -Depth 24
         Write-Host "Current User is : " $usr 
         Write-Host "Current User Group is : "  $gp 

     }else {
         $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        
     }

    $usr =  [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host $usr
    
    #build table array - list of all builds for this release
    $buildTableArray = @()

    # array for changes to a given build
    $buildChangesArray = @()

    # array for artifacts to a given build
    $buildArtifactArray = @()
   
    # array for release notes
    $ReleaseWorkItems = @()

    # array for list of builds with a given tag
    $AllBuildswithTags = @()
      
    # Get a list of all builds with a specific tag
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/list?view=azure-devops-rest-6.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds?definitions={definitions}&queues={queues}&buildNumber={buildNumber}&minTime={minTime}&maxTime={maxTime}&requestedFor={requestedFor}&reasonFilter={reasonFilter}&statusFilter={statusFilter}&resultFilter={resultFilter}&tagFilters={tagFilters}&properties={properties}&$top={$top}&continuationToken={continuationToken}&maxBuildsPerDefinition={maxBuildsPerDefinition}&deletedFilter={deletedFilter}&queryOrder={queryOrder}&branchName={branchName}&buildIds={buildIds}&repositoryId={repositoryId}&repositoryType={repositoryType}&api-version=6.1-preview.6
    foreach ($tag in $userParams.BuildTags) 
    {
        $AllBuildsUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds?tagFilters=" + $tag + "&api-version=6.1-preview.6"     
        #$BuildswithTags = Invoke-RestMethod -Uri $AllBuildsUri -Method Get -Headers $authorization -Verbose
        $BuildswithTags = Invoke-RestMethod -Uri $AllBuildsUri -Method Get -Headers $authorization
        
        # add in all builds
        foreach ($bldTag in $BuildswithTags.value)
        {
            $AllBuildswithTags += $bldTag
        }
    } 
    Write-Host "Builds found :" $AllBuildswithTags.count

    # work items for all builds found
    $ReleaseWorkItems = New-Object System.Collections.ArrayList
    $ReleaseWorkItems = [System.Collections.ArrayList]::new()

    # loop thru each build in list found
    foreach ($build in $AllBuildswithTags) 
    {
        # get work all items for this build
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/get%20build%20work%20items%20refs?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/workitems?api-version=6.1-preview.2
        $workItemUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $build.id + "/workitems?api-version=6.1-preview.2"
        $allBuildWorkItems = Invoke-RestMethod -Uri $workItemUri -Method Get -Headers $authorization
       
        Write-Host "   Build Number:" $build.buildNumber " Build Definition :" $build.definition.name "  Results: " $build.result  " Status : " $build.status 
        Write-Host "   Number of work Items in this Build : "  $allBuildWorkItems.count
    
        # loop thru all workitems get work items 
        foreach ($workItem in $allBuildWorkItems.value)
        {
            $fld = ""
            try {
                # get individual work item
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items/get%20work%20item?view=azure-devops-rest-6.1
                # GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?api-version=6.1-preview.3
                $BuildworkItemUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/wit/workitems/" + $workItem.id + "?$" + "expand=All&api-version=6.1-preview.3" 
                $WItems = Invoke-RestMethod -Uri $BuildworkItemUri -Method Get -Headers $authorization
                    
                $fld = $WItems.fields
                $wkType = $fld.'System.WorkItemType'

                # Check if this is a userstory or bug
                  # if not user story find parent user story  "User Story", "Bug"
                if( !$userParams.WorkItemTypes.Contains($wkType) )
                {
                    try {
                        $prnt = $fld.'System.Parent'
                        # get parent work item
                        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items/get%20work%20item?view=azure-devops-rest-6.1
                        # GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?api-version=6.1-preview.3
                        $BuildworkItemUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/wit/workitems/" + $prnt + "?$" + "expand=All&api-version=6.1-preview.3" 
                        $WItems = Invoke-RestMethod -Uri $BuildworkItemUri -Method Get -Headers $authorization
                       
                        $fld = $WItems.fields                                
                        $wkType = $fld.'System.WorkItemType'

                        # add field to house work item type. this will allow sorting of workitems by type
                        $WItems | Add-Member -MemberType NoteProperty -name "WorkItemType" -Value $wkType
                        $WItems | Add-Member -MemberType NoteProperty -name "Version" -Value $build.buildNumber
                        $WItems | Add-Member -MemberType NoteProperty -name "PipeLine" -Value $build.definition.name

                    }
                    catch {
                        $ErrorMessage = $_.Exception.Message
                        $FailedItem = $_.Exception.ItemName
                        Write-Host "Error in Finding work items parent  : " + $ErrorMessage 
                    }
                }else 
                {
                    # add field to house work item type. this will allow sorting of workitems by type
                    $WItems | Add-Member -MemberType NoteProperty -name "WorkItemType" -Value $wkType
                    $WItems | Add-Member -MemberType NoteProperty -name "Version" -Value $build.buildNumber
                    $WItems | Add-Member -MemberType NoteProperty -name "PipeLine" -Value $build.definition.name
                }
              
                # save work items into an array to sort if tag was found
                $ReleaseWorkItems.Add($WItems) | Out-Null
                Write-Host   " WorkItem ID:" $workItem.id " Version : "  $build.buildNumber.ToString()
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Write-Host "Error in work item lookup : " + $ErrorMessage + " iTEM : " + $WItems.fields
            }
        }

        $buildChangesArray = @()
        try 
        {
            # get all changes for a given build       
            # need to use webrequest to get continuation token to get all rows. it pages at 50
            # https://stackoverflow.com/questions/59980722/azure-devops-rest-api-call-retrieving-only-top-100-records-and-continuationtoken
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/get%20build%20changes?view=azure-devops-rest-6.1
            # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/changes?api-version=6.1-preview.2           
            $continuationToken = $null
            
            do {
                $bldChangegUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $Build.id + "/changes?continuationToken=" + $continuationToken + "&includeSourceChange=True&api-version=6.1-preview.2"
                $bldData = Invoke-WebRequest  -Uri $bldChangegUri -Method Get -Headers $authorization -UseBasicParsing -ContentType "application/json" 

                $continuationToken = $bldData.Headers.'x-ms-continuationtoken'
                $fl1 =  ConvertFrom-Json -InputObject $bldData.Content    

                foreach ($item in $fl1.value) {
                    $locationData = Invoke-RestMethod -Uri $item.Location -Method Get -Headers $authorization
                    $loc = $locationData.remoteUrl.Replace(" ", "%20")
                    Write-Host "      Change : " + $item.message

                    $chg = New-Object -TypeName PSObject -Property @{
                        BuildChange = $item.message
                        DateChanged = $item.timestamp 
                        ChangedBy = $item.'author'.DisplayName   
                        Location =   $loc
                        type = $item.type 
                        Id = $item.Id                    
                    }    
                    $buildChangesArray += $chg       
                }
            } while ($null -ne $continuationToken)
        }
        catch 
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Error in Finding Changes for given build : " + $ErrorMessage + " iTEM : " + $FailedItem    
        }
       
        try {
            # get build stages
            # 
            # get build timeline 
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/timeline/get?view=azure-devops-rest-6.1
            # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/timeline/{timelineId}?api-version=6.1-preview.2
            $BuildTimelineUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $build.id + "/timeline?api-version=6.1-preview.2"
            $BuildTimeLine = Invoke-RestMethod -Uri $BuildTimelineUri -Method Get -Headers $authorization
                        
            # filter timeline by stages,job,tasks, etc
            $tmStages = $BuildTimeLine.records | Where-Object { $_.type -eq "Stage" } | Sort-Object -Property order
            $tmJobs = $BuildTimeLine.records | Where-Object { $_.type -eq "Job" } | Sort-Object -Property order
            $tmTasks = $BuildTimeLine.records | Where-Object { $_.type -eq "Task" } | Sort-Object -Property order
            $tmPhase = $BuildTimeLine.records | Where-Object { $_.type -eq "Phase" } | Sort-Object -Property order

            $tmCheckPoint = $BuildTimeLine.records | Where-Object { $_.type -eq "CheckPoint" } | Sort-Object -Property order        
            $tmCpApproval = $BuildTimeLine.records | Where-Object { $_.type -eq "Checkpoint.Approval" } | Sort-Object -Property order
            $tmCpTaskChk = $BuildTimeLine.records | Where-Object { $_.type -match "Checkpoint.TaskCheck" } | Sort-Object -Property order
            
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
                $stg = $null         
            }

            Write-Host "Jobs for this Build:"
            foreach ($job in $tmJobs) 
            {
                Write-Host "           " $build.buildNumber $job.name $job.order $job.startTime $job.state $job.result
            }

            Write-Host "Approvals for this Build"
            foreach ($Apprv in $tmCpApproval) 
            {
                
            }

            
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Error in getting build stages : " + $ErrorMessage 
        }
                
        try {
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
                    BuildNumber  = $build.buildNumber
                    buildId      = $build.id
                    type = $artifact.resource.type                   
                }
                $buildArtifactArray += $stg    
                $stg = $null        
            }
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Error in getting artifacts : " + $ErrorMessage 
        }
        
        Write-Host ""   
        Write-Host "Build ID: " $build.id " - Build Number : " $build.buildNumber    
       
        $def = $build.definition
        $repo = $build.repository
        
        # get tags
        $buildTag = ""
        foreach ($tg in $build.tags) 
        {
            $buildTag += $tg + " "
        }

        # write build record table . this arraylist will hold all builds found
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
            BuildArtifiacts = $buildArtifactArray

        }
        $buildTableArray += $bld
       
        # to count work items associated with this build
        $workitemsReported = 0
        
        # sort by url( work item type) decending
        $allBuildWorkItemsSorted =  $ReleaseWorkItems | Sort-Object -Property WorkItemType -Descending
               
        # add count of workitems to report to summary. this will count all reported workitems for this build. 
        # note reported is user stories and bugs. all tasks are rolled up into userstories
        if ($buildTableArray.Length -gt 0)
        {
            $buildTableArray[$buildTableArray.Length -1]  | Add-Member -MemberType NoteProperty -name "WorkItemCount" -Value  $allBuildWorkItems.count
            Write-Host "    Work Items Found :" $workitemsReported
        }

    }
    
       # return build and workitems to add to wiki    
       # write build record table and workitems  . this arraylist will hold all builds found and workitems
       $ReleaseArray = New-Object -TypeName PSObject -Property @{
        Builds = $buildTableArray
        WorkItems = $allBuildWorkItemsSorted
        Artifacts = $buildArtifactArray
    }
    return $ReleaseArray

}

function WriteToWikiPage()
{

    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $contentData,
        [Parameter(Mandatory = $false)]
        $UsingExtension,
        [Parameter(Mandatory = $false)]
        $RelPageName
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately    
    if($UsingExtension -eq "yes")
    {
        Write-Host "Using System Access Token"
        $authorization  = @{Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"} 
        
        $usr =  [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $getcur = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $gp =   ConvertTo-Json  -InputObject $getcur.groups -Depth 24
        Write-Host "Current User is : " $usr 
        Write-Host "Current User Group is : "  $gp 

    }else {
        $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        
    }

    try {
        # get all wiki for given org
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/wikis/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis?api-version=6.1-preview.2
        $wikiUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis?api-version=6.1-preview.2"
        $wikiUri = $wikiUri.Replace(" ","%20")
        $allWikifnd = Invoke-RestMethod -Uri $wikiUri -Method Get -Headers $authorization

        # find desired wiki to use
        $allWiki = $allWikifnd.value | Where-Object {$_.name -eq $userParams.PublishWiKi }

        Write-Host ""
        Write-Host "==========   WiKi Page Build Section  =========="
        Write-Host "Wiki found :"  $allWiki.name
        Write-Host "WiKi ID    :" $allWiki.id
        Write-host "WiKi Type  :" $allWiki.type
       
    }
    catch {
        $ErrorMessage = $_.Exception.Message      
        Write-Host "Error in getting Main WiKi : " + $ErrorMessage 
    }

    #
    # create parent page if it does not exist
    #
    try 
    {
        # first see if parent page exists, if not create it
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/pages/get-page?view=azure-devops-rest-6.1#examples
        $FindPageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $allWiki.Name + "/pages?path=" + $userParams.PublishParent  + "&api-version=6.1-preview.1" 
        $FindParentPage = Invoke-RestMethod -Uri $FindPageUri -Method Get -ContentType "application/json" -Headers $authorization 
        Write-Host "Parent Page exist :  $userParams.PublishParent  " $FindParentPage.content       
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Error in creating parent WiKi page : " $userParams.PublishParent  
        Write-Host "Error returned  : " + $ErrorMessage 
               
        $tmData = @{
            content  = "Parent Release Notes Page"
        }
        $tmJson = ConvertTo-Json -InputObject $tmData    
        $CreatePageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $allWiki.Name + "/pages?path=" + $userParams.PublishParent  + "&api-version=6.1-preview.1" 
        $CreatePage = Invoke-RestMethod -Uri $CreatePageUri -Method Put -ContentType "application/json" -Headers $authorization -Body $tmJson -Verbose
        Write-Host "Parent Page Created : $userParams.PublishParent  " $CreatePage

    }

    #
    # Create wiki page if it does not exist, if exists it will throw an error
    #
    # create project page in wiki
    if([string]::IsNullOrEmpty($RelPageName) )
    {
        $landingPg = $userParams.PublishParent + "/" + $userParams.PublishPagePrfx 
    }
    else
    {
        $landingPg = $userParams.PublishParent + "/" + $RelPageName    
    }

    try
    {
        #DELETE https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis/{wikiIdentifier}/pages?path={path}&api-version=7.1-preview.1
        #https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/pages/delete-page?view=azure-devops-rest-7.1
        $DeletePageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $allWiki.Name + "/pages?path=" + $landingPg + "&api-version=7.1-preview.1" 
        $DeletePage = Invoke-RestMethod -Uri $DeletePageUri -Method Delete -Headers $authorization -Verbose
        Write-Host $DeletePage


    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
    }


    try 
    {
       $contentData = @{
            content  =  $contentData
        }
        $blankData = @{
            "content" = "Wiki page content"
        }

        $ContentJson = ConvertTo-Json -InputObject $contentData
      
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/pages/create%20or%20update?view=azure-devops-rest-6.1
        # PUT https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis/{wikiIdentifier}/pages?path={path}&api-version=6.1-preview.1
        $CreatePageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $allWiki.Name + "/pages?path=" + $landingPg + "&api-version=7.1-preview.1" 
        $CreatePage = Invoke-RestMethod -Uri $CreatePageUri -Method Put -ContentType "application/json" -Headers $authorization -Body $ContentJson -Verbose
        Write-Host $CreatePage
        Write-Host "WiKi Landing Page Created "
    }
    catch {
        
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error Creating parent Page : " $ErrorMessage 
        Write-Host "WiKi Landing Page exists "
    }   


     Write-Host "Page created - Release Notes complete"
  

}


function Set-ReleaseNotesToWiKi()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $Data,
        [Parameter(Mandatory = $false)]
        $UsingExtension
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately    
    if($UsingExtension -eq "yes")
    {
        Write-Host "Using System Access Token"
        $authorization  = @{Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"} 
        
        $usr =  [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $getcur = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $gp =   ConvertTo-Json  -InputObject $getcur.groups -Depth 24
        Write-Host "Current User is : " $usr 
        Write-Host "Current User Group is : "  $gp 

    }else {
        $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        
    }

    try {
        # get all wiki for given org
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/wikis/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis?api-version=6.1-preview.2
        $wikiUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis?api-version=6.1-preview.2"
        $wikiUri = $wikiUri.Replace(" ","%20")
        $allWikifnd = Invoke-RestMethod -Uri $wikiUri -Method Get -Headers $authorization

        # find desired wiki to use
        $allWiki = $allWikifnd.value | Where-Object {$_.name -eq $userParams.PublishWiKi }

        Write-Host ""
        Write-Host "==========   WiKi Page Build Section  =========="
        Write-Host "Wiki found :"  $allWiki.name
        Write-Host "WiKi ID    :" $allWiki.id
        Write-host "WiKi Type  :" $allWiki.type
       
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error in getting Main WiKi : " + $ErrorMessage 
    }
    
    #
    # create parent page if it does not exist
    #
    try 
    {
        # first see if parent page exists, if not create it
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/pages/get-page?view=azure-devops-rest-6.1#examples
        $FindPageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $allWiki.Name + "/pages?path=" + $userParams.PublishParent  + "&api-version=6.1-preview.1" 
        $FindParentPage = Invoke-RestMethod -Uri $FindPageUri -Method Get -ContentType "application/json" -Headers $authorization 
        Write-Host "Parent Page exist :  $userParams.PublishParent  " $FindParentPage.content       
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error in creating parent WiKi page : " $userParams.PublishParent  
        Write-Host "Error returned  : " + $ErrorMessage 
               
        $tmData = @{
            content  = "Parent Release Notes Page"
        }
        $tmJson = ConvertTo-Json -InputObject $tmData    
        $CreatePageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $allWiki.Name + "/pages?path=" + $userParams.PublishParent  + "&api-version=6.1-preview.1" 
        $CreatePage = Invoke-RestMethod -Uri $CreatePageUri -Method Put -ContentType "application/json" -Headers $authorization -Body $tmJson -Verbose
        Write-Host "Parent Page Created : $userParams.PublishParent  " $CreatePage

    }

    #
    # Create wiki page if it does not exist, if exists it will throw an error
    #
    # create project page in wiki
    if([string]::IsNullOrEmpty($RelPageName) )
    {
        $landingPg = $userParams.PublishParent + "/" + $userParams.PublishPagePrfx 
    }
    else
    {
        $landingPg = $userParams.PublishParent + "/" + $RelPageName    
    }

    try 
    {
       $blankData = @{
            content  = "Blank Page"
        }
        $BlankJson = ConvertTo-Json -InputObject $blankData
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/pages/create%20or%20update?view=azure-devops-rest-6.1
        # PUT https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis/{wikiIdentifier}/pages?path={path}&api-version=6.1-preview.1
        $CreatePageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $allWiki.Name + "/pages?path=" + $landingPg + "&api-version=6.0" 
        $CreatePage = Invoke-RestMethod -Uri $CreatePageUri -Method Put -ContentType "application/json" -Headers $authorization -Body $BlankJson
        Write-Host $CreatePage
        Write-Host "WiKi Landing Page Created "
    }
    catch {
        
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error Creating parent Page : " $ErrorMessage 
        Write-Host "WiKi Landing Page exists "
    }   
  

    # build content
    # sort by sequence number  
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date?view=powershell-7.1
    $dt = Get-Date -format "dddd MM/dd/yyyy HH:mm K"
    $contentData = "" 
    $contentData = "[[_TOC_]]" + $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  "_Release Notes for Build Tags : "  + $userParams.BuildTags + "_"
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  "_Release Notes Created        : "  + $dt + "_"
    $contentData +=  $([char]13) + $([char]10) 
    
    # count number of changes
    $chgCount = 0
    $chgCount += $Data.Builds.BuildChanges.count
        
    # permanent notes section will replace '\r' with carrage return line feed
    if($userParams.PermNoteTitle -ne "")
    {
        $contentData +=  $([char]13) + $([char]10) 
        $contentData +=  $([char]13) + $([char]10) 
        $contentData +=  $userParams.PermNoteTitle + $([char]13) + $([char]10) 
        $body = $userParams.PermNoteBody.Replace('\r', $([char]13) + $([char]10) )
        $contentData +=  $body + $([char]13) + $([char]10) 
        $contentData +=  $([char]13) + $([char]10) 
        $contentData +=  $([char]13) + $([char]10) 
    }

    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  "#Build Summary" + $([char]13) + $([char]10) 
    $contentData += "|Summary Item|Count" + $([char]13) + $([char]10) 
    $contentData += "|:---------|:---------|" + $([char]13) + $([char]10) 
    $contentData += "|" + "Builds in this Release" + "|" + $Data.builds.count + "|" + $([char]13) + $([char]10) 
    $contentData += "|" + "Builds Changes in this Release" + "|" + $chgCount + "|" + $([char]13) + $([char]10) 
    $contentData += "|" + "Work Items(user stories,bugs,Tasks) in this release" + "|" + $Data.WorkItems.count + "|" + $([char]13) + $([char]10) 

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
    $buildBySeq = $Data.builds | Sort-Object -Property Version
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
    $contentData += "|Name|Type|Build|" + $([char]13) + $([char]10) 
    $contentData += "|:---------|:---------|:---------|" + $([char]13) + $([char]10)    
    
    foreach ($bldArt in $Data.Artifacts) 
    {       
        $Nameurl = " [" + $bldArt.ArtifactName + "]" + "(" + $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" +  $userParams.ProjectName.Replace(" ","%20") + "/_build/results?buildId=" + $bldArt.buildId + "&view=artifacts&pathAsName=false&type=publishedArtifacts" + ")"       
        $url = " [" + $bldArt.BuildNumber + "]" + "(" + $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" +  $userParams.ProjectName.Replace(" ","%20") + "/_build/results?buildId=" + $bldArt.buildId + "&view=results" + ")"       
        $contentData += "|" + $Nameurl + "|" +  $bldArt.Type + "|" + $url + "|" + $([char]13) + $([char]10) 
    }

    $contentData += $([char]13) + $([char]10) 
    $contentData += $([char]13) + $([char]10) 
        
    <# 
        $contentData += $([char]13) + $([char]10) 
        $contentData += "#Backout Plan" + $([char]13) + $([char]10) 
        $contentData += "|Solution|Pipeline|Sequence|Version|" + $([char]13) + $([char]10) 
        $contentData += "|:---------|:---------|:---------|:---------|" + $([char]13) + $([char]10)      
    #>

    # if replace was generated add it to the end of page.
    # If($secReplace -ne "")
    # {
    #     $contentData += $secReplace
    # }

  WriteToWikiPage -userParams $userParams -contentData $contentData

    # try {

    #     Write-Host "Begin Writting to WiKi "
     
    #     # write to code wiki page
    #     if ($allWiki.type -eq "codewiki")
    #     {
    #         $tmData = @{
    #             refUpdates  = @{
    #                 name = "ref/heads/master"
    #                 newObjectId =  [guid]::NewGuid()
    #             }
    #             commits = @{
    #                 comment = "new file"
    #                 changes = @{
    #                     changeType = "add"
    #                     item = @{
    #                         path = "/testaag.md"
    #                     }
    #                     newContent = @{
    #                         content = $contentData
    #                         contentType = "rawtext"
    #                     }
    #                 }
    #             }
    #         }

    #         $tmJson = ConvertTo-Json -InputObject $tmData    

    #         # test writing to code wiki
    #         # https://docs.microsoft.com/en-us/rest/api/azure/devops/git/pushes/create?view=azure-devops-rest-6.1
    #         # POST https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/pushes?api-version=6.1-preview.2
    #         $codeWiki = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/git/repositories/" + $allWiki.repositoryId + "/pushes?api-version=6.1-preview.2"
    #         $writeCodeWiki = Invoke-RestMethod -Uri $codeWiki -Method Put -ContentType "application/json" -Headers $authorization -Body $tmJson -Verbose
    #     }

    
}

function GetADOToken() {

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $env:build.requestedForEmail, $env:SYSTEM_ACCESSTOKEN)))
    return @{Authorization = ("Basic {0}" -f $base64AuthInfo)}
}


function GetADOTokenWithEtagForExt () {
    Param(
        
        $eTag
    )
    
    return @{Authorization = ("Bearer $env:SYSTEM_ACCESSTOKEN") 
            'If-Match' = $etag
            }
}

function GetADOTokenWithEtag () {
    Param(
        
        $eTag
    )
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $env:build.requestedForEmail, $env:SYSTEM_ACCESSTOKEN)))
    return @{Authorization = ("Basic {0}" -f $base64AuthInfo) 
            'If-Match' = $etag
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

function GeReleaseNotesByQuery()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $Data,
        [Parameter(Mandatory = $false)]
        $UsingExtension
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately    
    if($UsingExtension -eq "yes")
    {
        Write-Host "Using System Access Token"
        $authorization  = @{Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"} 
        
        $usr =  [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $getcur = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $gp =   ConvertTo-Json  -InputObject $getcur.groups -Depth 24
        Write-Host "Current User is : " $usr 
        Write-Host "Current User Group is : "  $gp 

    }else {
        $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        
    }
  
    # first get project because we need project id
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/_apis/projects?api-version=7.1-preview.4
    $AllProjectsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects?api-version=7.1-preview.4"     
    $AllProjects = Invoke-RestMethod -Uri $AllProjectsUrl -Method Get -Headers $authorization
    $project = $AllProjects.value | Where-Object {$_.name -eq $userParams.ProjectName}
    Write-Host $project

    # get query list and find specific query for current release
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/queries/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/wit/queries?api-version=7.1-preview.2
    $queryUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct +"/" +  $project.Id +"/_apis/wit/queries?" + '$expand=all&$depth=1&api-version=7.1-preview.2'
    $query = Invoke-RestMethod -Uri $queryUrl -Method Get -Headers $authorization -ContentType "application/json" 
    
    $sharedQry =  $query.value | Where-Object {$_.name -eq "Shared Queries"}
    $currRelQuery =  $sharedQry.children | Where-Object {$_.name -eq $userParams.CurrentWitemQry } 
    $futureRelQuery =  $sharedQry.children | Where-Object {$_.name -eq $userParams.FutureWitemQry}
        
    $tmData = @{
        query = $currRelQuery.wiql
    }
    $qryText = ConvertTo-Json -InputObject $tmData  
    
    # get current query items
    $queryUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct +"/" +  $project.Id +"/" + $userParams.DefaultTeam +"/_apis/wit/wiql?api-version=7.1-preview.2"     
    $currquery = Invoke-RestMethod -Uri $queryUrl -Method Post -Headers $authorization -Body $qryText -ContentType "application/json" 

    IF (![string]::IsNullOrEmpty($futureRelQuery.wiql) )
    {
        $tmData = @{
            query = $futureRelQuery.wiql
        }
        $qryFutureText = ConvertTo-Json -InputObject $tmData  

        # get future query items
        $futurequery = Invoke-RestMethod -Uri $queryUrl -Method Post -Headers $authorization -Body $qryFutureText -ContentType "application/json" 
    }      

    # setup array to house results
    $AllWorkItems = @()
    $FutureWkItems = @()
    #$qryCnt = 0

    foreach ($wk in $currquery.workItems) 
    {
        $WorItemUrl =  $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wit/workitems/" + $wk.Id + "?expand=Fields&api-version=7.1-preview.3"
        $WorkItem = Invoke-RestMethod -Uri $WorItemUrl -Method Get -Headers $authorization
     
        # remove special characters from title. they cause the markup for the page to be invalid
        $title = $WorkItem.fields.'System.Title'
        $title = $title.Replace('"',"'").Replace('~',"-") 

        #$title = $title.Replace('~',"-")

        $Desc = $WorkItem.fields.'Custom.CTI'
        if($desc -ne $null)
        {
            if($Desc.length -ge 150)
            {
                #$desc = $Desc.substring(0,150)
            }
        }

        Write-Host  $title
        $stg = New-Object -TypeName PSObject -Property @{
            Id = $wk.Id
            Title = $title 
            RequestType = $WorkItem.fields.'Custom.RequestType'
            Program = $WorkItem.fields.'Custom.Program'
            Bucket = $WorkItem.fields.'Custom.Bucket'
            Description = $desc 
            Sprint = $WorkItem.fields.'Custom.Sprint'
            Team = $WorkItem.fields.'Custom.Team'
            Leads = $WorkItem.fields.'Custom.ProgramOwner'
        }

        $AllWorkItems += $stg   
        $stg = $null   
        # $qryCnt += 1
        # if($qryCnt -ge 300)
        # {
        #     break
        # }        
      
    }

    IF (![string]::IsNullOrEmpty($futureRelQuery.wiql) )
    {
        # loop thru all future work items and store in array
        foreach ($wk in $futurequery.workItems) 
        {
            $WorItemUrl =  $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wit/workitems/" + $wk.Id + "?expand=Fields&api-version=7.1-preview.3"
            $WorkItem = Invoke-RestMethod -Uri $WorItemUrl -Method Get -Headers $authorization

            Write-Host  $WorkItem.fields.'System.Title'

            $stg = New-Object -TypeName PSObject -Property @{
                Id = $wk.Id
                Title =  $WorkItem.fields.'System.Title'
                RequestType = $WorkItem.fields.'Custom.RequestType'
                Program = $WorkItem.fields.'Custom.Program'
                Bucket = $WorkItem.fields.'Custom.Bucket'
                Description = $WorkItem.fields.'Custom.CTI'
                Sprint = $WorkItem.fields.'Custom.Sprint'
                Team = $WorkItem.fields.'Custom.Team'
                Leads = $WorkItem.fields.'Custom.ProgramOwner'
            }
            $FutureWkItems += $stg   
            $stg = $null           
        }

        # sort data by Bucket , title and generate wiki markup
        $srtFutureData =  $FutureWkItems | Sort-Object -Property  @{Expression={$_.Program}; Descending=$false}, @{Expression={$_.Title}; Descending=$false} 
    }
    
    # sort data by Bucket , title and generate wiki markup
    $srtData =  $AllWorkItems | Sort-Object -Property @{Expression={$_.Program}; Descending=$false}, @{Expression={$_.Title}; Descending=$false}

    $lstBucket = ""
    $lstNull = "false"

    [int]$cnt = 1
    $dt = Get-Date -format "dddd MM/dd/yyyy HH:mm K"
    $contentData = "" 
    $contentData = "[[_TOC_]]" + $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  "_Release Notes from ISCJ Programs Requests Work Items_"
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  "_Release Notes Created        : "  + $dt + "_"
    $contentData +=  $([char]13) + $([char]10) 

    $contentData +=  "_Current Work Items Query used : "  + $userParams.CurrentWitemQry + "_"
    $contentData +=  $([char]13) + $([char]10) 
    
    if( $userParams.FutureWitemQry -ne "")
    {
        $contentData +=  "_Future Work Items Query used  : "  + $userParams.FutureWitemQry + "_"
        $contentData +=  $([char]13) + $([char]10) 
    }
    
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10)     
    $contentData += "**Whats New**" +  $([char]13) + $([char]10) 
   
    $dte = Get-Date -Format "MM/dd" 
    $contentData += " The " + $dte + " release cycle "
   
    $contentData += $userParams.WhatsNewComment + $([char]13) + $([char]10)
    $contentData +=  $([char]13) + $([char]10) 

    $contentData += "*Feedback?  Questions?*   askISCJprograms@microsoft.com" + $([char]13) + $([char]10)
    $contentData += "*Suggested program/system/tooling enhancements?*   https://aka.ms/ISCJProgramsRequest" + $([char]13) + $([char]10)
    $contentData +=  $([char]13) + $([char]10) 

    $contentData += "#" + $userParams.CurrentQryText + $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 
 
    foreach ($srt in $srtData)
    {
       IF ([string]::IsNullOrEmpty($srt.Program) -and $lstNull -eq "false") 
       {
        $contentData +=  $([char]13) + $([char]10) 
        $contentData +=  $([char]13) + $([char]10) 
        $contentData += "##" + " No Program" + $([char]13) + $([char]10) 
        $lstBucket = ""
        $lstNull = "true"
       }
       else 
       {
           if($lstBucket -ne $srt.Program)
           {
            $contentData +=  $([char]13) + $([char]10) 
            $contentData +=  $([char]13) + $([char]10) 
            $contentData += "## " + $srt.Program + $([char]13) + $([char]10) 
            $cnt = 1
           }

       }

       $contentData += $cnt.ToString() + ". **" 
       $contentData += $srt.Title.Trim() + "**"

       $pjName = $userParams.ProjectName.Replace(" ","%20")
       $url = "(" + $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $pjName + "/_workitems/edit/" + $srt.id + ")"
       $contentData += " [" + $srt.id + "]" + $url  + $([char]13) + $([char]10) 
       $contentData += " <U>Lead: </U>"
       
       # add tag for leads
       if(![string]::IsNullOrEmpty($srt.Leads.Displayname) )
       {
            # for testing dont tag leads as it will show in inbox
            if($userParams.TagLeads -eq $true)
            {
                $contentData +=  "@<" + $srt.Leads.uniqueName + ">" + $([char]13) + $([char]10) 
            }
            else
            {
                $contentData +=  $srt.Leads.Displayname + $([char]13) + $([char]10)                 
            }
       }
       else
       {
        $contentData += $([char]13) + $([char]10) 
       }
      
       $desc = ""     
       $atags = $false

       IF (![string]::IsNullOrEmpty($srt.Description) )
       {
            $HTML = New-Object -Com "HTMLFile"      
            $Unicode = [System.Text.Encoding]::Unicode.GetBytes($srt.Description)
            if ($HTML.IHTMLDocument2_Write) {
                $HTML.IHTMLDocument2_Write($Unicode)
            } else {
                $HTML.write($Unicode)
            }

            # loop thru the HTML and filter out Tags
            # Some DIV and SPAN tags have <A> anchor tags imbedded and you have to find them and replae the description
            # careful not to duplicate inner text when building description
            #
            $lstATag = ""
            $lstSpan = $false
            foreach ($tag in $HTML.all) 
            {
                Write-Host $tag.tagName " -- " $srt.Id " -- " $desc 
                #
                # swithcu thru the important tags and get description and link
                switch ($tag.tagName) 
                {
                    "DIV"{
                        $desc += $tag.outerText
                        IF (![string]::IsNullOrEmpty($tag.href) ) 
                        {
                            if($lstATag -ne $tag.href)
                            {
                                $desc = $desc.replace($tag.outerText,  " [" + $tag.outerText + "](" + $tag.href + ") " )
                            }
                            $lstATag = $tag.href
                        }                    
                    }
                    "SPAN" {
                        if($lstSpan -eq $false)
                        {
                            if(!$desc.Contains($tag.outerText))
                            {
                                $desc += $tag.outerText
                            }
                        }
                        else
                        {
                            $desc = $desc.replace($tag.outerText, $tag.outerText)
                        }
                        $lstSpan = $true
                        #
                        # loop thru any child tags
                        foreach ($child in $tag.children) 
                        {
                            if($child.tagName -eq "A")
                            {
                                if($lstATag -ne $child.href )
                                {
                                    $desc = $desc.replace($child.innerText,  " [" + $child.innerText + "](" + $child.href + ") " )
                                }
                                $lstATag = $child.href
                            }
                            $atags = $true
                        }
                        
                    }

                    "A" {
                        IF (![string]::IsNullOrEmpty($tag.href) -and $atags -eq $false ) 
                        {
                            if($lstATag -ne $tag.href)
                            {
                                $desc = $desc.replace($tag.outerText,  " [" + $tag.outerText + "](" + $tag.href + ") " )
                            }
                            $lstATag = $tag.href                            
                        }
                        
                    }

                    Default {}
                }

                Write-Host "Desc After Switch :" $desc
            }    
       } 

       $contentData += " <U>Description: </U> " + $desc +  $([char]13) + $([char]10)  
       $lstBucket = $srt.Program
    }

    $lstBucket = ""
    $lstNull = "false"
    $contentData +=  $([char]13) + $([char]10) 
    $contentData +=  $([char]13) + $([char]10) 

    # second query - omit this section if query is not provided
    IF (![string]::IsNullOrEmpty($futureRelQuery.wiql) )
    {
    
        $contentData += "# " + $userParams.FutureQryText + $([char]13) + $([char]10) 
        $contentData +=  $([char]13) + $([char]10) 
        $contentData +=  $([char]13) + $([char]10) 
        [int]$cnt = 1
        
        # get future items
        foreach ($srt in $srtFutureData)
        {
            IF ([string]::IsNullOrEmpty($srt.Program) -and $lstNull -eq "false") 
            {
                $contentData +=  $([char]13) + $([char]10) 
                $contentData +=  $([char]13) + $([char]10) 
                $contentData += "##" + " No Program" + $([char]13) + $([char]10) 
                $lstBucket = ""
                $lstNull = "true"
            }
            else 
            {
                if($lstBucket -ne $srt.Program)
                {
                    $contentData +=  $([char]13) + $([char]10) 
                    $contentData +=  $([char]13) + $([char]10) 
                    $contentData += "## " + $srt.Program + $([char]13) + $([char]10) 
                    $cnt = 1
                }
            }

            $contentData += $cnt.ToString() + ". "
            $contentData += $srt.Title 

            $pjName = $userParams.ProjectName.Replace(" ","%20")
            $url = "(" + $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $pjName + "/_workitems/edit/" + $srt.id + ")"
            $contentData += " [" + $srt.id + "]" + $url  + $([char]13) + $([char]10) 
            
            $cnt = $cnt + 1
            $lstBucket = $srt.Program
        }
    }

    # set page name to todays date plus prefix
    $relpg = get-date -Format "yyyy-MM-dd" 
    $relpg += ":" + $userParams.PublishPagePrfx

    WriteToWikiPage -userParams $userParams -contentData $contentData -UsingExtension $UsingExtension -RelPageName $relpg 

       
}