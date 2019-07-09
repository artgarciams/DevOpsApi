#
# Fileaction : Helper.psm1
# Data     : 03/20/2018
# Purpose  : this module has helper methods
#





function Get-GroupDescriptor () {
    param(
        [Parameter(Mandatory = $true)]
        $userParams,
        [Parameter(Mandatory = $true)]
        $groupaction
    )

    $grpInfo =  Get-GroupInfo -userParams $userParams -groupaction $groupaction
    IF (![string]::IsNullOrEmpty($grpInfo)) {

         
        # Base64-encodes the Personal Access Token (PAT) appropriately
        $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail

        # find groups
        #$projectUri = "https://" + $userParams.VSTSMasterAcct + ".vsaex.visualstudio.com/_apis/groupentitlements/"+ $grpInfo.originId + "?api-version=4.1-preview"
        #$grpEntitlments = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $authorization 
        return $grpInfo.descriptor
        
        # return "Microsoft.VisualStudio.Services.Identity;" +  $grpInfo.domain + "\" + "[" + $groupaction + "]"
        # for later use
        #descriptor = "Microsoft.IdentityModel.Claims.ClaimsIdentity;" +  $domain + "\" + $userParams.userEmail
        #descriptor = "Microsoft.VisualStudio.Services.Identity;" + $grp.descriptor
    }
}
