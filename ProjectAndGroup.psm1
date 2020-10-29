#
# FileName : ProjectAndGroup.psm1
# Data     : 02/09/2018
# Purpose  : this module will create a project and groups for a project
#           This script is for demonstration only not to be used as production code
#
# last update 8/1/2019

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
        $projectUri = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/defaultcollection/_apis/projects?api-version=2.0-preview"
        $currProjects = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization 

        $fnd = $currProjects.value | Where-Object {$_.name -eq $name}
        IF (![string]::IsNullOrEmpty($fnd)) {
            Write-Host "Project found"
            Return $fnd.name
        } 
        
        # project does not exist, create new one
        $projectUri = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/defaultcollection/_apis/projects?api-version=2.0-preview"
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
        $projectUri = "https://" + $userParams.VSTSMasterAcct + ".VisualStudio.com/DefaultCollection/_apis/projects/" + $userParams.ProjectName + "/teams?api-version=2.2"

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

                    $adduserUri = "https://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/users?groupDescriptors=" + $fnd.descriptor + "&api-version=4.0-preview"
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
            $projectUri = "https://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/groups?api-version=4.0-preview"
            $fnd = Invoke-RestMethod -Uri $projectUri -Method Post -Headers $authorization  -ContentType "application/json" -Body $tmJson       
    
            IF (![string]::IsNullOrEmpty($fnd)) {

                Write-Host "Team :" + $fnd.displayName + " Found, Descriptor : " + $fnd.descriptor

                foreach ( $usr in $item.users){

                    # add user to group
                    $userData = @{principalName = $usr}
                    $json = ConvertTo-Json -InputObject $userData

                    $adduserUri = "https://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/users?groupDescriptors=" + $fnd.descriptor + "&api-version=4.0-preview"
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
    $outFile = $userParams.DataDirectory + $outFile

    # get all teams in org. need to see if group is a team or group
    # GET https://dev.azure.com/{organization}/_apis/teams?api-version=6.1-preview.3
    $teamUri = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/teams?api-version=6.1-preview.3"
    $allTeams = Invoke-RestMethod -Uri $teamUri -Method Get -Headers $authorization 

    # find groups in all ado projects
    $projectUri = "https://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/groups?subjectTypes=vssgp&api-version=6.0-preview.1"
    $vssGroups = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 

    $projectUri = "https://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/groups?subjectTypes=aadgp&api-version=6.0-preview.1"
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

    Write-Output 'Project|Group Name|Type|Relationship|User Name|Email Address|Fedex ID' | Out-File -FilePath $outFile
    Write-Output " " | Out-File -FilePath $outFile -Append 

    foreach ($item in $fnd) {
        # find group memberships frm identity api
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/ims/identities/read%20identities?view=azure-devops-rest-6.1#examples
        
        # search by name and get direct membership: need to use direct here and in the following query to get all direct members and member of
        # to mimic whats in ADO
        # GET https://vssps.dev.azure.com/fabrikam/_apis/identities?searchFilter=General&filterValue=jtseng@vscsi.us&queryMembership=None&api-version=6.1-preview.1
        #
        $grpMemberUrl = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?searchFilter=General&filterValue="  + $item.principalName + "&queryMembership=direct&api-version=6.1-preview.1"
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
            $teamGroup = "G-Delivered"
        }else {
            $teamGroup = "T-Custom"
        }

        if($allGrpMembers.value[0].members -ne 0)
        {        
            # get members this user is a member of
            foreach ($member in $allGrpMembers.value[0].memberOf ) {

                # now search by descriptor. sisnce we have all the direct members of the group  value[0].members
                $memberUrl = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?descriptors="  + $member + "&queryMembership=direct&api-version=6.1-preview.1"            
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
                $memberUrl = "https://vssps.dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/identities?descriptors="  + $member + "&queryMembership=direct&api-version=6.1-preview.1"            
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
        $projectUri = "https://" + $userParams.VSTSMasterAcct + ".vssps.visualstudio.com/_apis/graph/groups?api-version=4.0-preview"
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
        $listProviderURL = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories?api-version=5.0"
        $repo = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 
    
       
        try {
            Write-Output "  " | Out-File -FilePath $outFile -Append
            Write-Output " Repositories  " | Out-File -FilePath $outFile -Append
            
            # find branches for given repo
            $listProviderURL = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories/" + $repo.value[0].Id + "/refs?api-version=5.0"
            $branchlist = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 

            foreach ($item in $branchlist.value) {
                Write-Host "Repositories : " $item.name 
                Write-Output "  " | Out-File -FilePath $outFile -Append
                Write-Output '   Repositories : '$item.name | Out-File -FilePath $outFile -Append -NoNewline
            }    
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
        $listProviderURL = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories?api-version=5.0"
        $repo = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 
       
        try {
            
            # find branches for given repo
            $URL = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories/" + $repo.value[0].Id + "/refs?api-version=5.0"
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
            $listProviderURL = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories?api-version=5.0"
            $repo = Invoke-RestMethod -Uri $listProviderURL -Method Get -ContentType "application/json" -Headers $authorization 
       
            # get master branch id
            $URL = "https://dev.azure.com/" + $userParams.VSTSMasterAcct + "/" + $userParams.ProjectName + "/_apis/git/repositories/" + $repo.value[0].Id + "/refs?api-version=5.0"
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
    $projectUri = "https://" + $userParams.VSTSMasterAcct + ".VisualStudio.com/DefaultCollection/_apis/projects/" + $userParams.ProjectName +"?api-version=1.0"
    $return = Invoke-RestMethod -Uri $projectUri -Method Get -ContentType "application/json" -Headers $authorization 

    IF ([string]::IsNullOrEmpty($return)) {
        $projId = $return.id

        # create json body for request
        $repo = @{name = $userParams.RepositoryName
            project = @{id = $projId}
        }
        $tmJson = ConvertTo-Json -InputObject $repo

        # REST call to create Git Repo
        $projectUri = "https://" + $userParams.VSTSMasterAcct + ".VisualStudio.com/DefaultCollection/_apis/git/repositories?api-version=1.0"

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
    $groupUri = "https://" + $vstsAccount + ".vssps.visualstudio.com/_apis/graph/groups?api-version=4.0-preview"
    $returnValue = Invoke-RestMethod -Uri $groupUri -Method Get -ContentType "application/json" -Headers $authorization
    Write-Host $returnValue

}

function GetVSTSProcesses() {
    Param(
        $userParams ,
        $authorization
    )
   
    try {
        $projectUri = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/process/processes?api-version=1.0"
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
    $projectUri = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"
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
    $queueCreateUrl = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/" + $userParams.ProjectName + "/_apis/distributedtask/queues?api-version=3.0-preview.1"
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
            "url"           = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/" + $userParams.ProjectName + "/_git/" + $userParams.RepositoryName
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
    $buildUri = "https://" + $userParams.VSTSMasterAcct + ".visualstudio.com/DefaultCollection/" + $userParams.ProjectName + "/_apis/build/definitions?api-version=4.1-preview"
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