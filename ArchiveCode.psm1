

function Get-SecurityForGivenNamespaces_old()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $NamespaceFilter,
        [Parameter(Mandatory = $true)]
        $outFile
    )

        # Base64-encodes the Personal Access Token (PAT) appropriately
        $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

        # get list of all security namespaces for organization
        $projectUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/securitynamespaces?api-version=5.0"
        $allNamespaces = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 
       
        # find namespace for given category or all categories
        if($NamespaceFilter -ne "All"){
            $fndNamespace = $allNamespaces.value | Where-Object {$_.Name -match $NamespaceFilter }
        }else {
            $fndNamespace = $allNamespaces.value 
        }

        # find all groups in organization and then filter by project
        $projectUri = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/groups?api-version=5.0-preview.1"
        $allGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 

        # find all groups for given project
        $fnd = $allGroups.value | Where-Object {$_.principalName -match $userParams.ProjectName }

         # loop thru each group and get descriptor find security namespace filtered by descriptor
         # get access control list for filtered namespaces
         for ($j = 0; $j -lt $fnd.Length; $j++) 
         {

            # get decoded descriptor
            $dscrpt =  Get-DescriptorFromGroup -dscriptor $fnd[$j].descriptor
            $dscrpt = "Microsoft.TeamFoundation.Identity;" + $dscrpt
            
           # Write-Output "" | Out-File -FilePath $outFile -Append
           # Write-Output "" | Out-File -FilePath $outFile -Append
           # Write-Output '## Group      : ' $fnd[$j].displayName | Out-File -FilePath $outFile -Append -NoNewline
           # Write-Output "  " | Out-File -FilePath $outFile -Append
           # Write-Output '   Dectriptor : '$dscrpt | Out-File -FilePath $outFile -Append -NoNewline
           # Write-Output " " | Out-File -FilePath $outFile -Append

            # loop thru namespace selected and find ACL
            foreach( $ns in $fndNamespace)
            {
               # Write-Output "  " | Out-File $outFile -Append 
               # Write-Output '     == Security Namespace:' $ns.name  | Out-File $outFile  -Append -NoNewline

                $aclListByNamespace = ""
                try {
                    #find all access control lists for the given namespace and group
                    $grpUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?descriptors=" + $dscrpt + "&includeExtendedInfo=True&api-version=6.0-preview.1"
                    $aclListByNamespace = Invoke-RestMethod -Uri $grpUri -Method Get -Headers $authorization 
                }
                catch {
                    $ErrorMessage = $_.Exception.Message
                    $FailedItem = $_.Exception.ItemName
                    Write-Host "Security Error : " + $ErrorMessage + " iTEM : " + $FailedItem
                    Continue 
                }
                
                # to control printing of actions only once per namespace
                $namespacePrint = 0
                 
                # loop thru acesDictionary in namespace 
                for ($i = 0; $i -lt $aclListByNamespace.value.length; $i++) {

                    # list access control entry for each dictionary
                    $aclListByNamespace.value[$i].acesDictionary.PSObject.Properties | ForEach-Object {
                        if( ($_.Value.allow -ne 0) -or ($_.value.deny -ne 0) ) 
                        {
                            # print allowable actions for namespce only once
                            if($namespacePrint -eq 0)
                            {
                                # write out all available permissons
                                Write-Output "     ----------------------     " | Out-File $outFile -Append 
                                Write-Output '     Allowed Permissions for Security Namespace:' $ns.name  | Out-File $outFile  -Append -NoNewline
                                Write-Output "  " | Out-File $outFile -Append

                                foreach ($item in $ns.actions) {
                                    Write-Output "     Bit: " $item.bit | Out-File $outFile -Append -NoNewline
                                    Write-Output " Name: " $item.name | Out-File $outFile -Append -NoNewline
                                    Write-Output "  " | Out-File $outFile -Append 
                                }    
                                $namespacePrint = 1
                            }

                            # print out access control entry
                            Write-Output "  " | Out-File -FilePath $outFile -Append
                            Write-Output '     inheritPermissions: ' $aclListByNamespace.value[$i].inheritPermissions | Out-File -FilePath $outFile -Append -NoNewline
                            Write-Output "" | Out-File -FilePath $outFile -Append
                            Write-Output '     Token      :' $aclListByNamespace.value[$i].token | Out-File -FilePath $outFile -Append -NoNewline
                            Write-Output "" | Out-File -FilePath $outFile -Append
                            Write-Output '     Descriptor :' $_.Value.descriptor | Out-File $outFile -Append -NoNewline
                            Write-Output "" | Out-File -FilePath $outFile -Append

                            # undocumented api to get groupname  from descriptor
                            # https://stackoverflow.com/questions/55735054/translate-acl-descriptors-to-security-group-names
                            $aseList = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?descriptors=" + $_.Value.descriptor
                            $aselistRetrun = Invoke-RestMethod -Uri $aseList -Method Get -Headers $authorization 

                            Write-Output '     Group Name :' $aselistRetrun[0].DisplayName  | Out-File $outFile -Append -NoNewline
                            Write-Output "" | Out-File -FilePath $outFile -Append

                            Write-Output '     Allow      :' $_.Value.allow | Out-File $outFile -Append -NoNewline
                            Write-Output "" | Out-File -FilePath $outFile -Append
                            Write-Output '     Deny       :' $_.Value.deny | Out-File $outFile  -Append -NoNewline
                            Write-Output "" | Out-File -FilePath $outFile -Append
                            Write-Output "" | Out-File -FilePath $outFile -Append
                          
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
                            
                            # print allow permissions
                            if($_.Value.allow -gt 0)
                            {
                                $permAllow = [convert]::ToString($_.Value.allow,2)
                                Write-Output '       Allow Permission decoded :' $permAllow | Out-File $outFile  -Append -NoNewline
                                Write-Output "" | Out-File -FilePath $outFile -Append
                                
                                # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                for ($a =  $permAllow.Length-1; $a -ge 0; $a--) 
                                {
                                    # need to traverse the string in reverse to match the action list
                                    $Allowplace = ( ($a - $permAllow.Length) * -1 )-1
                                    Write-Host $Allowplace

                                    if( $permAllow.Substring($a,1) -eq 1)
                                    {
                                        Write-Output '            Allow Permission :' $ns.actions[$Allowplace].name " :: " $ns.actions[$Allowplace].bit | Out-File $outFile  -Append -NoNewline
                                        Write-Output "" | Out-File -FilePath $outFile -Append
                                        Write-Host $ns.actions[$Allowplace].name
                                        
                                    }
                                }

                                # check effective properties
                                if($_.Value.extendedInfo.effectiveAllow -gt 0 )
                                {
                                    $effAllow = [convert]::ToString($_.Value.extendedInfo.effectiveAllow ,2)
                                    
                                    # make sure allow and effective allow are not the same
                                    if($permAllow -ne $effAllow)
                                    {
                                        Write-Output "" | Out-File -FilePath $outFile -Append
                                        Write-Output '       Inherited Allow : ' $_.Value.extendedInfo.effectiveAllow | Out-File $outFile  -Append -NoNewline
                                        Write-Output "" | Out-File -FilePath $outFile -Append
                                        Write-Output '       Inherited Allow Permission decoded :' $effAllow | Out-File $outFile  -Append -NoNewline

                                        # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                        for ($a1 =  $effAllow.Length-1; $a1 -ge 0; $a1--) 
                                        {
                                            
                                            $EffAllowplace = ( ($a1 - $effAllow.Length) * -1 )-1
                                            if( $effAllow.Substring($a1,1) -eq 1)
                                            {
                                                # need to traverse the string in reverse to match the action list
                                                Write-Host $EffAllowplace
                                                Write-Output "" | Out-File -FilePath $outFile -Append
                                                Write-Output '            Inherited Allow Permission :' $ns.actions[$EffAllowplace].name " :: " $ns.actions[$EffAllowplace].bit | Out-File $outFile  -Append -NoNewline
                                                Write-Host $ns.actions[$EffAllowplace].name
                                            }
                                        }
                                    }else {
                                        Write-Output "" | Out-File -FilePath $outFile -Append
                                        Write-Output '            Selected (' $permAllow  ') and Inherited ('$effAllow ') Permissions are the same ' | Out-File $outFile  -Append -NoNewline
                                        Write-Output "" | Out-File -FilePath $outFile -Append
                                        
                                    }

                                }
                            }

                            Write-Output "" | Out-File -FilePath $outFile -Append
                            Write-Output "" | Out-File -FilePath $outFile -Append
                            # decode bit. convert to base 2 and find the accompaning permission
                            if($_.Value.deny -gt 0)
                            {
                                $permDeny = [convert]::ToString($_.Value.deny,2)
                                Write-Output '       Deny Permission decoded :' $permDeny | Out-File $outFile  -Append -NoNewline
                                Write-Output "" | Out-File -FilePath $outFile -Append

                                # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                for ($d =  $permDeny.Length-1; $d -ge 0; $d--) 
                                {
                                    # need to traverse the string in reverse to match the action list
                                    $Denyplace = ( ($d - $permDeny.Length) * -1 )-1

                                    if( $permDeny.Substring($d,1) -eq 1)
                                    {
                                        Write-Output '            Deny Permission :' $ns.actions[$Denyplace].name " :: " $ns.actions[$Denyplace].bit | Out-File $outFile  -Append -NoNewline
                                        Write-Output "" | Out-File -FilePath $outFile -Append
                                        Write-Host $ns.actions[$Denyplace].name

                                    }
                                }

                                 # check effective properties
                                 if($_.Value.extendedInfo.effectiveDeny -gt 0)
                                 {
                                     $effDeny = [convert]::ToString($_.Value.extendedInfo.effectiveDeny ,2)

                                    # make sure deny and effective deny are not the same
                                    if($permDeny -ne $effDeny)
                                    {
                                        Write-Output "" | Out-File -FilePath $outFile -Append
                                        Write-Output '       Inherited Deny : ' $_.Value.extendedInfo.effectiveDeny | Out-File $outFile  -Append -NoNewline
                                        Write-Output "" | Out-File -FilePath $outFile -Append
                                        Write-Output '       Inherited Deny Permission decoded :' $effDeny | Out-File $outFile  -Append -NoNewline
                                        Write-Output "" | Out-File -FilePath $outFile -Append
    
                                        # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                        for ($d1 =  $effDeny.Length-1; $d1 -ge 0; $d1--) 
                                        {
                                            # need to traverse the string in reverse to match the action list
                                            $EffDenyplace = ( ($d1 - $effDeny.Length) * -1 )-1
                                            Write-Host $EffDenyplace
    
                                            if( $effDeny.Substring($d1,1) -eq 1)
                                            {
                                                Write-Output "" | Out-File -FilePath $outFile -Append
                                                Write-Output '            Inherited Deny Permission :' $ns.actions[$EffDenyplace].name " :: " $ns.actions[$EffDenyplace].bit | Out-File $outFile  -Append -NoNewline
                                                Write-Host $ns.actions[$EffDenyplace].name
                                            }
                                        }
                                    }else {
                                        Write-Output "" | Out-File -FilePath $outFile -Append
                                        Write-Output '            Inherited Deny  (' $effDeny  ') and selected Deny  ('$permDeny ') Permissions are the same ' | Out-File $outFile  -Append -NoNewline
                                        Write-Output "" | Out-File -FilePath $outFile -Append

                                    }
                                 }

                            }
                            
                            #
                            # if either allow or deny permissions exist, show the group members
                            if($_.Value.deny -gt 0 -or $_.Value.allow -gt 0)
                            {
                                Write-Host '     Group Name :' $aselistRetrun[0].DisplayName  
                                Get-GroupListbyGroup -userParams $userParams -outFile $outFile -groupName $aselistRetrun[0].DisplayName 
                            }
                        }
                    }

                }
                
            }

         }
       
}




