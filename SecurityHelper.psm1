#
# FileName : SecurityHelper.psm1
# Data     : 03/20/2018
# Purpose  : this module has methods to allow for user and group security to be administered in a given VSTS project
#          : This script is for demonstration only not to be used as production code
#
#   list of available areas to secure in vsts
#

$UIpermissionArray = @{ 
    Values = @(
        [pscustomobject]@{NameSpace="Analytics";Permission="Read";Display="View analytics";UI_Group="UI-Analytics";UI_Permission="View analytics";Bit="1"}
        [pscustomobject]@{NameSpace="AnalyticsViews";Permission="Edit";Display="Edit shared Analytics views";UI_Group="UI-Analytics";UI_Permission="Edit shared Analytics views";Bit="2"}
        [pscustomobject]@{NameSpace="AnalyticsViews";Permission="Delete";Display="Delete shared Analytics views";UI_Group="UI-Analytics";UI_Permission="Delete shared Analytics views";Bit="4"}
        [pscustomobject]@{NameSpace="Tagging";Permission="Create";Display="Create tag definition";UI_Group="UI-Boards";UI_Permission="Create tag definition";Bit="2"}
        [pscustomobject]@{NameSpace="Project";Permission="WORK_ITEM_DELETE";Display="Delete and restore work items";UI_Group="UI-Boards";UI_Permission="Delete and restore work items";Bit="8192"}
        [pscustomobject]@{NameSpace="Project";Permission="WORK_ITEM_MOVE";Display="Move work items out of this project";UI_Group="UI-Boards";UI_Permission="Move work items out of this project";Bit="16384"}
        [pscustomobject]@{NameSpace="Project";Permission="WORK_ITEM_PERMANENTLY_DELETE";Display="Permanently delete work items";UI_Group="UI-Boards";UI_Permission="Permanently delete work items";Bit="32768"}
        [pscustomobject]@{NameSpace="Project";Permission="BYPASS_RULES";Display="Bypass rules on work item updates";UI_Group="UI-Boards";UI_Permission="Bypass rules on work item updates";Bit="1048576"}
        [pscustomobject]@{NameSpace="Project";Permission="CHANGE_PROCESS";Display="Change process of team project.";UI_Group="UI-Boards";UI_Permission="Change process of team project.";Bit="8388608"}
        [pscustomobject]@{NameSpace="Project";Permission="GENERIC_READ";Display="View project-level information";UI_Group="UI-General";UI_Permission="View project-level information";Bit="1"}
        [pscustomobject]@{NameSpace="Project";Permission="GENERIC_WRITE";Display="Edit project-level information";UI_Group="UI-General";UI_Permission="Edit project-level information";Bit="2"}
        [pscustomobject]@{NameSpace="Project";Permission="DELETE";Display="Delete team project";UI_Group="UI-General";UI_Permission="Delete team project";Bit="4"}
        [pscustomobject]@{NameSpace="Project";Permission="RENAME";Display="Rename team project";UI_Group="UI-General";UI_Permission="Rename team project";Bit="65536"}
        [pscustomobject]@{NameSpace="Project";Permission="MANAGE_PROPERTIES";Display="Manage project properties";UI_Group="UI-General";UI_Permission="Manage project properties";Bit="131072"}
        [pscustomobject]@{NameSpace="Project";Permission="SUPPRESS_NOTIFICATIONS";Display="Suppress notifications for work item updates";UI_Group="UI-General";UI_Permission="Suppress notifications for work item updates";Bit="2097152"}
        [pscustomobject]@{NameSpace="Project";Permission="UPDATE_VISIBILITY";Display="Update project visibility";UI_Group="UI-General";UI_Permission="Update project visibility";Bit="4194304"}
        [pscustomobject]@{NameSpace="Project";Permission="PUBLISH_TEST_RESULTS";Display="Create test runs";UI_Group="UI-Test Plans";UI_Permission="Create test runs";Bit="8"}
        [pscustomobject]@{NameSpace="Project";Permission="DELETE_TEST_RESULTS";Display="Delete test runs";UI_Group="UI-Test Plans";UI_Permission="Delete test runs";Bit="256"}
        [pscustomobject]@{NameSpace="Project";Permission="VIEW_TEST_RESULTS";Display="View test runs";UI_Group="UI-Test Plans";UI_Permission="View test runs";Bit="512"}
        [pscustomobject]@{NameSpace="Project";Permission="MANAGE_TEST_ENVIRONMENTS";Display="Manage test environments";UI_Group="UI-Test Plans";UI_Permission="Manage test environments";Bit="2048"}
        [pscustomobject]@{NameSpace="Project";Permission="MANAGE_TEST_CONFIGURATIONS";Display="Manage test configurations";UI_Group="UI-Test Plans";UI_Permission="Manage test configurations";Bit="4096"}
        [pscustomobject]@{NameSpace="AuditLog";Permission="Read";Display="View audit log";UI_Group="Org-Auditing";UI_Permission="View audit log";Bit="1"}
        [pscustomobject]@{NameSpace="AuditLog";Permission="Manage_Streams";Display="Manage audit streams";UI_Group="Org-Auditing";UI_Permission="Manage audit streams";Bit="4"}
        [pscustomobject]@{NameSpace="AuditLog";Permission="Delete_Streams";Display="Delete audit streams";UI_Group="Org-Auditing";UI_Permission="Delete audit streams";Bit="8"}
        [pscustomobject]@{NameSpace="Process";Permission="Edit";Display="Edit process";UI_Group="Org-Boards";UI_Permission="Edit process";Bit="1"}
        [pscustomobject]@{NameSpace="Process";Permission="Delete";Display="Delete process";UI_Group="Org-Boards";UI_Permission="Delete process";Bit="2"}
        [pscustomobject]@{NameSpace="Process";Permission="Create";Display="Create process";UI_Group="Org-Boards";UI_Permission="Create process";Bit="4"}
        [pscustomobject]@{NameSpace="Process";Permission="AdministerProcessPermissions";Display="Administer process permissions";UI_Group="Org-Boards";UI_Permission="Administer process permissions";Bit="8"}
        [pscustomobject]@{NameSpace="Collection";Permission="DELETE_FIELD";Display="Delete field from organization";UI_Group="Org-Boards";UI_Permission="Delete field from organization";Bit="1024"}
        [pscustomobject]@{NameSpace="Collection";Permission="CREATE_PROJECTS";Display="Create new projects";UI_Group="Org-General";UI_Permission="Create new projects";Bit="4"}
        [pscustomobject]@{NameSpace="Collection";Permission="DIAGNOSTIC_TRACE";Display="Alter trace settings";UI_Group="Org-General";UI_Permission="Alter trace settings";Bit="64"}
        [pscustomobject]@{NameSpace="Collection";Permission="MANAGE_ENTERPRISE_POLICIES";Display="Manage enterprise policies";UI_Group="Org-Policies";UI_Permission="Manage enterprise policies";Bit="2048"}
        [pscustomobject]@{NameSpace="Collection";Permission="SYNCHRONIZE_READ";Display="View system synchronization information";UI_Group="Org-Service Account";UI_Permission="View system synchronization information";Bit="128"}
        [pscustomobject]@{NameSpace="Collection";Permission="MANAGE_TEST_CONTROLLERS";Display="Manage test controllers";UI_Group="Org-Test Plans";UI_Permission="Manage test controllers";Bit="512"}
        [pscustomobject]@{NameSpace="BuildAdministration";Permission="ViewBuildResources";Display="View build resources";UI_Group="Org-Pipelines";UI_Permission="View build resources";Bit="1"}
        [pscustomobject]@{NameSpace="BuildAdministration";Permission="ManageBuildResources";Display="Manage build resources";UI_Group="Org-Pipelines";UI_Permission="Manage build resources";Bit="2"}
        [pscustomobject]@{NameSpace="BuildAdministration";Permission="UseBuildResources";Display="Use build resources";UI_Group="Org-Pipelines";UI_Permission="Use build resources";Bit="4"}
        [pscustomobject]@{NameSpace="BuildAdministration";Permission="AdministerBuildResourcePermissions";Display="Administer build resource permissions";UI_Group="Org-Pipelines";UI_Permission="Administer build resource permissions";Bit="8"}
        [pscustomobject]@{NameSpace="BuildAdministration";Permission="ManagePipelinePolicies";Display="Manage pipeline policies";UI_Group="Org-Pipelines";UI_Permission="Manage pipeline policies";Bit="16"}
        [pscustomobject]@{NameSpace="VersionControlPrivileges";Permission="CreateWorkspace";Display="Create a workspace";UI_Group="Org-Repos";UI_Permission="Create a workspace";Bit="2"}
        [pscustomobject]@{NameSpace="VersionControlPrivileges";Permission="AdminWorkspaces";Display="Administer workspaces";UI_Group="Org-Repos";UI_Permission="Administer workspaces";Bit="4"}
        [pscustomobject]@{NameSpace="VersionControlPrivileges";Permission="AdminShelvesets";Display="Administer shelved changes";UI_Group="Org-Repos";UI_Permission="Administer shelved changes";Bit="8"}
        [pscustomobject]@{NameSpace="Server";Permission="GenericRead";Display="View instance-level information";UI_Group="Org-General";UI_Permission="View instance-level information";Bit="1"}
        [pscustomobject]@{NameSpace="Server";Permission="GenericWrite";Display="Edit instance-level information";UI_Group="Org-General";UI_Permission="Edit instance-level information";Bit="2"}
        [pscustomobject]@{NameSpace="Server";Permission="Impersonate";Display="Make requests on behalf of others";UI_Group="Org-Service Account";UI_Permission="Make requests on behalf of others";Bit="4"}
        [pscustomobject]@{NameSpace="Server";Permission="TriggerEvent";Display="Trigger events";UI_Group="Org-Service Account";UI_Permission="Trigger events";Bit="16"}

       )
}


