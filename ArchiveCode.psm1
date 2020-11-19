

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


function Get-ApprovalsByEnvironment_old()
{
    # not archive code, just want to save what i found from hitting f12 
    # un documented calls
    Param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $outFile
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

    # get list of environments
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/environments/list?view=azure-devops-rest-6.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments?api-version=6.1-preview.1
    $envUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/distributedtask/environments?api-version=6.1-preview.1"
    $allEnvs = Invoke-RestMethod -Uri $envUri -Method Get -Headers $authorization -Verbose
    Write-Host $allEnvs.count

    $envMain = $allEnvs.value | Where-Object {$_.name -eq "PROD-App"}

    foreach ($Env in $envMain)
    {
        # get individual environment with resources if available
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/environments/get?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments/{environmentId}?expands={expands}&api-version=6.1-preview.1
        $envUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/distributedtask/environments/" + $Env.id + "?expands=resourceReferences&api-version=6.1-preview.1"
        $EnvwResources = Invoke-RestMethod -Uri $envUri -Method Get -Headers $authorization -Verbose
        for ($r = 0; $r -lt $EnvwResources.resources.length; $r++) 
        {
            # get the resources for this environment
            switch ($EnvwResources.resources[$r].type )
            {
                "kubernetes" { 
                    # https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/kubernetes/get?view=azure-devops-rest-6.1
                    # GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments/{environmentId}/providers/kubernetes/{resourceId}?api-version=6.1-preview.1
                    $kubUrl = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/distributedtask/environments/" + $Env.id + "/providers/kubernetes/" + $EnvwResources.resources[$r].id + "?api-version=6.1-preview.1"
                    $KubResource = Invoke-RestMethod -Uri $kubUrl -Method Get -Headers $authorization -Verbose

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
        

        $tmData =  @{
            contributionIds = @(@{"ms.vss-build-web.checks-panel-data-provider"});
            dataProviderContext = @{
                properties = {
                    buildId = "22168";
                    stageIds = "ab2863f6-83b8-5f68-9b02-83c7be202aa7";
                    checkListItemType= 1;                    
                    }
                }
            }
        
        $acl = ConvertTo-Json -InputObject $tmData
        $acl = $acl -replace """{}""", '{}'

        #application/json;api-version=5.0-preview.1;excludeUrls=true;enumsAsNumbers=true;msDateFormat=true;noArrayWrap=true
        # GET https://auditservice.dev.azure.com/{organization}/_apis/audit/auditlog?api-version=6.1-preview.1
        $envDepUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/Contribution/HierarchyQuery/project/" + $userParams.ProjectName + "?api-version=5.0-preview.1"
        $EnvDeps = Invoke-RestMethod -Uri $envDepUri -Method Post -Headers $authorization -ContentType "application/json" -Body $acl
        

        # get environment deployment record- this is a list of deployments
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/environmentdeployment%20records/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/environments/{environmentId}/environmentdeploymentrecords?api-version=6.1-preview.1
        $envDepUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/distributedtask/environments/" + $Env.id + "/environmentdeploymentrecords?api-version=6.1-preview.1"
        $EnvDeps = Invoke-RestMethod -Uri $envDepUri -Method Get -Headers $authorization -Verbose
        foreach ($Deploy in $EnvDeps.value) 
        {
            # get build in the deployments
            # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}?api-version=6.1-preview.6
            $DepBuildUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $deploy.owner.id + "?api-version=6.1-preview.6"
            $DepBuild = Invoke-RestMethod -Uri $DepBuildUri -Method Get -Headers $authorization -Verbose
    
                Write-Host $Deploy
                ConvertTo-Html -InputObject 

            $DepBuildUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_build/results?buildId=" + $deploy.owner.id + "&view=results"
            #$DepBuildUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/pipelines/approvals"
            $DepBuild = Invoke-RestMethod -Uri $DepBuildUri -Method Get -Headers $authorization  -Verbose 
            
            Write-Host $DepBuild.ParsedHtml
            
            $e = $DepBuild | Get-Member 

            $s = $DepBuild
            
            $first = $s.IndexOf('jobs') -1
            
            $t = $s.substring($first)
            $last = $t.IndexOf('ms.vss-web.navigation-data')

            
            $n =  $t.substring(0,$last-2)
            $data = ConvertTo-Json -InputObject $n 

            #$t = $DepBuild.data.'ms.vss-build-web.run-details-data-provider'
            Write-Host $data

            # get build timeline 
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/timeline/get?view=azure-devops-rest-6.1
            # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/timeline/{timelineId}?api-version=6.1-preview.2
            $BuildTimelineUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $deploy.owner.id + "/timeline?api-version=6.1-preview.2"
            $BuildTimeLine = Invoke-RestMethod -Uri $BuildTimelineUri -Method Get -Headers $authorization -Verbose
            
            $tmStages = $BuildTimeLine.records | Where-Object { $_.type -eq "Stage" } | Sort-Object -Property order
            $tmJobs = $BuildTimeLine.records | Where-Object { $_.type -eq "Job" } | Sort-Object -Property order
            $tmTasks = $BuildTimeLine.records | Where-Object { $_.type -eq "Task" } | Sort-Object -Property order
            $tmPhase = $BuildTimeLine.records | Where-Object { $_.type -eq "Phase" } | Sort-Object -Property order

            $tmCheckPoint = $BuildTimeLine.records | Where-Object { $_.type -eq "CheckPoint" } | Sort-Object -Property order        
            $tmCpApproval = $BuildTimeLine.records | Where-Object { $_.type -eq "Checkpoint.Approval" } | Sort-Object -Property order
            $tmCpTaskChk = $BuildTimeLine.records | Where-Object { $_.type -match "Checkpoint.TaskCheck" } | Sort-Object -Property order

            #loop thru stages
            foreach ($tm in $tmStages) 
            {

                # get build timeline 
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/timeline/get?view=azure-devops-rest-6.1
                # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/timeline/{timelineId}?changeId={changeId}&planId={planId}&api-version=6.1-preview.2
                $TimelineUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $deploy.owner.id + "/timeline/" + $tm.id + "?&api-version=6.1-preview.2"
                $ApprovalTimeLine = Invoke-RestMethod -Uri $TimelineUri -Method Get -Headers $authorization 


                # find approver
                # https://dev.azure.com/fdx-strat-pgm/_apis/Contribution/HierarchyQuery/project/633b0ef1-c219-4017-beb0-8eb49ff55c35
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/ims/identities/read%20identities?view=azure-devops-rest-6.1#uri-parameters
                # GET https://vssps.dev.azure.com/{organization}/_apis/identities?descriptors={descriptors}&identityIds={identityIds}&subjectDescriptors={subjectDescriptors}&searchFilter={searchFilter}&filterValue={filterValue}&queryMembership={queryMembership}&api-version=6.1-preview.1
                # GET https://vssps.dev.azure.com/{organization}/_apis/graph/users/{userDescriptor}?api-version=6.1-preview.1
                $idtf = $tm.identifier -replace('-', '')
                $idft = Get-UserDescriptorById  -userParams $userParams -id $tm.identifier 
                $idUrl = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/graph/users/" + $tm.identifier + "?api-version=6.1-preview.1"
                $idData = Invoke-RestMethod -Uri $idUrl -Method Get -Headers $authorization -Verbose

                Write-Host $tm.type " - " $tm.name " - " $tm.order
            }
            Write-Host $BuildTimeLine

    
        }
        



    }

    # get list of pipelines
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/pipelines/list?view=azure-devops-rest-6.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/pipelines?api-version=6.1-preview.1
    $pipelineUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/pipelines?api-version=6.1-preview.1"
    $allPipelines = Invoke-RestMethod -Uri $pipelineUri -Method Get -Headers $authorization -Verbose
    Write-Host $allPipelines.count

    # get all runs for a pipeline
    foreach ($pipeline in $allPipelines.value)
    {
        # get runs for a pipeline
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/runs/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/pipelines/{pipelineId}/runs?api-version=6.1-preview.1
        $runUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/pipelines/" + $pipeline.id + "/runs?api-version=6.1-preview.1"
        $allruns = Invoke-RestMethod -Uri $runUri -Method Get -Headers $authorization -Verbose
        Write-Host $allruns.count

        foreach ($run in $allruns.value) 
        {
            # get detail of a run 
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/runs/get?view=azure-devops-rest-6.1
            # GET https://dev.azure.com/{organization}/{project}/_apis/pipelines/{pipelineId}/runs/{runId}?api-version=6.1-preview.1
            $runDetailUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/pipelines/" + $pipeline.id + "/runs/" + $run.id + "?api-version=6.1-preview.1"
            $runDetail = Invoke-RestMethod -Uri $runDetailUri -Method Get -Headers $authorization -Verbose
            Write-Host $runDetail.count

        }

                
    }


}



function Get-ReleaseNotesByTag()
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
        $FolderName
    )

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail
    
    # get a list of all folders. we will loop thru each folder and find all the builds for each.
    # if folder is specified just find builds in that folder. 
    # if build number is specified just report on that build
    #
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/folders/list?view=azure-devops-rest-6.0
    # GET https://dev.azure.com/{organization}/{project}/_apis/build/folders/{path}?api-version=6.0-preview.2
    $folderUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/folders?api-version=6.0-preview.2"
    $allFlders = Invoke-RestMethod -Uri $folderUri -Method Get -Headers $authorization -Verbose

    #build table array - list of all builds for this release
    $buildTableArray = @()

    $runLog = $userParams.LogDirectory + "runLog.txt"    
    $now = get-Date
    Write-Output "Run Started :" $now | Out-File $runLog -NoNewline
    Write-Output ""  | Out-File $runLog -Append

    Write-Output "   Run Filters: "  | Out-File $runLog -Append    
    if( $userParams.Tags -ne "")
    {
        Write-Output "   Tags to Include   : "   | Out-File $runLog -Append -NoNewline
        foreach( $tg in $userParams.Tags  )
        {
            Write-Output $tg " | "  | Out-File $runLog -Append -NoNewline
        }
        Write-Output ""  | Out-File $runLog -Append
    }

    # filter by folder if needed
    if ( $userParams.Folder -ne "")
    {
        $allFolders = $allFlders.value | Where-Object { $_.path -match $userParams.Folder}
        Write-Output "   Folder to Include :" $userParams.Folder  | Out-File $runLog -Append 
    }
    else 
    {
        $allFolders = $allFlders.value
        Write-Output "   Folder to Include : All Folders" | Out-File $runLog -Append 
    }
    
    if($userParams.BuildResults -ne "")
    {
        Write-Output "   Results to Include: "   | Out-File $runLog -Append -NoNewline
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

    if($userParams.BuildNumber -ne "")
    {
        Write-Output "   Build Number      : " $userParams.BuildNumber  | Out-File $runLog -Append  -NoNewline
        Write-Output ""  | Out-File $runLog -Append
    }

    if($userParams.Stages -ne "")
    {
        Write-Output "   Stages to Include : "   | Out-File $runLog -Append -NoNewline
        foreach( $st in $userParams.Stages   )
        {
            Write-Output $st " | "  | Out-File $runLog -Append -NoNewline
        }
        Write-Output ""  | Out-File $runLog -Append
    }
    if($userParams.Release -ne "")
    {
        Write-Output "   Release to Include : "   | Out-File $runLog -Append -NoNewline
        foreach( $rl in $userParams.Release   )
        {
            Write-Output $rl " | "  | Out-File $runLog -Append -NoNewline
        }
        Write-Output ""  | Out-File $runLog -Append
    }
    Write-Output ""  | Out-File $runLog -Append
    Write-Output ""  | Out-File $runLog -Append

    foreach ($folder in $allFolders)
    {
        # get list build definitions by folder. folders contain build definitions
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/list?view=azure-devops-rest-6.1
        # GET https://dev.azure.com/{organization}/{project}/_apis/build/definitions?name={name}&repositoryId={repositoryId}&repositoryType={repositoryType}&queryOrder={queryOrder}&$top={$top}&continuationToken={continuationToken}&minMetricsTime={minMetricsTime}&definitionIds={definitionIds}&path={path}&builtAfter={builtAfter}&notBuiltAfter={notBuiltAfter}&includeAllProperties={includeAllProperties}&includeLatestBuilds={includeLatestBuilds}&taskIdFilter={taskIdFilter}&processType={processType}&yamlFilename={yamlFilename}&api-version=6.1-preview.7
        $folderUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/definitions?path=" +$folder.path + "&includeAllProperties=true&includeLatestBuilds=true&api-version=6.1-preview.7"
        $AllDefinitions = Invoke-RestMethod -Uri $folderUri -Method Get -Headers $authorization 

        Write-Host "Folder: " $folder.path 

        foreach ($BuildDef in $AllDefinitions.value) 
        {
            Write-Host "Build Definition: " $BuildDef.name
            # get builds for each definition
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/list?view=azure-devops-rest-6.1
            # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds?definitions={definitions}&queues={queues}&buildNumber={buildNumber}&minTime={minTime}&maxTime={maxTime}&requestedFor={requestedFor}&reasonFilter={reasonFilter}&statusFilter={statusFilter}&resultFilter={resultFilter}&tagFilters={tagFilters}&properties={properties}&$top={$top}&continuationToken={continuationToken}&maxBuildsPerDefinition={maxBuildsPerDefinition}&deletedFilter={deletedFilter}&queryOrder={queryOrder}&branchName={branchName}&buildIds={buildIds}&repositoryId={repositoryId}&repositoryType={repositoryType}&api-version=6.1-preview.6
            $BuildUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds?definitions=" + $BuildDef.id + "&queryOrder=startTimeDescending&api-version=6.1-preview.6"
            $allBuilds = Invoke-RestMethod -Uri $BuildUri -Method Get -Headers $authorization 
            
            # filter on build results. only get builds with the results specified in projectdef array            
            if($userParams.BuildResults -ne "")
            {
                $allBuilds = $allBuilds.value | Where-Object { $_.result -in $userParams.BuildResults }               
            }

            # filter on BUild number 
            if($userParams.BuildNumber -ne "")
            {
                $allBuilds = $allBuilds.value | Where-Object { $_.buildNumber -in $userParams.BuildNumber }
            }

            # loop thru each build in the definition
            foreach ($build in $allBuilds) 
            {
                $tagFound = $false
                $buildTitle = $false

                # get work all items for this build
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/get%20build%20work%20items%20refs?view=azure-devops-rest-6.1
                # GET https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/workitems?api-version=6.1-preview.2
                $workItemUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/build/builds/" + $build.id + "/workitems?api-version=6.1-preview.2"
                $allBuildWorkItems = Invoke-RestMethod -Uri $workItemUri -Method Get -Headers $authorization 

                Write-Host "Folder:" $folder.path  " Build Def:" $BuildDef.name " Build ID :" $build.buildNumber "  Results: " $build.result  " Status : " $build.status " Number of workItems :" $allBuildWorkItems.count
                Write-Output "Folder:" $folder.path  " Build Def: " $BuildDef.name " Build ID: " $build.buildNumber " Status: " $build.status "Results: " $build.result " Number of workItems: " $allBuildWorkItems.count |  Out-File $runLog -Append -NoNewline
                Write-Output "" |  Out-File $runLog -Append 

                $buildTags = $build.Tags

                $lm0 = 0
                $lm1 = 0
                $lm2 = 0
                $lm3 = 0
                $lm4 = 0
                
                $lstBuild = ""
                $ArrayList = New-Object System.Collections.ArrayList
                $ArrayList = [System.Collections.ArrayList]::new()
                $fndUserStory = $false

                # loop thru all workitems looking for tag
                foreach ($workItem in $allBuildWorkItems.value)
                {
                    # get individual work item
                    # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items/get%20work%20item?view=azure-devops-rest-6.1
                    # GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?api-version=6.1-preview.3
                    $BuildworkItemUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/wit/workitems/" + $workItem.id + "?$" + "expand=All&api-version=6.1-preview.3" 
                    $WItems = Invoke-RestMethod -Uri $BuildworkItemUri -Method Get -Headers $authorization 
                    
                    $fld = $WItems.fields
                    $tg = $fld.'System.Tags'
                    $rel = $fld.'Custom.Release#'

                    $EnvName = $fld.'Custom.Environment'
                    $Area = $fld.'System.NodeName'

                    $wkType = $fld.'System.WorkItemType'
                    $wkState = $fld.'System.State'
                    $wkTitle = $fld.'System.Title'
                    
                    # reuse url field to house work item type. this will allow sorting of workitems by type
                    $WItems.url = $wktype

                    # save work items into an array to sort if tag was found
                    $ArrayList.Add($WItems) | Out-Null

                    Write-Host   "     Tag:" $tg " WorkItem ID:" $workItem.id 
                   # Write-Output "     WorkItem ID:"  $workItem.id " Tag:" $tg  " Title:"  $wkTitle | Out-File $runLog -Append -NoNewline
                   # Write-Output "" | Out-File $runLog -Append

                    # for spacing
                    if( $WItems.id.Length -gt $lm0 )
                    {
                       # $lm0 = ($wkType +  ":" + $WItems.id).Length
                        $lm0 =  $WItems.id.Length
                    }
                    if($wkState.length -gt $lm1 )
                    {
                        $lm1 =  $wkState.length
                    }
                    if($wkType.length -gt $lm2  )
                    {
                        $lm2 =  $wkType.length
                    }
                    if($tg.length -gt $lm3 )
                    {
                        $lm3 =  $tg.length
                    }
                    if($wkTitle.length -gt $lm4 )
                    {
                        $lm4 =  $wkTitle.length
                    }

                    # loop thru tags to searc for in each workitem
                    foreach ($tag in $userParams.Tags) 
                    {
                        if($tg -match $tag)    
                        {
                            Write-Host $tg 
                            Write-Host "     Tag: " $tg " WorkItem ID:" $workItem.id " Title :" $fld.'System.Title' " Iteration:" $fld.'System.IterationPath'
                            
                            Write-Output "     Tag: " $tg " WorkItem ID:" $workItem.id " Title :" $fld.'System.Title' " Iteration:" $fld.'System.IterationPath' "    Environment :" $EnvName | Out-File $runLog -Append -NoNewline
                            Write-Output "" |  Out-File $runLog -Append  

                            $tagFound = $true

                            #write build record
                            if($build.id -ne $lstBuild)
                            {
                                $bld = $BuildDef.Id.ToString() + "|" + $BuildDef.name.ToString() + "|" + $build.id.ToString() + "|"  + $build.buildNumber.ToString() + "|" + $Area.ToString() + "|" + $rel
                                $buildTableArray += $bld
                                $lstBuild = $build.id
                            }
                        }
                    }

                    # loop thru each release to search for value
                    # Release# is a custom field user will populate with release number
                    if (![string]::IsNullOrEmpty($rel ))
                    {
                        Write-Host "     Release: " $rel 
                        foreach ($rlData in $userParams.Release) 
                        {
                            if($rel -match $rlData)
                            {
                                Write-Host $rel
                                Write-Host "     Release: " $rel " WorkItem ID:" $workItem.id " Title :" $fld.'System.Title' " Iteration:" $fld.'System.IterationPath'

                                Write-Output "     Release: " $rel " WorkItem ID:" $workItem.id " Title :" $fld.'System.Title' " Iteration:" $fld.'System.IterationPath' | Out-File $runLog -Append -NoNewline
                                Write-Output "" |  Out-File $runLog -Append  
                                
                                $tagFound = $true
                                
                                # write build record
                                if($build.id -ne $lstBuild)
                                {
                                    $bld = $BuildDef.Id.ToString() + "|" + $BuildDef.name.ToString() + "|" + $build.id.ToString() + "|"  + $build.buildNumber.ToString() + "|" + $Area.ToString() + "|" + $rel
                                    $buildTableArray += $bld
                                    $lstBuild = $build.id
                                }

                            }    
                        }
                    }

                }

                #
                # tag found. now report on this build
                #
                if($tagFound -eq $true)
                {
                    $pth = $userParams.DataDirectory +  $folder.path + "\" + $build.status + "\" +  $build.result
                    $pth = $pth -replace ' ','' 
                    if(!(test-path  $pth))
                    {
                        New-Item -ItemType directory -Path $pth
                    }
                    # remove special characters
                    $defName = $BuildDef.name -replace '[\W]','_'
                    $outFile = $pth + "\" + $folder.path + "_" + $defName + "_" + $build.buildNumber + ".txt"
                    
                    # sort by url( work item type) decending
                    $allBuildWorkItemsSorted =  $ArrayList | Sort-Object -Property url -Descending

                    $UserStoryList = New-Object System.Collections.ArrayList
                    $UserStoryList = [System.Collections.ArrayList]::new()
                    
                    # loop thru workitems again and display
                    foreach ($workItem in $allBuildWorkItemsSorted)
                    {
                        # get individual work item from array list
                        $WItems = $workItem
                        $noUserStory = ""  

                        $wiRel = $WItems.'relations'
                        $fld = $WItems.fields

                        $tg = $fld.'System.Tags'
                        $rel = $fld.'Custom.Release#'
                        $EnvName = $fld.'Custom.Environment'
    
                        $wkType = $fld.'System.WorkItemType'
                        $wkState = $fld.'System.State'
                        $wkAssignto = $fld.'System.AssignedTo'
                        $wkTitle = $fld.'System.Title'
                        

                        if($wkType -notin "User Story", "Bug")
                        {
                            $origId =   $workItem.id 
                            #$origId =  $wkType +  ":" + $workItem.id 
                        }
                        else
                        {
                            $origId =  $workItem.id
                        }

                        # if not user story find parent user story
                        if($wkType -notin "User Story", "Bug")
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

                                    if($wiType -eq "User Story")
                                    {
                                        Write-Host $relWkItem

                                        $fld = $relWkItem.fields
                                        $tg = $fld.'System.Tags'
                                        $rel = $fld.'Custom.Release#'
                                        $EnvName = $fld.'Custom.Environment'
                
                                        $wkType = $fld.'System.WorkItemType'
                                        $wkState = $fld.'System.State'
                                        $wkAssignto = $fld.'System.AssignedTo'
                                        $wkTitle = $fld.'System.Title'
                                        
                                        $noUserStory = ""
                                        $origId  =  $fld.'System.Id'
                                        #$origId  =  $origId + "->" + $fld.'System.Id'
                                        continue 
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

                            if( ![string]::IsNullOrEmpty($rel))
                            {
                                Write-Output "  Release#:" $rel | Out-File $runLog -Append -NoNewline
                                Write-Output ""  | Out-File $runLog -Append

                                Write-Output "  Release#:" $rel | Out-File $outFile   -Append -NoNewline
                                Write-Output ""  | Out-File $outFile -Append
                            }

                            Write-Output " "  | Out-File $outFile -Append
                            Write-Output "     Work Items :"  | Out-File $outFile -Append -NoNewline
                            #Write-Output "     Work Items Found:"  $allBuildWorkItems.count  "        *** - No User Story found for Task " | Out-File $outFile -Append -NoNewline
                            Write-Output " "  | Out-File $outFile -Append
                            Write-Output " "  | Out-File $outFile -Append
                           
                        }

                       
                        # for spacing "".PadRight($l0," ") this will pad right $l0 number of spaces
                        $l0 = ($lm0 + 4) - $origId.length
                        if($l0 -lt 0)
                        {
                            $l0 = 20 - $origId.length
                        }
                        $l1 = ($lm1 + 1) - $wkState.length
                        if($l1 -lt 0)
                        {
                            $l1 = $lm1
                        }
                        $l2 = ($lm2 + 1) - $wkType.length
                        if($l2 -lt 0)
                        {
                            $l2 = $lm2
                        }
                        $l3 = ($lm3 + 1 )- $tg.length 
                        if($l3 -lt 0)
                        {
                            $l3 = $lm3
                        }
                        $l4 = ($lm4 + 1) - $wkTitle.length

                        $fndUserStory = $UserStoryList.Contains( $fld.'System.Id' )

                        # if no user story found display it
                        if(!$fndUserStory)
                        {
                            if($noUserStory -ne "")
                            {
                                #Write-Output $noUserStory " for " $wkType " ID :" $WItems.Id | Out-File $runLog -Append -NoNewline
                                #Write-Output ""  | Out-File $runLog -Append
                                
                                #Write-Output  $noUserStory "   ID:" $origId "".PadRight($l0," ") "Status:" $wkState "".PadRight($l1," ") "Type:" $wkType "".PadRight($l2," ") " Tag:" $tg "".PadRight($l3," ") " Title:" $fld.'System.Title' "".PadRight($l4," ") " Assigned to:" $wkAssignto.displayName | Out-File $outFile   -Append -NoNewline                            
                                #Write-Output ""  | Out-File $outFile -Append
                            }
                            else
                            {
                                Write-Output "      ID:" $origId "".PadRight($l0," ") "Status:" $wkState "".PadRight($l1," ") "Type:" $wkType "".PadRight($l2," ") " Tag:" $tg "".PadRight($l3," ") " Title:" $fld.'System.Title' "".PadRight($l4," ") " Assigned to:" $wkAssignto.displayName | Out-File $outFile   -Append -NoNewline                            
                                Write-Output ""  | Out-File $outFile -Append
                            }
                        }
                        $UserStoryList.Add($fld.'System.Id') | Out-Null
                      

                    }

                    #
                    # get approvals.
                    #
                    Get-BuildApprovers -userParams $userParams -build $build -outFile $outFile
                                        
                }
                        
            }
        }
    }

    # generate build release table
    $out = $userParams.DataDirectory + "BuildTable.txt"
    Get-BuildReleaseTable -userParams $userParams -buildTableArray $buildTableArray -BuildTable $out

    $now = get-Date
    Write-Output ""  | Out-File $runLog -Append
    Write-Output "Run Ended :" $now | Out-File $runLog -Append -NoNewline
    Write-Output ""  | Out-File $runLog -Append

}