function Get-SecurityByNamespaces()
{
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $outFile,
        [Parameter(Mandatory = $true)]
        $AllProjects

        )

        # Base64-encodes the Personal Access Token (PAT) appropriately
        $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

        # get list of all security namespaces for organization
        $projectUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/securitynamespaces?api-version=5.0"
        $allNamespaces = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 
       
        #find all Teams in Org. needed to determine if group is a team or group
        # GET https://dev.azure.com/{organization}/_apis/teams?api-version=6.0-preview.3        
        # 
        $tmUrl = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/teams?api-version=6.0-preview.3"
        $allteams = Invoke-RestMethod -Uri $tmUrl -Method Get -Headers $authorization 

        Write-Output 'Namespace|Project|Group Type|Group Name|Description|Permission Type|Permission|bit|Permission Name|Decoded Value|Raw Data'  | Out-File $outFile  -Append -NoNewline
       
        # get all groups in org or just for a given project vssgp,aadgp are the subject types use vssgp to get groups for a given project
        $projectUri = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/groups?subjectTypes=vssgp&api-version=6.0-preview.1"
        $allGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization    
        
        if( $AllProjects -eq "True")
        {
            $groups = $allGroups.value
        }else {
            # find all groups for given project
            $groups = $allGroups.value | Where-Object {$_.principalName -match $userParams.ProjectName }
            #$groups = $allGroups.value | Where-Object {$_.displayName -match "Portal" }
        }

        # loop thru all groups in list
        foreach ($selectGroup in $groups) 
        {
            Write-host $selectGroup.principalname
            $HasPermissions = $false

            # get decoded descriptor for the group 
            $dscrpt =  Get-DescriptorFromGroup -dscriptor $selectGroup.descriptor
            $dscrpt = "Microsoft.TeamFoundation.Identity;" + $dscrpt
  
            # loop thru namespace selected and find ACL
            foreach( $nsItem in $userParams.Namespaces)
            {
                # get namespace
                $nmeSpace =  $nsItem
                Write-Host $nmeSpace 
                $ns = $allNamespaces.value | Where-Object {$_.Name -eq $nmeSpace }

                $aclListByNamespace = ""
                try {
                    #find all access control lists for the given namespace
                    # $grpUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?includeExtendedInfo=True&api-version=6.0-preview.1"
                    #$grpUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?descriptors=" + $dscrpt +"&includeExtendedInfo=True&api-version=6.0-preview.1"
                    $grpUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?descriptors=" + $dscrpt +"&includeExtendedInfo=True&recurse=True&api-version=6.0-preview.1"
                    $aclListByNamespace = Invoke-RestMethod -Uri $grpUri -Method Get -Headers $authorization 
                }
                catch {
                    $ErrorMessage = $_.Exception.Message
                    $FailedItem = $_.Exception.ItemName
                    Write-Host "Security Error : " + $ErrorMessage + " iTEM : " + $FailedItem
                    Continue 
                }
                                
                # loop thru all access control lists for given namespace
                foreach ($acl in $aclListByNamespace.value) {
                    Write-Host | ConvertTo-Json -InputObject $acl -Depth 32
                                       
                    $grpUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?token=" + $acl.token +"&includeExtendedInfo=True&api-version=6.0-preview.1"
                    $aclListByToken = Invoke-RestMethod -Uri $grpUri -Method Get -Headers $authorization 
                    
                    #loop thru each access control entry in the given acl
                    foreach ($item in $aclListByToken.Value[0].acesDictionary.PSObject.Properties) {
                        Write-Host $item
                        
                        # first find the name of the group the permissions is for
                        # undocumented api to get groupname  from descriptor
                        # https://stackoverflow.com/questions/55735054/translate-acl-descriptors-to-security-group-names
                        $aceGroupUrl = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?descriptors=" + $item.value.descriptor
                        $aceGroupRetrun = Invoke-RestMethod -Uri $aceGroupUrl -Method Get -Headers $authorization 
                        Write-Host $selectGroup.DisplayName
                
                        # figure out if this is a team or group or user
                        if( $aceGroupRetrun.properties.SchemaClassName -eq "User")
                        {
                            $t = $aceGroupRetrun.properties
                            $GroupType = "User"
                            $tm = $t.Account
                            $projectName = $t.Account
                        }
                        else 
                        {
                            $prName = $selectGroup.principalName.Split('\')
                            if($prName.Length -eq 1)
                            {
                                $prName1 =  $selectGroup.principalName.Split('(')
                                $tm =  $prName1[0].substring(0,$prName1[0].length-1)
                                $projectName = $prName1[1].substring(0,$prName1[1].length-1)
                            }else {
                                $projectName =  $prName[0].substring(1,$prname[0].length-2)
                                $tm = $prName[1]
                            }

                            $teamFound = $allteams.value | Where-Object {($_.ProjectName -eq $projectName) -and ($_.name -eq $tm)}
                            $GroupType = "G-Delivered"
                            IF (![string]::IsNullOrEmpty($teamFound)) {
                                $GroupType = "T-Custom"                
                            } 
                        
                        }

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
                        # now look at the allow and eny bits
                        if( ($item.Value.allow -ne 0) -or ($item.Value.deny -ne 0) ) 
                        {
                            # check allow permission
                            if($item.value.allow -ne 0)
                            {
                                $HasPermissions = $true
                                $permAllow = [convert]::ToString($item.value.allow,2)
                                # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                for ($a =  $permAllow.Length-1; $a -ge 0; $a--) 
                                {
                                    # need to traverse the string in reverse to match the action list
                                    $Allowplace = ( ($a - $permAllow.Length) * -1 )-1
                                    if( $permAllow.Substring($a,1) -eq 1)
                                    {
                                        if($ns.actions[$Allowplace].bit -ne 16384 )
                                        {
                                            Write-Output "" | Out-File -FilePath $outFile -Append
                                            Write-Output $ns.Name  "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $projectName "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $GroupType "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $tm "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $aceGroupRetrun.properties.Description "|" | Out-File $outFile  -Append -NoNewline

                                            Write-Output 'Allow' "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $ns.actions[$Allowplace].displayName "|" $ns.actions[$Allowplace].bit  "|" $ns.actions[$Allowplace].name "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $permAllow "|" $item.Value.allow  | Out-File -FilePath $outFile -Append -NoNewline
                                            Write-Host $ns.actions[$Allowplace].name
                                        }
                                    }
                                }                            
                            }

                            # check deny permission
                            if($item.value.deny -ne 0)
                            {
                                $HasPermissions = $true
                                $permDeny = [convert]::ToString($item.value.deny,2)
                                # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                for ($a =  $permDeny.Length-1; $a -ge 0; $a--) 
                                {
                                    # need to traverse the string in reverse to match the action list
                                    $Denyplace = ( ($a - $permDeny.Length) * -1 )-1
                                    if( $permDeny.Substring($a,1) -eq 1)
                                    {
                                        Write-Output "" | Out-File -FilePath $outFile -Append

                                        Write-Output $ns.Name  "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $projectName "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $GroupType "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $tm "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $aceGroupRetrun.properties.Description "|" | Out-File $outFile  -Append -NoNewline

                                        Write-Output 'Deny' "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $ns.actions[$Denyplace].displayName "|" $ns.actions[$Denyplace].bit  "|" $ns.actions[$Denyplace].name "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $permDeny "|" $item.Value.deny | Out-File -FilePath $outFile -Append -NoNewline
                                        Write-Host $ns.actions[$Denyplace].name
                                    }
                                }                            
                            }

                        }

                        # check extendedinfo 
                        if (![string]::IsNullOrEmpty($item.value.extendedInfo ))
                        {
                            # check extended info effective allow
                            if (![string]::IsNullOrEmpty($item.value.extendedInfo.effectiveAllow ))
                            { 
                                $HasPermissions = $true
                                $effInheritedAllow = [convert]::ToString($item.value.extendedInfo.effectiveAllow,2)
                                # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                for ($a =  $effInheritedAllow.Length-1; $a -ge 0; $a--) 
                                {
                                    $grpUrl = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?descriptors=" + $item.Value.descriptor 
                                    $grpFromDesc = Invoke-RestMethod -Uri $grpUrl -Method Get -Headers $authorization 
                                    Write-Host " inherited group : " $grpFromDesc.DisplayName
                                    $effallowFrom = $grpFromDesc.DisplayName

                                    # need to traverse the string in reverse to match the action list
                                    $effAllowplace = ( ($a - $effInheritedAllow.Length) * -1 )-1
                                    if( $effInheritedAllow.Substring($a,1) -eq 1)
                                    {
                                        if($ns.actions[$effAllowplace].bit -ne 16384 )
                                        {
                                            Write-Output "" | Out-File -FilePath $outFile -Append
                                            Write-Output $ns.Name  "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $projectName "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $GroupType "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $tm "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $aceGroupRetrun.properties.Description "|" | Out-File $outFile  -Append -NoNewline

                                            Write-Output 'Inherited Allow' "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $ns.actions[$effAllowplace].displayName "|" $ns.actions[$effAllowplace].bit  "|" $ns.actions[$effAllowplace].name "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $effInheritedAllow "|" $item.value.extendedInfo.effectiveAllow | Out-File -FilePath $outFile -Append -NoNewline
                                            Write-Host $ns.actions[$effAllowplace].name
                                        }
                                    }
                                }      
                            }

                            # check extended info effective deny
                            if (![string]::IsNullOrEmpty($item.value.extendedInfo.effectiveDeny ))
                            { 
                                $HasPermissions = $true
                                $effInheritedDeny = [convert]::ToString($item.Value.extendedInfo.effectiveDeny ,2)                            
                                # loop thru the decoded base 2 number and check the bit. if 1(on) then that permission is set
                                for ($a =  $effInheritedDeny.Length-1; $a -ge 0; $a--) 
                                {
                                    # need to traverse the string in reverse to match the action list
                                    $effDenyplace = ( ($a - $effInheritedDeny.Length) * -1 )-1
                                    if( $effInheritedDeny.Substring($a,1) -eq 1)
                                    {
                                        Write-Output "" | Out-File -FilePath $outFile -Append

                                        Write-Output $ns.Name  "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $projectName "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $GroupType "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $tm "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $aceGroupRetrun.properties.Description "|" | Out-File $outFile  -Append -NoNewline

                                        Write-Output 'inherited Deny' "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output $ns.actions[$effDenyplace].displayName "|" $ns.actions[$effDenyplace].bit  "|" $ns.actions[$effDenyplace].name "|" | Out-File $outFile  -Append -NoNewline
                                        Write-Output effInheritedDeny "|" $item.value.extendedInfo.effectiveAllow | Out-File -FilePath $outFile -Append -NoNewline
                                        Write-Host $ns.actions[$effDenyplace].name
                                    }
                                }      
                            }
                            
                        }
                        
                    }
                }
            
                 # if no permission ser still add team
                if($HasPermissions -eq $false)
                {
                    Write-Output "" | Out-File -FilePath $outFile -Append
                    Write-Output $ns.Name  "|" | Out-File $outFile  -Append -NoNewline
                    Write-Output $projectName "|" | Out-File $outFile  -Append -NoNewline
                    Write-Output $GroupType "|" | Out-File $outFile  -Append -NoNewline
                    Write-Output $tm "|" | Out-File $outFile  -Append -NoNewline
                    Write-Output $aceGroupRetrun.properties.Description "|" | Out-File $outFile  -Append -NoNewline

                    Write-Output 'No Permission Set' "|" | Out-File $outFile  -Append -NoNewline
                    Write-Output  "||||" | Out-File $outFile  -Append -NoNewline
                }
            }

        }

}










  # check for inherited permissions from other groups
                    # https://docs.microsoft.com/en-us/rest/api/azure/devops/security/access%20control%20lists/query?view=azure-devops-rest-6.1#examples                             
                    $tokenUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/accesscontrollists/" + $ns.namespaceId + "?token=" + $aclListByNamespace.value[$i].token + "&includeExtendedInfo=Fales&recurse=False&api-version=6.1-preview.1"
                    $aclListByToken = Invoke-RestMethod -Uri $tokenUri -Method Get -Headers $authorization 

                    if($aclListByNamespace.value[$i].token -notmatch "PROJECT")
                    {
                        if($rawDataDump -eq "True")
                        {
                            $outname = "C:\Temp\RawData\" + $aclListByNamespace.value[$i].token.Substring(2) + "_" + $tm + "_" + $userParams.Namespaces[$n] + "_RawData.txt"
                            Write-Output $fnd.displayname " - " $ns.name | Out-File $outname -Append -NoNewline
                            Write-Output " " | Out-File $outname -Append

                            for ($i = 0; $i -lt $aclListByNamespace.Count; $i++) {
                                $t =  ConvertTo-Json -InputObject $aclListByToken.value[$i] -Depth 42                         
                                Write-Output $t | Out-File $outname -Append
                            }
                        }

                        # look for duplicate tokens
                        if($lastTOken -ne $aclListByNamespace.value[$i].token)
                        {
                            foreach ($token in  $aclListByToken.value[0].acesDictionary.PSObject.Properties) {
                                $grpUrl = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?descriptors=" + $token.Value.descriptor 
                                $grpFromDesc = Invoke-RestMethod -Uri $grpUrl -Method Get -Headers $authorization 
                                Write-Host " inherited group : " $grpFromDesc.DisplayName
                                $effallowFrom = $grpFromDesc.DisplayName

                                # check allow permissions
                                if( $token.Value.allow -gt 0 )
                                {                           
                                    $permAllow = [convert]::ToString($token.Value.allow ,2)
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

                                            Write-Output $ns.name '|'  | Out-File $outFile  -Append -NoNewline
                                            Write-Output $projectName '|'  | Out-File $outFile  -Append -NoNewline                                    
                                            Write-Output $GroupType '|'  | Out-File $outFile  -Append -NoNewline
                                            Write-Output $fnd.displayName  '|'   | Out-File $outFile -Append -NoNewline
                                            Write-Output $fnd.description '|'  | Out-File $outFile  -Append -NoNewline
                                            Write-Output 'Allow(inherited)|'  $bit.displayName "|"  $bit.bit "|"  $bit.Name  "|" | Out-File $outFile  -Append -NoNewline
                                            Write-Output $token.Value.allow   "|" $effallowFrom | Out-File -FilePath $outFile -Append -NoNewline
                                            Write-Output " " | Out-File -FilePath $outFile -Append  
                                            
                                            $hasPermission = $true                                    
                                        }
                                        
                                    }
        
                                }
                            }
                            $lastTOken = $aclListByNamespace.value[$i].token
                        }
                    }