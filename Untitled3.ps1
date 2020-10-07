$sub = Get-AzureRmSubscription
$subJson = ConvertTo-Json $sub
Select-AzureSubscription -SubscriptionId 5812a6d7-817f-4798-b4ad-8a991a941edd

$grp = Get-AzureRmResourceGroup
$json = ConvertTo-Json $grp

write-host $json