function Get-DescriptorFromGroup()
{
    Param(
        [Parameter(Mandatory = $true)]
        $dscriptor
    )

    $b64 = $dscriptor.Split('.')[1]
    $rem = [math]::ieeeremainder( $b64.Length, 4 ) 
    
    $str = ""
    $ln1 = 0
    $dscrpt = ""

    if($rem -ne 0)
    {
        #if (lengthMod4 != 0)
        #    {
        #        //fix Invalid length for a Base-64 char array or string
        #        base64EncodedData += new string('=', 4 - lengthMod4);
        #    }
        $ln1 = (4 - [math]::Abs($rem))
        if ($ln1 -gt 2)
        {
            $ln1 = 2
        }

        $str = ("=" * $ln1)
        $b64 +=  $str

    }
    
    try {
       # Write-Host "Descriptor : " $b64
        $dscrpt = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($b64))
    }
    catch {
          $ErrorMessage = $_.Exception.Message
          $FailedItem = $_.Exception.ItemName
          Write-Host "Security Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
   
    return $dscrpt

}

#
# this function will get a list of all groups in the org and
# the permissions for each. it will get the direct permissions and then the extended permissions
# for any groups this group is a member of.
#
function Get-SecuritybyGroupByNamespace()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $outFile,
        [Parameter(Mandatory= $false)]
        $getAllProjects,
        [Parameter(Mandatory= $false)]
        $rawDataDump
    )

        # Base64-encodes the Personal Access Token (PAT) appropriately
        $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
        
        # set output file directory and name
        $outFile = $userParams.DirRoot + $userParams.SecurityDir + $outFile

        # get list of all security namespaces for organization
        $projectUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/securitynamespaces?api-version=5.0"
        $allNamespaces = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 
          
        # find all Teams in Org. needed to determine if group is a team or group
        # GET https://dev.azure.com/{organization}/_apis/teams?api-version=6.0-preview.3        
        $tmUrl = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/teams?api-version=6.0-preview.3"
        $allteams = Invoke-RestMethod -Uri $tmUrl -Method Get -Headers $authorization 
        
        # get all groups in org or just for a given project
        # vssgp,aadgp are the subject types use vssgp to get groups for a given project
        $projectUri = $userParams.HTTP_preFix  + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/groups?subjectTypes=vssgp&api-version=6.0-preview.1"
        $allGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization    
        if( $getAllProjects -eq "True")
        {
            $groups = $allGroups.value
        }else {
            # find all groups for given project   
            $groups = $allGroups.value | Where-Object {$_.principalName -match $userParams.ProjectName }
        }
      
        Write-Output 'Namespace|Project|Group Type|Group Name|Description|Permission Type|Permission|bit|Permission Name|Decoded Value|Raw Data|Inherited From'  | Out-File $outFile  

        # loop thru each group
        foreach ($fnd in $groups) {

            # find out if this is a team or project
            $prName = $fnd.principalName.Split('\')
            $projectName =  $prName[0].substring(1,$prname[0].length-2)
            $tm = $prName[1]
            $teamFound = $allteams.value | Where-Object {($_.ProjectName -eq $projectName) -and ($_.name -eq $tm)}
            $GroupType = "G-Delivered"
            IF (![string]::IsNullOrEmpty($teamFound)) {
                $GroupType = "T-Custom"                
            } 

            Write-Host $fnd.displayname
           # $dumpFile =  $userParams.DirRoot + $userParams.DumpDirectory  + $rawDataDump

            #get Direct permissions
            Get-PermissionsByNamespaceByGroup -Direct "Direct" -Namespaces $allNamespaces -userParams $userParams -projectName $projectName -GroupType $GroupType -fnd $fnd -rawDataDump $rawDataDump -outFile $outFile

            # find any groups this group is a member of
            $MemberOfGroups = Get-GroupMembership -userParams $userParams -fndGroup $fnd

            foreach ($item in $MemberOfGroups.value) 
            {
                # get decoded descriptor for the group 
                $dscrpt =  Get-DescriptorFromGroup -dscriptor $item.containerDescriptor 
                $dscrpt = "Microsoft.TeamFoundation.Identity;" + $dscrpt
               
                # get group data for group this parent group is a member of
                $grpUrl = $userParams.HTTP_preFix  + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/groups/" + $item.containerDescriptor  +"?api-version=6.1-preview.1"
                $grpMembership = Invoke-RestMethod -Uri $grpUrl -Method Get -Headers $authorization 
            
                # get any permissions from groups this group is a member of
                if($rawDataDump -ne "")
                {
                    $dumpFile =  "E_" + $grpMembership.displayName +"_" + $rawDataDump
                }
                Get-PermissionsByNamespaceByGroup -Direct "Extended" -Namespaces $allNamespaces -userParams $userParams -projectName $projectName -GroupType $GroupType -fnd $fnd -rawDataDump $dumpFile -outFile $outFile -GroupMember $grpMembership
                
            }

        }
       
}
 

