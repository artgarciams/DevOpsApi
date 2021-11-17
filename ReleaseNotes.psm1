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
        $allWiki = Invoke-RestMethod -Uri $wikiUri -Method Get -Headers $authorization

        Write-Host ""
        Write-Host "==========   WiKi Page Build Section  =========="
        Write-Host "Wiki found :"  $allWiki.value[0].name
        $wiki = $allWiki.value[0]
        Write-Host "WiKi ID    :" $wiki.id

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
        $FindPageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $wiki.Name + "/pages?path=" + $userParams.PublishParent  + "&api-version=6.1-preview.1" 
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
        $CreatePageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $wiki.Name + "/pages?path=" + $userParams.PublishParent  + "&api-version=6.0" 
        $CreatePage = Invoke-RestMethod -Uri $CreatePageUri -Method Put -ContentType "application/json" -Headers $authorization -Body $tmJson
        Write-Host "Parent Page Created : $userParams.PublishParent  " $CreatePage

    }

    #
    # Create wiki page if it does not exist, if exists it will throw an error
    #
    # create project page in wiki
    $landingPg = $userParams.PublishParent + "/" + $userParams.PublishPagePrfx 

    try 
    {
       $blankData = @{
            content  = "Blank Page"
        }
        $BlankJson = ConvertTo-Json -InputObject $blankData
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/pages/create%20or%20update?view=azure-devops-rest-6.1
        # PUT https://dev.azure.com/{organization}/{project}/_apis/wiki/wikis/{wikiIdentifier}/pages?path={path}&api-version=6.1-preview.1
        $CreatePageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $wiki.Name + "/pages?path=" + $landingPg + "&api-version=6.0" 
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

  
    try {

        Write-Host "Begin Writting to WiKi "
        
        # Parent page / release notes page   
        $landingPg = $userParams.PublishParent + "/"  + $userParams.PublishPagePrfx 
        $tmData = @{
                content  = $contentData
        }
        $tmJson = ConvertTo-Json -InputObject $tmData
                              
        # add etag to the header. for update to work, must have etag in header
        # Base64-encodes the Personal Access Token (PAT) appropriately + etag used to allow update to wiki page
        $getPageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $wiki.Name + "/pages?path=" + $landingPg + "&recursionLevel=Full&api-version=6.0"
        $GetPage = Invoke-WebRequest -Uri $getPageUri -Method Get -ContentType "application/json" -Headers $authorization -UseBasicParsing

        # add etag to the header. for update to work, must have etag in header
        # Base64-encodes the Personal Access Token (PAT) appropriately + etag used to allow update to wiki page
        Write-Host $GetPage.Headers.ETag       
        if($UsingExtension -eq "yes")
        {
            Write-Host " Using System Access Token + ETag for update "
            $authorization =  GetADOTokenWithEtagForExt  -eTag $GetPage.Headers.ETag   
            Write-Host $authorization
        }else {
            $authorization = GetVSTSCredentialWithEtag -Token $userParams.PAT -userEmail $userParams.userEmail  -eTag $GetPage.Headers.ETag      
        }
       
        # update or create page if it does not exist
        $AddPageUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct +  "/" + $userParams.ProjectName + "/_apis/wiki/wikis/" + $wiki.Name + "/pages?path=" + $landingPg + "&api-version=6.0"
        $AddPage = Invoke-RestMethod -Uri $AddPageUri -Method Put -ContentType "application/json" -Headers $authorization -Body $tmJson -UseBasicParsing -Verbose

        Write-Host "Page created - Release Notes complete"
        Write-Host $AddPage

    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Error in getting updating Landing page : "  $ErrorMessage 
        Write-Host "Failed Item : "  $FailedItem
    }
  
    Write-Host "- Release Notes complete -"

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

