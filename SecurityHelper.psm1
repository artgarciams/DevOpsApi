#
# FileName : SecurityHelper.psm1
# Data     : 03/20/2018
# Purpose  : this module has methods to allow for user and group security to be administered in a given VSTS project
#          : This script is for demonstration only not to be used as production code

     

#
#   list of available areas to secure in vsts
#
$project =  @{
    values = @(
        @{area="PROJECT"; displayName = "View project-level information"; bit = 1; action ="GENERIC_READ";}
        @{area="PROJECT"; displayName = "Edit project-level information"; bit = 2; action ="GENERIC_WRITE";}
        @{area="PROJECT"; displayName = "Delete team project"; bit =4; action ="DELETE";}
        @{area="PROJECT"; displayName = "Create test runs"; bit =8; action ="PUBLISH_TEST_RESULTS";}
        @{area="PROJECT"; displayName = "Administer a build"; bit=16; action ="ADMINISTER_BUILD";}
        @{area="PROJECT"; displayName = "Start a build"; bit=32; action ="START_BUILD"}        
        @{area="PROJECT"; displayName = "Edit build quality"; bit=64; action ="EDIT_BUILD_STATUS";}
        @{area="PROJECT"; displayName = "Write to build operational store"; bit=128; action ="UPDATE_BUILD";}
        @{area="PROJECT"; displayName = "Delete test runs"; bit =256; action ="DELETE_TEST_RESULTS";}
        @{area="PROJECT"; displayName = "View test runs"; bit =512; action ="VIEW_TEST_RESULTS";}
        @{area="PROJECT"; displayName = "Manage test environments"; bit =2048; action ="MANAGE_TEST_ENVIRONMENTS";}
        @{area="PROJECT"; displayName = "Manage test configurations"; bit =4096; action ="MANAGE_TEST_CONFIGURATIONS";}
        @{area="PROJECT"; displayName = "Delete and restore work items"; bit =8192; action ="WORK_ITEM_DELETE";}
        @{area="PROJECT"; displayName = "Move work items out of this project"; bit =16384; action ="WORK_ITEM_MOVE";}
        @{area="PROJECT"; displayName = "Permanently delete work items"; bit =32768; action ="WORK_ITEM_PERMANENTLY_DELETE";}
        @{area="PROJECT"; displayName = "Reaction team project"; bit =65536; action ="REaction";}
        @{area="PROJECT"; displayName = "Manage project properties"; bit =131072; action ="MANAGE_PROPERTIES";}
        @{area="PROJECT"; displayName = "Bypass rules on work item updates"; bit =1048576; action ="BYPASS_RULES";}
        @{area="PROJECT"; displayName = "Bypass project property cache"; bit=524288; action ="BYPASS_PROPERTY_CACHE";} 
        @{area="PROJECT"; displayName = "Suppress notifications for work item updates"; bit =2097152; action ="SUPPRESS_NOTIFICATIONS";}

        @{area="BUILD";bit=1; action="ViewBuilds"; displayName="View builds";}
        @{area="BUILD";bit=2; action="EditBuildQuality"; displayName="Edit build quality";}
        @{area="BUILD";bit=4; action="RetainIndefinitely"; displayName="Retain indefinitely"; }
        @{area="BUILD";bit=8; action="DeleteBuilds"; displayName="Delete builds";}
        @{area="BUILD";bit=16; action="ManageBuildQualities"; displayName="Manage build qualities"; }
        @{area="BUILD";bit=32; action="DestroyBuilds"; displayName="Destroy builds";}
        @{area="BUILD";bit=64; action="UpdateBuildInformation"; displayName="Update build information";}
        @{area="BUILD";bit=128; action="QueueBuilds"; displayName="Queue builds"; }
        @{area="BUILD";bit=256; action="ManageBuildQueue"; displayName="Manage build queue";}
        @{area="BUILD";bit=512; action="StopBuilds"; displayName="Stop builds";}
        @{area="BUILD";bit=1024; action="ViewBuildDefinition"; displayName="View build definition"; }
        @{area="BUILD";bit=2048; action="EditBuildDefinition"; displayName="Edit build definition";}
        @{area="BUILD";bit=4096; action="DeleteBuildDefinition"; displayName="Delete build definition"; }
        @{area="BUILD";bit=8192; action="OverrideBuildCheckInValidation"; displayName="Override check-in validation by build"; }
        @{area="BUILD";bit=16384; action="AdministerBuildPermissions"; displayName="Administer build permissions";}

        @{area="ReleaseManagement"; displayName = "View release definition"; bit=1; action="ViewReleaseDefinition";}
        @{area="ReleaseManagement"; displayName = "Edit release definition"; bit=2; action="EditReleaseDefinition";}
        @{area="ReleaseManagement"; displayName = "Delete release definition"; bit=4; action="DeleteReleaseDefinition";}
        @{area="ReleaseManagement"; displayName = "Manage release approvers"; bit=8; action="ManageReleaseApprovers";}
        @{area="ReleaseManagement"; displayName = "Manage releases"; bit=16; action="ManageReleases";}
        @{area="ReleaseManagement"; displayName = "View releases"; bit=32; action="ViewReleases";}
        @{area="ReleaseManagement"; displayName = "Create releases"; bit=64; action="CreateReleases";}
        @{area="ReleaseManagement"; displayName = "Edit release environment"; bit=128; action="EditReleaseEnvironment";}
        @{area="ReleaseManagement"; displayName = "Delete release environment";bit=256; action="DeleteReleaseEnvironment";}
        @{area="ReleaseManagement"; displayName = "Administer release permissions";bit=512; action="AdministerReleasePermissions";}
        @{area="ReleaseManagement"; displayName = "Delete releases";bit=1024; action="DeleteReleases";}
        @{area="ReleaseManagement"; displayName = "Manage deployments";bit=2048; action="ManageDeployments";}
        @{area="ReleaseManagement"; displayName = "Manage release settings";bit=4096; action="ManageReleaseSettings";}

        @{area="Git Repositories"; displayName = "Administer"; bit=1; action="Administer";}
        @{area="Git Repositories"; displayName = "Read"; bit=2; action="GenericRead";}
        @{area="Git Repositories"; displayName = "Contribute"; bit=4; action="GenericContribute";}
        @{area="Git Repositories"; displayName = "Force push (rewrite history, delete branches and tags)"; bit=8; action="ForcePush";}
        @{area="Git Repositories"; displayName = "Create Branch"; bit=16; action="CreateBranch";}
        @{area="Git Repositories"; displayName = "Create Tag"; bit=32; action="CreateTag";}
        @{area="Git Repositories"; displayName = "Manage Note"; bit=64; action="ManageNote";}
        @{area="Git Repositories"; displayName = "Exempt from policy enforcement"; bit=128; action="PolicyExempt";}
        @{area="Git Repositories"; displayName = "Create Repository";bit=256; action="CreateRepository";}
        @{area="Git Repositories"; displayName = "Delete Repository";bit=512; action="DeleteRepository";}
        @{area="Git Repositories"; displayName = "Reaction Repository";bit=1024; action="ReactionRepository";}
        @{area="Git Repositories"; displayName = "Edit Policies";bit=2048; action="EditPolicies";}
        @{area="Git Repositories"; displayName = "Remove others\u0027 locks";bit=4096; action="RemoveOthersLocks";}
        @{area="Git Repositories"; displayName = "Manage Permissions";bit=8192; action="ManagePermissions";}
        @{area="Git Repositories"; displayName = "Contribute to pull requests";bit=16384; action="PullRequestContribute";}
        

    )
}


