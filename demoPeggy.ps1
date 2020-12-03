
$userEmail = "arthur.garcia.osv@fedex.com"
$PAT = "37ffftez7dnwosok2ybs2j2xdmoi7szpsizsworzmcakmuzkjkva"

function GetVSTSCredential () {
    Param(
        $userEmail,
        $Token
    )

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $userEmail, $token)))
    return @{Authorization = ("Basic {0}" -f $base64AuthInfo)}
}


 # Base64-encodes the Personal Access Token (PAT) appropriately
 $authorization = GetVSTSCredential -Token $PAT -userEmail $userEmail
   
$AllBuildsUri = "http://dev.azure.com/fdx-strat-pgm/fdx-surround//_apis/build/builds?api-version=6.1-preview.6"
$AllBuildswithTags = Invoke-RestMethod -Uri $AllBuildsUri -Method Get -Headers $authorization -Proxy "https://esso.secure.fedex.com/infosec/proxy:3128" -ProxyUseDefaultCredentials

Write-Host $AllBuildswithTags.count