Function Get-PermissionsByNamespaceByGroup()
{
    #
    #   this function will get the list of permissions for a given group.
    #   it will get either the direct or extended permissions. In order to get all the permissions
    #   you need to first get the direct permissions and then the extended permissions for each group the
    #   primary group is a memeber of.
    #
    Param(
        [Parameter(Mandatory = $true)]
        $Namespaces,
        [Parameter(Mandatory = $true)]
        $Direct,
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $projectName,
        [Parameter(Mandatory = $true)]
        $GroupType,
        [Parameter(Mandatory = $true)]
        $fnd,
        [Parameter(Mandatory = $true)]
        $rawDataDump,
        [Parameter(Mandatory = $true)]
        $outFile,
        [Parameter(Mandatory = $false)]
        $GroupMember
      
    )

    $inheritFrom = ""
    if ([string]::IsNullOrEmpty($GroupMember) )    
    {
        # get decoded descriptor for the group 
        $dscrpt =  Get-DescriptorFromGroup -dscriptor $fnd.descriptor
        $dscrpt = "Microsoft.TeamFoundation.Identity;" + $dscrpt
        $inheritFrom = ""
    }else
    {
        # get descriptor for the group   
        $dscrpt =  Get-DescriptorFromGroup -dscriptor $GroupMember.Descriptor
        $dscrpt = "Microsoft.TeamFoundation.Identity;" + $dscrpt      
        $inheritFrom = $GroupMember.principalName
    }
   
    # find all access control lists for the given namespace and group
    # loop thru each namespace in the list and get security
    for ($n = 0; $n -lt $userParams.Namespaces.Count; $n++) {

        # get namespace
        $nmeSpace =  $userParams.Namespaces[$n]
        Write-Host $nmeSpace 
        $ns = $Namespaces.value | Where-Object {$_.Name -eq $nmeSpace }

        $aclListByNamespace = ""
        $hasPermission = $false
        $errorfile = $userParams.DirRoot + $userParams.LogDirectory + "Error.txt"

         # set permissions used. use this to find permissions not set
         $permsSet = ""

        # find all access control lists for the given namespace and group
        # get ACL for the given namespace and group( descriptor) set api to include extended  info properties        
        # for the parent group get diect membership, for the groups the parent is a member of get extended info
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/security/access%20control%20lists/query?view=azure-devops-rest-6.1#examples  
        #
        # link to issue and how we solved it
        # https://developercommunity2.visualstudio.com/t/security-api-for-acl-for-given-namespace-and-descr/1230600?from=email#T-ND1232440
        #
        switch ( $Direct ) {
           "Direct" {
               #  get direct permissions
               $grpUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?descriptors=" + $dscrpt + "&api-version=6.1-preview.1"
           }
           "Child" {
                #  get child permissions
                $grpUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?descriptors=" + $dscrpt + "&includeExtendedInfo=False&recurse=True&api-version=6.1-preview.1"                       
            }
            "Extended" {
                #  get Extended permissions
                $grpUri = $userParams.HTTP_preFix  + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?descriptors=" + $dscrpt + "&includeExtendedInfo=True&recurse=True&api-version=6.1-preview.1"            
            }
            Default {}
        }

        #check for CRLF in description
        $des = $fnd.description.replace("`n",", ").replace("`r",", ")

        try {
            $aclListByNamespace = Invoke-RestMethod -Uri $grpUri -Method Get -Headers $authorization 
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Security Error : " + $ErrorMessage + " iTEM : " + $FailedItem

         
                Write-Output "Error in namespace :" $ns.name | Out-File $errorfile -Append
                Write-Output "         Error : " $ErrorMessage | Out-File $errorfile -Append -NoNewLine            
                Write-Output " iTEM : " $FailedItem | Out-File $errorfile -Append
                Write-Output "         grpUri :" | Out-File $errorfile -Append -NoNewline
                Write-Output $grpUri | Out-File $errorfile -Append 
                Write-Output "" | Out-File $errorfile -Append
            
        }
       
        # get dump of data to process - for debugging
        if (![string]::IsNullOrEmpty($rawDataDump) )                
        {
            $outname =  $userParams.DirRoot + $userParams.DumpDirectory + $projectName +"_" + $fnd.displayname + "_" + $ns.name + "_" + $rawDataDump
            
          
                Write-Output $projectName  " - " $fnd.displayname " - " $ns.name | Out-File $outname -Append -NoNewline
                Write-Output " " | Out-File $outname -Append
            
                for ($i = 0; $i -lt $aclListByNamespace.Count; $i++) {
                    $t =  ConvertTo-Json -InputObject $aclListByNamespace.value[$i] -Depth 42                         
                    Write-Output $t | Out-File $outname -Append
                }
            
        }
       
        # loop thru acesDictionary in namespace and find security
        for ($i = 0; $i -lt $aclListByNamespace.value.length; $i++) {
            
            # list access control entry for each dictionary 
            $aclListByNamespace.value[$i].acesDictionary.PSObject.Properties | ForEach-Object {
                        
                Write-Host "Security for group : " $fnd.DisplayName
                Write-Host $aclListByNamespace.value[$i].acesDictionary

                # check allow permissions
                if($_.Value.allow -gt 0 )
                {                           
                    $permAllow = [convert]::ToString($_.Value.allow,2)
                    # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                    for ($a =  $permAllow.Length-1; $a -ge 0; $a--) 
                    {
                        # need to traverse the string in reverse to match the action list
                        $Allowplace = ( ($a - $permAllow.Length) * -1 )-1
                        Write-Host "      " $ns.actions[$Allowplace].displayName

                        if( $permAllow.Substring($a,1) -ge 1)
                        {
                            
                            # find bit in action list
                            $raise = [Math]::Pow(2, $Allowplace)
                            $bit = $ns.actions | Where-Object {$_.bit -eq $raise }

                                # find ui permission
                                $UIPerm =  Get-UIPermission -bit $bit -namespace $ns.name
                                if (![string]::IsNullOrEmpty($UIPerm )  )
                                {
                                    $permsSet += [convert]::ToString($bit.bit) + "|"
                                    Write-Output $UIPerm.UI_Group '|'  | Out-File $outFile  -Append -NoNewline
                                }else {
                                    Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                }

                                Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                                Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                                Write-Output $fnd.displayName  '|'   | Out-File $outFile -Append -NoNewline
                                Write-Output $des'|'  | Out-File $outFile  -Append -NoNewline
                                Write-Output 'Allow|'  $bit.displayName "|"  $bit.bit "|"  $bit.Name  "|" | Out-File $outFile  -Append -NoNewline
                                Write-Output $permAllow  "|" $_.Value.allow "|" $inheritFrom | Out-File -FilePath $outFile -Append -NoNewline
                                Write-Output " " | Out-File -FilePath $outFile -Append  
                                $hasPermission = $true                                    
                            
                        }
                    }
                }

                # check effective allow permissions -and ($lastDescriptor -ne $_.Value.descriptor)
                if (![string]::IsNullOrEmpty($_.Value.extendedInfo.effectiveAllow )  )
                {                   
                    if( ($_.Value.extendedInfo.effectiveAllow -gt 0)  )
                    {
                        $effAllow = [convert]::ToString($_.Value.extendedInfo.effectiveAllow,2)
                        # make sure allow and effective allow are not the same
                        if( $permAllow -ne $effAllow)
                        {
                            # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                            for ($a =  $effAllow.Length-1; $a -ge 0; $a--) 
                            {
                                # need to traverse the string in reverse to match the action list
                                $effAllowplace = ( ($a - $effAllow.Length) * -1 )-1
                                Write-Host "      " $ns.actions[$effAllowplace].displayName

                                if( $effAllow.Substring($a,1) -ge 1)
                                {
                                    $raise = [Math]::Pow(2, $effAllowplace)
                                    $bit = $ns.actions | Where-Object {$_.bit -eq $raise }
                                  
                                        # find ui permission
                                        $UIPerm =  Get-UIPermission -bit $bit -namespace $ns.name
                                        if (![string]::IsNullOrEmpty($UIPerm )  )
                                        {
                                            $permsSet += [convert]::ToString($bit.bit) + "|"
                                            Write-Output $UIPerm.UI_Group '|'  | Out-File $outFile  -Append -NoNewline
                                        }else {
                                            Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                        }
                                        Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                                        Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                                        Write-Output $fnd.displayName  '|'   | Out-File $outFile -Append -NoNewline
                                        Write-Output $des '|'  | Out-File $outFile  -Append -NoNewline                                        
                                        Write-Output 'Allow(Effective)|' $bit.displayName "|" $bit.bit "|" $bit.Name  "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $effAllow  "|" $_.Value.extendedInfo.effectiveAllow "|" $inheritFrom | Out-File -FilePath $outFile -Append -NoNewline
                                        Write-Output " " | Out-File -FilePath $outFile -Append  
                                        
                                        $hasPermission = $true
                                   
                                
                                }
                            }
                        }
                    }
                }

                # check inherited allow permissions -and ($lastDescriptor -ne $_.Value.descriptor)
                if (![string]::IsNullOrEmpty($_.Value.extendedInfo.inheritedAllow )   )
                {                   

                    # Write-Host $_.Value.descriptor
                    if( ($_.Value.extendedInfo.inheritedAllow -gt 0)  )
                    {
            
                        $inhAllow = [convert]::ToString($_.Value.extendedInfo.inheritedAllow,2)

                        # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                        for ($a =  $inhAllow.Length-1; $a -ge 0; $a--) 
                        {
                            # need to traverse the string in reverse to match the action list
                            $inhAllowplace = ( ($a - $inhAllow.Length) * -1 )-1
                            Write-Host "      " $ns.actions[$inhAllowplace].displayName

                            if( $inhAllow.Substring($a,1) -ge 1)
                            {
                                $raise = [Math]::Pow(2, $inhAllowplace)
                                $bit = $ns.actions | Where-Object {$_.bit -eq $raise }

                                # find ui permission
                                $UIPerm =  Get-UIPermission -bit $bit -namespace $ns.name
                                if (![string]::IsNullOrEmpty($UIPerm )  )
                                {
                                    $permsSet += [convert]::ToString($bit.bit) + "|"
                                    Write-Output $UIPerm.UI_Group '|'  | Out-File $outFile  -Append -NoNewline
                                }else {
                                    Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                }
                                Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                                Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                                Write-Output $fnd.displayName  '|'   | Out-File $outFile -Append -NoNewline
                                Write-Output $des '|'  | Out-File $outFile  -Append -NoNewline
                                Write-Output 'Allow(Inherited)|' $bit.displayName "|" $bit.bit "|" $bit.Name  "|" | Out-File $outFile  -Append -NoNewline
                                Write-Output $inhAllow  "|" $_.Value.extendedInfo.inheritedAllow "|" $inheritFrom | Out-File -FilePath $outFile -Append -NoNewline
                                Write-Output " " | Out-File -FilePath $outFile -Append  
                                                                        
                                $hasPermission = $true
                            
                            }
                        }

                    }
                }

                # check deny
                if($_.Value.deny -gt 0 )
                {
                
                    $permDeny = [convert]::ToString($_.Value.deny,2)
                
                    # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                    for ($a =  $permDeny.Length-1; $a -ge 0; $a--) 
                    {
                        # need to traverse the string in reverse to match the action list
                        $Denyplace = ( ($a - $permDeny.Length) * -1 )-1
                        Write-Host "      " $ns.actions[$Denyplace].displayName

                        if( $permDeny.Substring($a,1) -ge 1)
                        {
                            $raise = [Math]::Pow(2, $inhAllowplace)
                            $bit = $ns.actions | Where-Object {$_.bit -eq $raise }

                            # find ui permission
                            $UIPerm =  Get-UIPermission -bit $bit -namespace $ns.name
                            if (![string]::IsNullOrEmpty($UIPerm )  )
                            {
                                $permsSet += [convert]::ToString($bit.bit) + "|"
                                Write-Output $UIPerm.UI_Group '|'  | Out-File $outFile  -Append -NoNewline
                            }else {
                                Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                            }
                            Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                            Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                            Write-Output $fnd.displayName  '|'   | Out-File $outFile -Append -NoNewline
                            Write-Output $des'|'  | Out-File $outFile  -Append -NoNewline
                            Write-Output 'Deny|' $bit.displayName "|" $bit.bit "|" $bit.Name  "|" | Out-File $outFile  -Append -NoNewline
                            Write-Output $permDeny  "|" $_.Value.deny  "|" $inheritFrom| Out-File $outFile -Append -NoNewline
                            Write-Output " " | Out-File -FilePath $outFile -Append  
                        
                            $hasPermission = $true
                        
                        }
                    }

                }

                # check effective deny permissions 
                if (![string]::IsNullOrEmpty($_.Value.extendedInfo.effectiveDeny )  )
                {                   
                    
                    # Write-Host $_.Value.descriptor
                    if( ($_.Value.extendedInfo.effectiveDeny -gt 0)  )
                    {
                                            
                        $effDeny = [convert]::ToString($_.Value.extendedInfo.effectiveDeny,2)

                        # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                        for ($a =  $effDeny.Length-1; $a -ge 0; $a--) 
                        {
                            # need to traverse the string in reverse to match the action list
                            $EffDenyplace = ( ($a - $effDeny.Length) * -1 )-1
                            Write-Host $effDeny

                            if( $effDeny.Substring($a,1) -ge 1)
                            {
                                
                                $raise = [Math]::Pow(2, $EffDenyplace)
                                $bit = $ns.actions | Where-Object {$_.bit -eq $raise }

                                # find ui permission
                                $UIPerm =  Get-UIPermission -bit $bit -namespace $ns.name
                                if (![string]::IsNullOrEmpty($UIPerm )  )
                                {
                                    $permsSet += [convert]::ToString($bit.bit) + "|"
                                    Write-Output $UIPerm.UI_Group '|'  | Out-File $outFile  -Append -NoNewline
                                }else {
                                    Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                }
                                Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                                Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                                Write-Output $fnd.DisplayName  '|'   | Out-File $outFile -Append -NoNewline
                                Write-Output $des '|'  | Out-File $outFile  -Append -NoNewline
                                Write-Output 'Deny(Effective)|' $bit.displayName "|" $bit.bit "|" $bit.Name  "|" | Out-File $outFile  -Append -NoNewline
                                Write-Output $effDeny  "|" $_.Value.extendedInfo.effectiveDeny "|" $inheritFrom| Out-File -FilePath $outFile -Append -NoNewline
                                
                                Write-Output " " | Out-File -FilePath $outFile -Append  
                                
                                $hasPermission = $true
                            
                            }
                        }

                    }
                }

                # check inherited deny permissions 
                if (![string]::IsNullOrEmpty($_.Value.extendedInfo.InheritedDeny )  )
                {                   
                    
                    # Write-Host $_.Value.descriptor
                    if( ($_.Value.extendedInfo.InheritedDeny -gt 0)  )
                    {
                                            
                        $inhDeny = [convert]::ToString($_.Value.extendedInfo.InheritedDeny,2)

                        # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                        for ($a =  $inhDeny.Length-1; $a -ge 0; $a--) 
                        {
                            # need to traverse the string in reverse to match the action list
                            $EffDenyplace = ( ($a - $inhDeny.Length) * -1 )-1
                            Write-Host $effDeny

                            if( $inhDeny.Substring($a,1) -ge 1)
                            {
                                
                                $raise = [Math]::Pow(2, $EffDenyplace)
                                $bit = $ns.actions | Where-Object {$_.bit -eq $raise }

                                # find ui permission
                                $UIPerm =  Get-UIPermission -bit $bit -namespace $ns.name
                                if (![string]::IsNullOrEmpty($UIPerm )  )
                                {
                                    $permsSet += [convert]::ToString($bit.bit) + "|"
                                    Write-Output $UIPerm.UI_Group '|'  | Out-File $outFile  -Append -NoNewline
                                }else {
                                    Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                }
                                Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                                Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                                Write-Output $fnd.DisplayName  '|'   | Out-File $outFile -Append -NoNewline
                                Write-Output $des '|'  | Out-File $outFile  -Append -NoNewline
                                Write-Output 'Deny(Inherited)|' $bit.displayName "|" $bit.bit "|" $bit.Name  "|" | Out-File $outFile  -Append -NoNewline
                                Write-Output $effDeny  "|" $_.Value.extendedInfo.InheritedDeny "|" $inheritFrom| Out-File -FilePath $outFile -Append -NoNewline
                                
                                Write-Output " " | Out-File -FilePath $outFile -Append  
                                
                                $hasPermission = $true
                            
                            }
                        }

                    }
                }

            }

        }

        # list permissions not set in ui
        if($permsSet -ne "")
        {
            $allPermsForUiNamespace = $UIpermissionArray.Values | Where-Object {$_.NameSpace -eq $ns.name}
            $permsetArray = $permsSet.Split('|')

            foreach ($item in $allPermsForUiNamespace) 
            {
                if($permsetArray -contains $item.Bit )
                {
                    Write-Host $item
                }else
                {
                    Write-Output $item.UI_group '|'  | Out-File $outFile  -Append -NoNewline
                    Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                    Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                    Write-Output $tm  '|'   | Out-File $outFile -Append -NoNewline
                    Write-Output $des '|'  | Out-File $outFile  -Append -NoNewline
                    Write-Output 'Not Set|'  $item.Display '|' $item.Bit '|0|0|0|' $inheritFrom | Out-File $outFile  -Append -NoNewline
                    Write-Output ' '  | Out-File $outFile  -Append 
                    $hasPermission = $true
                }
            }

        }
        else
        {
            # no ui permission set for this namespace, list all as not set
            $allPermsForUiNamespace = $UIpermissionArray.Values | Where-Object {$_.NameSpace -eq $ns.name}
            foreach ($item in $allPermsForUiNamespace) 
            {
                if( $ns.name -eq "Analytics")
                {
                    Write-Output "UI-Analytics" '|'  | Out-File $outFile  -Append -NoNewline
                    Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                    Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                    Write-Output $tm  '|'   | Out-File $outFile -Append -NoNewline
                    Write-Output $des '|'  | Out-File $outFile  -Append -NoNewline
                    Write-Output 'Allow(inherited)|View analytics|0|0|0|0|' $inheritFrom | Out-File $outFile  -Append -NoNewline
                    Write-Output ' '  | Out-File $outFile  -Append 
                    $hasPermission = $true
                }else 
                {
                    Write-Output $item.UI_group '|'  | Out-File $outFile  -Append -NoNewline
                    Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                    Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                    Write-Output $tm  '|'   | Out-File $outFile -Append -NoNewline
                    Write-Output $des '|'  | Out-File $outFile  -Append -NoNewline
                    Write-Output 'Not Set|'  $item.Display '|' $item.Bit '|0|0|0|' $inheritFrom | Out-File $outFile  -Append -NoNewline
                    Write-Output ' '  | Out-File $outFile  -Append 
                    $hasPermission = $true
                }
            }
        }

        # if no permission ser still add team  View analytics",UI="Analytics",UI_Permission="View analytics",Bit="1"},
        if($hasPermission -eq $false)
        {
            if( $ns.name -eq "Analytics" -and $inheritFrom -ne "")
            {
                Write-Output "UI-Analytics" '|'  | Out-File $outFile  -Append -NoNewline
                Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                Write-Output $tm  '|'   | Out-File $outFile -Append -NoNewline
                Write-Output $des '|'  | Out-File $outFile  -Append -NoNewline
                Write-Output 'Allow(inherited)|View analytics|0|0|0|0|' $inheritFrom | Out-File $outFile  -Append -NoNewline
                Write-Output ' '  | Out-File $outFile  -Append 
                $hasPermission = $true
            }
            else {
                Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                Write-Output $tm  '|'   | Out-File $outFile -Append -NoNewline
                Write-Output $des '|'  | Out-File $outFile  -Append -NoNewline
                Write-Output 'No Permission set|No Permission Set|0|0|0|0|' $inheritFrom | Out-File $outFile  -Append -NoNewline
                Write-Output ' '  | Out-File $outFile  -Append 
            }
        }
    }
}