function Get-PermissionBit(){
    param(
        [Parameter(Mandatory = $true)]
        $Permission
    )

    $fnd = $project.values | Where-Object {$_.action -eq $Permission}
    return $fnd
}


##############################
#.SYNOPSIS
#Short description
#  this function will set the access control entries for a given user. this will set the permissions
#  for the thye of object ie (project, build, etc)
#
#.PARAMETER userParams
#Parameter description
#
#.PARAMETER userSecurity
# {"user":"argarc@microsoft.com","permissions" :["MANAGE_PROPERTIES|ALLOW","PUBLISH_TEST_RESULTS|ALLOW"] 
##############################
function Set-UserSecurity()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        $userSecurity
    )
     
    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
       
    # find project id and then token. this token is for project level permisions TODO: find tokens for build, git, etc.
    $projectUri = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"
    $allPrjects = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
    $prjId = $allPrjects.value | Where-Object {$_.name -eq $userParams.ProjectName}

    # find security namespaces for area given ie : project, build, etc
    $secURL = " https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/securitynamespaces/00000000-0000-0000-0000-000000000000/?api-version=1.0"
    $namespaces = Invoke-RestMethod -Uri $secURL -Method Get -Headers $authorization -ContentType "application/json" 

    # loop thru the security list for each user
    foreach ($secUser in $userSecurity)
    {
        # get user descriptor
        $descriptor = Get-UserDescriptor -userParams $userParams -email $secUser.user

        # loop thru permissions for each user
        foreach( $perm in $secUser.permissions)
        {
            # "MANAGE_PROPERTIES|ALLOW
            $permissionList = $perm | Split-String -Separator "|"
              
            #get security bit based on allow or deny permission
            $deny = 0
            $allow =0
            $tkn = $null;

            switch ($permissionList[1]) {
                "DENY" { 
                    $prmObj = Get-PermissionBit  -Permission $permissionList[0];  
                    $deny = $prmObj.bit;
                     # token for project permissions
                    $tkn = "$" + $prmObj.area + ":vstfs:///Classification/TeamProject/" + $prjId.id 
                    $Sec = $namespaces.value | Where-Object {$_.name -eq $prmObj.area}
                }
                "ALLOW" { 
                    $prmObj = Get-PermissionBit -Permission $permissionList[0]; 
                    $allow = $prmObj.bit
                     # token for project permissions
                    $tkn = "$" + $prmObj.area + ":vstfs:///Classification/TeamProject/" + $prjId.id 
                    $Sec = $namespaces.value | Where-Object {$_.name -eq $prmObj.area}
                }
            }

            # create body - json request to set security for this user. ToDO: allow and deny will be params
            $tmData =  @{ token =$tkn ;
                merge = "True";
                accessControlEntries = @( @{
                    descriptor = $descriptor;
                    allow = $allow ;
                    deny =  $deny;  
                    extendedinfo = "{}";         
                })    
            }
            $acl = ConvertTo-Json -InputObject $tmData
            $acl = $acl -replace """{}""", '{}'

            # create  access control lists for given area = what to secure ie project, build, etc
            $nmURL = " https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/_apis/accesscontrolentries/" +  $Sec.namespaceId + "?api-version=4.1-preview"
            $results = Invoke-RestMethod -Uri $nmURL -Method Post -Headers $authorization -ContentType "application/json" -Body $acl
            # display results
            $out = ConvertTo-Json -InputObject $results
            Write-Host $out

        }
       
    }
      
}


