$ServicePrincipalClientId="ede4ced5-7241-4792-bd34-99b3cd23b6b2";
$ServicePrincipalSecret="<ENTER SECRET HERE>";

.\DeployGPO.ps1 -DomainFQDN dev.lab `
-ReportServerFQDN srv1.dev.lab `
-ArcRemoteShare AzureArc `
-ServicePrincipalSecret $ServicePrincipalSecret `
-ServicePrincipalClientId $ServicePrincipalClientId `
-SubscriptionId 2272a9d6-ae77-4ecb-8852-5c8866ee5a51 `
-ResourceGroup DemoAzureArc929575 `
-Location eastus `
-TenantId 3931f026-9b8a-4d3a-85b9-f8990331fe84