function Get-UIPermission()
{
    Param(
        [Parameter(Mandatory = $true)]
        $bit,
        [Parameter(Mandatory = $false)]
        $namespace
    )

    $UIPerm = $UIpermissionArray.Values | Where-Object {$_.UI_Permission -eq $bit.displayName -and $_.NameSpace -eq $namespace}
    return $UIPerm
}

function Get-MembersByTeam
{
    # this function will get all members of a given team
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $teamId
      
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

     # get project id
     #GET https://dev.azure.com/{organization}/_apis/projects?api-version=5.0
     $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects?api-version=5.0"
     $currProjects = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization 

     $fnd = $currProjects.value | Where-Object {$_.name -eq $userParams.ProjectName}
     IF (![string]::IsNullOrEmpty($fnd)) {
         Write-Host "Project found"        
     } 

     # get all teams and then specific team. need team id
     $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/teams?api-version=5.0-preview.2"
     $allTeams = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization 

     $fndTeam = $allTeams.value | Where-Object {$_.name -eq $teamId}
     IF (![string]::IsNullOrEmpty($fndTeam)) {
        Write-Host "Team found"        
    } 

     # get liest of memners of given team
     #GET https://dev.azure.com/{organization}/_apis/projects/{projectId}/teams/{teamId}/members?api-version=5.0
     $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects/" + $fnd.id+ "/teams/" + $teamId + "/members?api-version=5.0"
     $allTeamMembers = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 


}
              
       