function Get-UserDescriptor () {
    param(
        [Parameter(Mandatory = $true)]
        $userParams,
        $email
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # find domain id for user. need this for descriptor in accesscontrolentries
    $descriptorURL = " https://" + $userParams.VSTSMasterAcct + ".vsaex.visualstudio.com/_apis/userentitlements?top=100&skip=0&api-version=4.1-preview"
    $descriptor = Invoke-RestMethod -Uri $descriptorURL -Method Get -Headers $authorization  -ContentType "application/json"  
    
    # for later use
    #descriptor = "Microsoft.IdentityModel.Claims.ClaimsIdentity;" +  $domain + "\" + $userParams.userEmail
    #descriptor = "Microsoft.VisualStudio.Services.Identity;" + $grp.descriptor
   
    # # loop thru object to find domain for given user TODO: find better way to do this
    foreach($item in $descriptor.value)
    {
        foreach($usr in $item.user)
        {
            if($usr.mailAddress -eq $email )
            {
                $domain = $usr.domain;
                return "Microsoft.IdentityModel.Claims.ClaimsIdentity;" +  $domain + "\" + $email
            }
        }
    }

}

##############################
#.SYNOPSIS
#Short description
#  this function will set the access control entries for a geven group . this will set the permissions
#  for the thye of object ie (project, build, etc)
#
#.PARAMETER userParams
#Parameter description
#
#.PARAMETER userSecurity
# {"user":"argarc@microsoft.com","permissions" :["MANAGE_PROPERTIES|ALLOW","PUBLISH_TEST_RESULTS|ALLOW"] 
##############################
function Set-GroupSecurity()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        $groupSecurity
    )
     
    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
       
    # find project id and then token. this token is for project level permisions TODO: find tokens for build, git, etc.
    $projectUri = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"
    $allPrjects = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
    $prjId = $allPrjects.value | Where-Object {$_.name -eq $userParams.ProjectName}

    # find security namespaces for area given ie : project, build, etc
    $secURL = " https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/securitynamespaces/00000000-0000-0000-0000-000000000000/?api-version=1.0"
    $namespaces = Invoke-RestMethod -Uri $secURL -Method Get -Headers $authorization -ContentType "application/json" 

    
    # loop thru the security list for each user
    foreach ($secGroup in $groupSecurity)
    {
        # find group info
        $projectUri = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects/"+  $prjId.Id + "/teams?api-version=2.2"
        $allPrjects = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
        
        # get access control list for namespace
        $nsp = $namespaces.value | Where-Object {$_.displayName -eq "build"}
        $js =ConvertTo-Json -InputObject $nsp -Depth 4
        Out-File -FilePath "C:\temp\namespace_build.json"  -InputObject $js 

        
        # get all enabled groups
        $aclUrl = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/_apis/graph/groups?api-version=3.0-preview.2"
        $aclList = Invoke-RestMethod -Uri $aclUrl -Method Get -Headers $authorization -ContentType "application/json" 

        $js =ConvertTo-Json -InputObject $aclList -Depth 4
        Out-File -FilePath "C:\temp\groups.json"  -InputObject $js 

        $aclUrl = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/_apis/accesscontrollists/" + $nsp.namespaceId + "?api-version=4.1-preview.1"
        $aclList = Invoke-RestMethod -Uri $aclUrl -Method Get -Headers $authorization -ContentType "application/json" 
        $js =ConvertTo-Json -InputObject $aclList -Depth 4
        Out-File -FilePath "C:\temp\aclList_build1.json"  -InputObject $js 
    

        # get user descriptor
        $descriptor = Get-GroupDescriptor -userParams $userParams -groupName $secGroup.name

        # loop thru permissions for each user
        foreach( $perm in $secGroup.permissions)
        {
            # "MANAGE_PROPERTIES|ALLOW
            $permissionList = $perm | Split-String -Separator "|"
              
            #get security bit based on allow or deny permission
            $deny = 0
            $allow =0
            $tkn = $null;

            switch ($permissionList[1]) {
                "DENY" { 
                    $prmObj = Get-PermissionBit  -Permission $permissionList[0];  
                    $deny = $prmObj.bit;
                     # token for project permissions
                    $tkn = "$" + $prmObj.area + ":vstfs:///Classification/TeamProject/" + $prjId.id 
                    $Sec = $namespaces.value | Where-Object {$_.name -eq $prmObj.area}
                }
                "ALLOW" { 
                    $prmObj = Get-PermissionBit -Permission $permissionList[0]; 
                    $allow = $prmObj.bit
                     # token for project permissions
                    $tkn = "$" + $prmObj.area + ":vstfs:///Classification/TeamProject/" + $prjId.id 
                    $Sec = $namespaces.value | Where-Object {$_.name -eq $prmObj.area}
                }
            }

            # create body - json request to set security for this user. ToDO: allow and deny will be params
            $tmData =  @{ token =$tkn ;
                merge = "True";
                accessControlEntries = @( @{
                
                    descriptor = $descriptor;
                    allow = $allow ;
                    deny =  $deny;  
                    extendedinfo = "{}";         
                })    
            }
            $acl = ConvertTo-Json -InputObject $tmData
            $acl = $acl -replace """{}""", '{}'

            # create  access control lists for given area = what to secure ie project, build, etc
            $nmURL = " https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/_apis/accesscontrolentries/" +  $Sec.namespaceId + "?api-version=4.1-preview"
            $results = Invoke-RestMethod -Uri $nmURL -Method Post -Headers $authorization -ContentType "application/json" -Body $acl
          
            # display results
            $out = ConvertTo-Json -InputObject $results
            Write-Host $out

        }
       
    }
      
}


##############################
#
# this function will create the tfssecurity.exe command to change permissions for a given group and area
# https://docs.microsoft.com/en-us/vsts/tfs-server/command-line/tfssecurity-cmd?toc=/vsts/security/toc.json&bc=/vsts/security/breadcrumb/toc.json&view=tfs-2017
##############################
function Add-GroupSecurity()
{
    Param(
        [Parameter(Mandatory = $true)]
        $ProjectName,
        [Parameter(Mandatory = $true)]
        $VSTSMasterAcct,
        [Parameter(Mandatory = $true)]
        $authorization,
        [Parameter(Mandatory = $true)]
        $teamList,
        [Parameter(Mandatory = $false)]
        [string]$exePath =  [System.Management.Automation.Language.NullString]::Value,

        [Parameter(Mandatory = $false)]
        [string]$vstsGroup = [System.Management.Automation.Language.NullString]::Value
        
    )
       
    # get project id and then token
    $projectUri = "https://" + $VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"
    $allPrjects = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
    $fnd = $allPrjects.value | Where-Object {$_.name -eq $ProjectName}

    # get path to tfssecurity
    if($null -eq $exePath)
    {
        $exePath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\"
    }
    $pth = $exePath + "TFSSecurity.exe"

    foreach ($item in $teamList)
    {
        $cmd = ""

        # if vstsGroup has data the the permissions are for vsts group if not for a team
        if($null -eq $vstsGroup){
            $groupName = " n:" + $([char]34) + "[" + $ProjectName + "]\" + $item.name + $([char]34)            
        }
        else{
            $groupName = " n:" + $([char]34) + "[" + $VSTSMasterAcct + "]\" + $item.name + $([char]34)
        }

        foreach( $permission in $item.permissions)
        {
            # "PROJECT|MANAGE_TEST_ENVIRONMENTS|ALLOW"
            $permissionList = $permission | Split-String -Separator "|"

            $permData = Get-PermissionBit -Permission $permissionList[0]

            # set namespace and token
            if ( $permData.area.IndexOf(" ")  -ge 1) 
            {   
                #Git Repositories namespace has a space in it. must add quotes around namespace. generate token from namespace + project id      
                $tkn = "token:" + $permData.area.Replace(" ","") + ":" + $fnd.id  
                $namespace = " /a+ " + $([char]34) + $permData.area + $([char]34) + ' "' + $tkn + '"' 
            }else{
                $tkn =  "$" + $permData.area + ":vstfs:///Classification/TeamProject/" + $fnd.id  
                $namespace = " /a+ " + $permData.area + ' "' + $tkn + '"'                  
            }

            $action = $permData.action
            $accessLevel = $permissionList[1]
            $cmd += $namespace + " " + $action + " " + $groupName + " " + $accessLevel + " /collection:https://" + $VSTSMasterAcct + ".visualstudio.com"
            Write-Host $cmd

            Start-Process $pth -ArgumentList $cmd -NoNewWindow -Wait 
            $cmd = ""

            # find security namespaces for area given ie : project, build, etc
            # $secURL = " https://" + $VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/securitynamespaces/00000000-0000-0000-0000-000000000000/?api-version=1.0"
            # $namespaces = Invoke-RestMethod -Uri $secURL -Method Get -Headers $authorization -ContentType "application/json" 
            # $js = ConvertTo-Json -InputObject $namespaces -Depth 42
            # Out-File -FilePath "C:\temp\SecurityNamespaces.json" -InputObject $js 

            # $Sec = $namespaces.value | Where-Object {$_.name -eq $permissionList[0] }
                
            # $aclUrl = "https://" + $VSTSMasterAcct + ".visualstudio.com/_apis/accesscontrollists/" + $Sec.namespaceId + "?token=" + $tkn  +  "&api-version=4.1-preview.1"
            # $aclList = Invoke-RestMethod -Uri $aclUrl -Method Get -Headers $authorization -ContentType "application/json" 
           
            # $fp = "C:\temp\acl_" + $item.name + "_" + $permissionList[0] + "_.json"
            # $js = ConvertTo-Json -InputObject $aclList -Depth 42
            # Out-File -FilePath $fp -InputObject $js 

        }
    }    
}