function Get-NamespaceByGroup(){
    # this function will get all security namespaces for each group in the organization
    Param(
        [Parameter(Mandatory = $true)]
        $userParams
    )
    
    try {
          # Base64-encodes the Personal Access Token (PAT) appropriately
          $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

          # get list of all security namespaces for organization
          $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/securitynamespaces?api-version=5.0"
          $allNamespaces = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 
          
          # filter out the namespace to look for
          $oneNamespace = $allNamespaces.value | Where-Object {$_.displayName -match "Project"}
          
          # find all groups in organization and then filter by project
          $projectUri = $userParams.HTTP_preFix + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/groups?api-version=5.0-preview.1"
          $allGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 

          # find all groups for given project
          $fnd = $allGroups.value | Where-Object {$_.principalName -match $userParams.ProjectName }
          
          # for each group get descriptor, decode base64 descriptor and look it up in acl
          foreach ($grp in $fnd) 
          {
                # get decoded descriptor
                $dscrpt =  Get-DescriptorFromGroup -dscriptor $grp.descriptor
                $dscrpt = "Microsoft.TeamFoundation.Identity;" + $dscrpt

                # loop thru namespace and find ACL
                foreach( $ns in $oneNamespace)
                {
                    #Write-Host "Namespace : " + $ns.namespaceId + "   " + $ns.displayName
                    $grpUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?api-version=5.1"
                    $aclListByGroup = Invoke-RestMethod -Uri $grpUri -Method Get -Headers $authorization 
                    
                    # loop thru each acl looking for matck
                    foreach($acl in $aclListByGroup.value )
                    {             
                        Write-Host $acl.Token , $acl.acesDictionary
                        $out = ConvertTo-Json -InputObject $acl.acesDictionary -Depth 42
                        Write-Host $out.allow

                        foreach ($h in $acl.acesDictionary)
                        {
                            Write-Host $h

                        }
                       
                    }
                }
            }
            
           
            # get ACL list by descriptor
            # https://spsprodeus23.vssps.visualstudio.com/{organization}/_apis/Identities?searchFilter=DisplayName&filterValue={groupName}&options=None&queryMembership=None
            # GET https://dev.azure.com/{organization}/_apis/accesscontrollists/{securityNamespaceId}?api-version=5.1
            #$grpUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?api-version=5.1"
            #$aclListByGroup = Invoke-RestMethod -Uri $grpUri -Method Get -Headers $authorization 
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Error : " + $ErrorMessage + " iTEM : " + $FailedItem
        }
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
    $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"
    $allPrjects = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
    $prjId = $allPrjects.value | Where-Object {$_.name -eq $userParams.ProjectName}

    # find security namespaces for area given ie : project, build, etc
    $secURL = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/securitynamespaces/00000000-0000-0000-0000-000000000000/?api-version=1.0"
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
    $descriptorURL = " https://" + $userParams.VSTSMasterAcct + ".vsaex.visualstudio.com/_apis/userentitlements?top=1000&skip=0&api-version=4.1-preview"
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


function Get-UserDescriptorById () {
    param(
        [Parameter(Mandatory = $true)]
        $userParams,
        $id
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # find domain id for user. need this for descriptor in accesscontrolentries
    $descriptorURL = " https://" + $userParams.VSTSMasterAcct + ".vsaex.visualstudio.com/_apis/userentitlements?top=1000&skip=0&api-version=4.1-preview"
    $descriptor = Invoke-RestMethod -Uri $descriptorURL -Method Get -Headers $authorization  -ContentType "application/json"  
    
    # for later use
    #descriptor = "Microsoft.IdentityModel.Claims.ClaimsIdentity;" +  $domain + "\" + $userParams.userEmail
    #descriptor = "Microsoft.VisualStudio.Services.Identity;" + $grp.descriptor
    $fnd = $descriptor.value | Where-Object {($_.id -eq $id)}
    
    # # loop thru object to find domain for given user TODO: find better way to do this
    foreach($item in $descriptor.value)
    {
        foreach($usr in $item.user)
        {
            if($usr.id -eq $id )
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
    $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"
    $allPrjects = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
    $prjId = $allPrjects.value | Where-Object {$_.name -eq $userParams.ProjectName}

    # find security namespaces for area given ie : project, build, etc
    $secURL = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/securitynamespaces/00000000-0000-0000-0000-000000000000/?api-version=1.0"
    $namespaces = Invoke-RestMethod -Uri $secURL -Method Get -Headers $authorization -ContentType "application/json" 

    
    # loop thru the security list for each user
    foreach ($secGroup in $groupSecurity)
    {
        # find group info
        $projectUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects/"+  $prjId.Id + "/teams?api-version=2.2"
        $allPrjects = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
        
        # get access control list for namespace
        $nsp = $namespaces.value | Where-Object {$_.displayName -eq "build"}
        $js =ConvertTo-Json -InputObject $nsp -Depth 4
        Out-File -FilePath "C:\temp\namespace_build.json"  -InputObject $js 

        
        # get all enabled groups
        $aclUrl = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/_apis/graph/groups?api-version=3.0-preview.2"
        $aclList = Invoke-RestMethod -Uri $aclUrl -Method Get -Headers $authorization -ContentType "application/json" 

        $js =ConvertTo-Json -InputObject $aclList -Depth 4
        Out-File -FilePath "C:\temp\groups.json"  -InputObject $js 

        $aclUrl = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".visualstudio.com/_apis/accesscontrollists/" + $nsp.namespaceId + "?api-version=4.1-preview.1"
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
    $projectUri = $userParams.HTTP_preFix + "://" + $VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"
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



function Get-GroupSecurityTFS()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams
        
    )
       
    
     # Base64-encodes the Personal Access Token (PAT) appropriately
     $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # find list of all Groups  # https://vssps.dev.azure.com/{organization}/_apis/graph/groups?api-version=5.1-preview.1
    $projectUri = $userParams.HTTP_preFix + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/groups?api-version=5.1-preview.1"
    $allGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
   
    # find groups for the current project
    $fnd = $allGroups.value | Where-Object {$_.principalName -match  $userParams.ProjectName }
   
    # get path to tfssecurity
    $exePath = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\"
   
    $pth = $exePath + "TFSSecurity.exe"

    foreach ($item in $fnd)
    {
        $cmd = " /im "

        $groupName = $([char]34) + $item.displayName + $([char]34)            


           
            $cmd +=  $groupName +  " /server:https://" + $userParams.VSTSMasterAcct + ".visualstudio.com"
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


function Get-Teams()
{
    param (
        [Parameter(Mandatory = $true)]
        $userParams

    )
     # Base64-encodes the Personal Access Token (PAT) appropriately
     $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # first get project id
    $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects/" + $userParams.ProjectName +"?api-version=5.0"
    $prj = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization 
 
    # find all teams in a given project
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/core/teams/get%20teams?view=azure-devops-rest-5.0
    # GET https://dev.azure.com/{organization}/_apis/projects/{projectId}/teams?api-version=5.0
    #
    $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects/"  + $prj.id +   "/teams?api-version=5.0"
    $allTeams = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json" 

   # foreach ($item in $allTeams.value) {
   #     # GET https://dev.azure.com/{organization}/_apis/projects/{projectId}/teams/{teamId}/members?api-version=6.1-preview.2
   #      $teamUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects/"  + $prj.id +   "/teams/" + $item.id + "/members?api-version=6.1-preview.2"
   #      $allTeamMembers = Invoke-RestMethod -Uri $teamUri -Method Get -Headers $authorization  -ContentType "application/json" 
   #
   # }

    return $allTeams
    
}


function Get-TeamsAndPermsions()
{
    param (
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $NamespaceFilter,
        [Parameter(Mandatory = $false)]
        $outFile, [Parameter(Mandatory = $false)]
        $Allprojects
    )
    #**************************************************************
    # This function will retrieve the permissions for all teams and all namspaces
    #     you can pass in the namespace ( $NamespaceFilter ) to limit namespaces
    #     you can pass in the $AllProjects ( "True" or "False") to limit to teams in 
    #      a project or all teams in org
    #

     # Base64-encodes the Personal Access Token (PAT) appropriately
     $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

     #GET https://dev.azure.com/fabrikam/Fabrikam-Fiber-Git/_apis/wit/recyclebin?api-version=5.0
    # get list of all security namespaces for organization
    
    # list of backlog items
    # $projectUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/fdx-surround" +  "/_apis/wit/recyclebin?api-version=5.0"
    
    $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/securitynamespaces?api-version=5.0"
    $allNamespaces = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 
    
    # find namespace for given category or all categories
    if($NamespaceFilter -ne "All"){
        $fndNamespace = $allNamespaces.value | Where-Object {$_.Name -eq $NamespaceFilter }
    }else {
        $fndNamespace = $allNamespaces.value 
    }

    # find all teams in a given project
    if($Allprojects -eq "True")
    {
        #GET https://dev.azure.com/{organization}/_apis/teams?api-version=6.0-preview.3
        $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/teams?api-version=6.0-preview.3"
        $allTeams = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json" 
    }
    else {
        # get project id
        $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects/" + $userParams.ProjectName +"?api-version=5.0"
        $prj = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization 

        $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects/"  + $prj.id +   "/teams?api-version=5.0"
        $allTeams = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"             
    }
    
    Write-Output "namespace|team name|description|permission type|permission|bit" $item.bit | Out-File $outFile -Append

    foreach ($item in $allTeams.value) {
        # GET https://vssps.dev.azure.com/{organization}/_apis/identities?descriptors={descriptors}&identityIds={identityIds}&subjectDescriptors={subjectDescriptors}&searchFilter={searchFilter}&filterValue={filterValue}&queryMembership={queryMembership}&api-version=6.0
         $teamUri = $userParams.HTTP_preFix + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?identityIds="  + $item.id +   "&api-version=6.0"
         $teamIdentity = Invoke-RestMethod -Uri $teamUri -Method Get -Headers $authorization  -ContentType "application/json" 
         
         $desc = $item.description
         $desc -replace ",", " - "
         
         $hasPermissions = $false

        # loop thru namespace selected and find ACL
        foreach( $ns in $fndNamespace)
        {
            $aclListByNamespace = ""
            try {
                #find all access control lists for the given namespace and group
                $grpUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?descriptors=" + $teamIdentity.value[0].descriptor + "&includeExtendedInfo=True&api-version=6.0-preview.1"
                $aclListByNamespace = Invoke-RestMethod -Uri $grpUri -Method Get -Headers $authorization 
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Write-Host "Security Error : " + $ErrorMessage + " iTEM : " + $FailedItem
                Continue 
            }
                      
            # loop thru acesDictionary in namespace 
            for ($i = 0; $i -lt $aclListByNamespace.value.length; $i++) {

                # list access control entry for each dictionary
                $aclListByNamespace.value[$i].acesDictionary.PSObject.Properties | ForEach-Object {
                    #if( ($_.Value.allow -ge 0) -or ($_.value.deny -ge 0) ) 
                    #{                           
                                                                      
                        # undocumented api to get groupname  from descriptor
                        # https://stackoverflow.com/questions/55735054/translate-acl-descriptors-to-security-group-names
                        $aseList = $userParams.HTTP_preFix + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?descriptors=" + $_.Value.descriptor
                        $aselistRetrun = Invoke-RestMethod -Uri $aseList -Method Get -Headers $authorization 
                        
                        # decode bit. convert to base 2 and find the accompaning permission
                        # ACL has an allow and deny bit flag. this bit flag when converted to base 2
                        # shows the allowed or denyed permissions
                        # for example
                        #    Allow      :1025
                        #    Deny       :4104
                        #    Allow Permission decoded :10000000001
                        #        Allow Permission :ViewBuilds :: 1
                        #        Allow Permission :ViewBuildDefinition :: 1024
                        #        1 + 1024 = 1025
                        #    Deny Permission decoded :1000000001000
                        #            Deny Permission :DeleteBuilds :: 8
                        #            Deny Permission :DeleteBuildDefinition :: 4096
                        #        8 + 4096 = 4104
                        #    
                        # print allowable actions for namespce only once
                                               

                        # print allow permissions
                        if($_.Value.allow -ge 1) 
                        {
                            $permAllow = [convert]::ToString($_.Value.allow,2)
                            
                            # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                            for ($a =  $permAllow.Length-1; $a -ge 0; $a--) 
                            {
                                # need to traverse the string in reverse to match the action list
                                $Allowplace = ( ($a - $permAllow.Length) * -1 )-1
                                Write-Host $Allowplace

                                if( $permAllow.Substring($a,1) -ge 1)
                                {
                                    Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                    Write-Output $aselistRetrun[0].DisplayName '|'   | Out-File $outFile -Append -NoNewline
                                    Write-Output $desc '|'  | Out-File $outFile  -Append -NoNewline
                                    Write-Output 'Allow|' $ns.actions[$Allowplace].name "|" $ns.actions[$Allowplace].bit | Out-File $outFile  -Append -NoNewline
                                    Write-Output "" | Out-File -FilePath $outFile -Append
                                    Write-Host $ns.actions[$Allowplace].name

                                    $hasPermissions = $true
                                }
                            }
                        }

                        # check effective properties
                        if (![string]::IsNullOrEmpty($_.Value.extendedInfo.effectiveAllow )) {
                                                    
                            if($_.Value.extendedInfo.effectiveAllow -ge 1 )
                            {
                                $effAllow = [convert]::ToString($_.Value.extendedInfo.effectiveAllow ,2)
                                
                                # make sure allow and effective allow are not the same
                                if($permAllow -ne $effAllow)
                                {
                                    # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                    for ($a1 =  $effAllow.Length-1; $a1 -ge 0; $a1--) 
                                    {
                                        $EffAllowplace = ( ($a1 - $effAllow.Length) * -1 )-1
                                        if( $effAllow.Substring($a1,1) -ge 1)
                                        {
                                            # need to traverse the string in reverse to match the action list
                                            Write-Host $effAllow
                                            Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                            Write-Output $aselistRetrun[0].DisplayName '|'   | Out-File $outFile -Append -NoNewline   
                                            Write-Output $desc '|'  | Out-File $outFile  -Append -NoNewline
                                            Write-Output 'Inherited Allow|' $ns.actions[$EffAllowplace].name "|" $ns.actions[$EffAllowplace].bit | Out-File $outFile  -Append -NoNewline
                                            Write-Output "" | Out-File -FilePath $outFile -Append
                                            Write-Host $ns.actions[$EffAllowplace].name

                                            $hasPermissions = $true
                                        }
                                    }
                                }
                            }

                        }

                        
                        # decode bit. convert to base 2 and find the accompaning permission
                        if($_.Value.deny -ge 1) 
                        {
                            $permDeny = [convert]::ToString($_.Value.deny,2)

                            # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                            for ($d =  $permDeny.Length-1; $d -ge 0; $d--) 
                            {
                                # need to traverse the string in reverse to match the action list
                                $Denyplace = ( ($d - $permDeny.Length) * -1 )-1

                                if( $permDeny.Substring($d,1) -ge 1)
                                {
                                    Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                    Write-Output $aselistRetrun[0].DisplayName '|'   | Out-File $outFile -Append -NoNewline 
                                    Write-Output $desc '|'  | Out-File $outFile  -Append -NoNewline
                                    Write-Output 'Deny|' $ns.actions[$Denyplace].name "|" $ns.actions[$Denyplace].bit | Out-File $outFile  -Append -NoNewline
                                    Write-Output "" | Out-File -FilePath $outFile -Append
                                    Write-Host $ns.actions[$Denyplace].name

                                    $hasPermissions = $true
                                }
                            }
                        }

                        if (![string]::IsNullOrEmpty($_.Value.extendedInfo.effectiveDeny))
                        { 
                            # check effective properties
                            if($_.Value.extendedInfo.effectiveDeny -ge 1)
                            {
                                $effDeny = [convert]::ToString($_.Value.extendedInfo.effectiveDeny ,2)

                                # make sure deny and effective deny are not the same
                                if($permDeny -ne $effDeny)
                                {
                                    
                                    # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                    for ($d1 =  $effDeny.Length-1; $d1 -ge 0; $d1--) 
                                    {
                                        # need to traverse the string in reverse to match the action list
                                        $EffDenyplace = ( ($d1 - $effDeny.Length) * -1 )-1
                                        Write-Host $EffDenyplace

                                        if( $effDeny.Substring($d1,1) -ge 1)
                                        {
                                            Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                            Write-Output $aselistRetrun[0].DisplayName '|'   | Out-File $outFile -Append -NoNewline 
                                            Write-Output $desc '|'  | Out-File $outFile  -Append -NoNewline
                                            Write-Output 'Inherited Deny|' $ns.actions[$EffDenyplace].name "|" $ns.actions[$EffDenyplace].bit | Out-File $outFile  -Append -NoNewline
                                            Write-Host $ns.actions[$EffDenyplace].name

                                            $hasPermissions = $true
                                        }
                                    }
                                }
                              }
                        }                                                                            
                    
                }

            }

            # if no permission ser still add team
            if($hasPermissions -eq $false)
            {
                #Write-Output ' '  | Out-File $outFile  -Append 
                Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                Write-Output $aselistRetrun[0].DisplayName '|'   | Out-File $outFile -Append -NoNewline
                Write-Output $desc '|'  | Out-File $outFile  -Append -NoNewline
                Write-Output 'No Permission set|No Permission Set|0'  | Out-File $outFile  -Append -NoNewline
                Write-Output ' '  | Out-File $outFile  -Append 
            
            }
            
        }


        

    }

    return $allTeams
    
}


function Get-TeamsAndMemberstoCSV()
{
    param (
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $outFile

    )
     # Base64-encodes the Personal Access Token (PAT) appropriately
     $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # first get project id
    $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects/" + $userParams.ProjectName +"?api-version=5.0"
    $prj = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization 
 
    # find all teams in a given project    
    $projectUri = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects/"  + $prj.id +   "/teams?api-version=5.0"
    $allTeams = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json" 

    Write-Output "Team/Group,Name,Member,Email Address"  | Out-File -FilePath $outFile -Append 
    foreach ($item in $allTeams.value) {
        # get all members of given team
        # GET https://dev.azure.com/{organization}/_apis/projects/{projectId}/teams/{teamId}/members?api-version=6.1-preview.2
         $teamUri = $userParams.HTTP_preFix +  "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/projects/"  + $prj.id +   "/teams/" + $item.id + "/members?api-version=6.1-preview.2"
         $allTeamMembers = Invoke-RestMethod -Uri $teamUri -Method Get -Headers $authorization  -ContentType "application/json" 

         foreach ($member in $allTeamMembers.value) {
            Write-Output "Team" | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output $item.name | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output ',' $member.Identity.displayName  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output ',' $member.Identity.uniqueName  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output "" | Out-File -FilePath $outFile -Append 
         }

    }      
}

function Get-AllGroups()
{
    param (
        [Parameter(Mandatory = $true)]
        $userParams
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

     # find list of all Groups  # https://vssps.dev.azure.com/{organization}/_apis/graph/groups?api-version=5.1-preview.1
     $projectUri = $userParams.HTTP_preFix + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/groups?api-version=5.1-preview.1"
     $allGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
    
     # loop thru all groups and get all users in each group
     foreach ($item in $allGroups.value)
     {
         Write-Host $item.displayName
         Write-Host $item.principalName
         Write-Host $item.descriptor
          
         $usersUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/users?groupDescriptors=" + $item.descriptor + "&api-version=4.0-preview"
         $grp =  Invoke-RestMethod -Uri $usersUri -Method Get -Headers $authorization -ContentType "application/json" 
 
         Write-Host ConvertTo-Json -InputObject $grp.value -Depth 42
     }
}

function Get-GroupListbyGroup() 
{
    param (
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $outFile,
        [Parameter(Mandatory = $true)]
        $groupName
        
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
     
    # find list of all Groups  # https://vssps.dev.azure.com/{organization}/_apis/graph/groups?api-version=5.1-preview.1
    $projectUri = $userParams.HTTP_preFix + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/groups?api-version=5.1-preview.1"
    $allGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
   
    # find namespace for given category or all categories
    if($groupName -ne "All"){
        $fnd = $allGroups.value | Where-Object {$_.principalName -eq $groupName}
    }else {
        $fnd = $allGroups.value 
    }
    
    foreach ($item in $fnd)
    {
        
        Write-Host $item.displayName 
        Write-Host $item.principalName
        Write-Host $item.descriptor
        Write-Host $item.description
        
        Write-Output "       ********* Users for selected group *********" | Out-File -FilePath $outFile -Append
        Write-Output '       Group Name     : ' $item.displayName | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "" | Out-File -FilePath $outFile -Append

        Write-Output '       Principal Name : ' $item.principalName | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "" | Out-File -FilePath $outFile -Append

        Write-Output '       Descriptor     : ' $item.descriptor | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "" | Out-File -FilePath $outFile -Append

        Write-Output '       Description    : ' $item.description | Out-File -FilePath $outFile -Append -NoNewline
        Write-Output "" | Out-File -FilePath $outFile -Append

        $usersUri = $userParams.HTTP_preFix + "://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/users?groupDescriptors=" + $item.descriptor + "&api-version=4.0-preview"
        $grp =  Invoke-RestMethod -Uri $usersUri -Method Get -Headers $authorization -ContentType "application/json" 

        foreach($useritem in $grp.value)
        {
       
            Write-Host  $useritem.displayName  
            Write-Host  $userItem.mailAddress 

            Write-Output '            User : ' $useritem.displayName  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output '  Alias : ' $useritem.directoryAlias  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output '  Email : ' $userItem.mailAddress  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output "" | Out-File -FilePath $outFile -Append      

        }
        Write-Output "" | Out-File -FilePath $outFile -Append      
    }
}

function Get-GroupList() 
{
    param (
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $false)]
        $outFile
      
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
     
    # find list of all Groups  # https://vssps.dev.azure.com/{organization}/_apis/graph/groups?api-version=5.1-preview.1
    $projectUri = $userParams.HTTP_preFix + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/groups?api-version=5.1-preview.1"
    $allGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization  -ContentType "application/json"  
   
      # find groups for the current project
    if($groupName -ne "All"){
        $fnd = $allGroups.value | Where-Object {$_.principalName -match  $userParams.ProjectName }
    }else {
        $fnd = $allGroups.value 
    }
    
    #Write-Output "" | Out-File -FilePath $outFile -Append
    Write-Output 'Group Name,UserName,type,origin,Fedex ID,Email Address' $item.displayName | Out-File -FilePath $outFile -Append -NoNewline
    Write-Output "" | Out-File -FilePath $outFile -Append

    foreach ($item in $fnd)
    {
        
         # get decoded descriptor
         $dscrpt =  Get-DescriptorFromGroup -dscriptor $item.descriptor
         $dscrpt = "Microsoft.TeamFoundation.Identity;" + $dscrpt
         
        Write-Host $item.displayName 
        Write-Host $item.principalName
        Write-Host $item.descriptor
        Write-Host $item.description
        
        $usersUri = $userParams.HTTP_preFix + "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/users?api-version=4.0-preview"
        #$usersUri = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/users?api-version=6.0-preview.1"
        $grp2 =  Invoke-RestMethod -Uri $usersUri -Method Get -Headers $authorization -ContentType "application/json" 
        
        $fnd1 = $grp2.value | Where-Object {$_.metaType -eq "member" }

              

        foreach($useritem in $fnd1)
        {
            # GET https://vssps.dev.azure.com/fabrikam/_apis/graph/Memberships/{subjectDescriptor}?direction=Down&api-version=6.1-preview.1
            $memberUri = $userParams.HTTP_preFix +  "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "_apis/graph/Memberships/" + $useritem.descriptor + "?api-version=5.1-preview.1"
            $mbr1 =  Invoke-RestMethod -Uri $memberUri -Method Get -Headers $authorization -ContentType "application/json" 


            write-host $item.principalName
            Write-Host $useritem.displayName  
            Write-Host $userItem.mailAddress 
          
            Write-Output $item.principalName | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output ',' $useritem.displayName  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output ',' $useritem.subjectKind  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output ',' $useritem.origin  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output ',' $useritem.directoryAlias  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output ',' $userItem.mailAddress  | Out-File -FilePath $outFile -Append -NoNewline
            Write-Output "" | Out-File -FilePath $outFile -Append      

        }
        Write-Output "" | Out-File -FilePath $outFile -Append      
    }
}

function Get-GroupMembership(){

    param (
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $fndGroup
      
    )
    
    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
                
    #GET https://vssps.dev.azure.com/{organization}/_apis/graph/Memberships/{subjectDescriptor}?api-version=6.0-preview.1
    $memberUri = $userParams.HTTP_preFix +  "://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/Memberships/" + $fndGroup.descriptor +"?direction=Up&api-version=6.1-preview.1"
    $Memberof = Invoke-RestMethod -Uri $memberUri -Method Get -Headers $authorization    

   
    return $MemberOf

}