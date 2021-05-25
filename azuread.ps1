<#
.SYNOPSIS
Gets an access token from Azure Active Directory

.DESCRIPTION
Gets an access token from Azure Active Directory that can be used to authenticate to for example Microsoft Graph or Azure Resource Manager.

Run without parameters to get an access token to Microsoft Graph and the users original tenant.

Use the parameter -Interactive and the script will open the sign in experience in the default browser without user having to copy any code.

.PARAMETER ClientID
Application client ID, defaults to well-known ID for Microsoft Azure PowerShell

.PARAMETER Interactive
Tries to open sign-in experience in default browser. If this succeeds the user don't need to copy and paste any device code.

.PARAMETER TenantID
ID of tenant to sign in to, defaults to the tenant where the user was created

.PARAMETER Resource
Identifier for target resource, this is where the token will be valid. Defaults to  "https://graph.microsoft.com/"
Use "https://management.azure.com" to get a token that works with Azure Resource Manager (ARM)

.EXAMPLE
$Token = Connect-AzureDevicelogin -Interactive
$Headers = @{'Authorization' = "Bearer $Token" }
$UsersUri = 'https://graph.microsoft.com/v1.0/users?$top=5'
$Users = Invoke-RestMethod -Method GET -Uri $UsersUri -Headers $Headers
$Users.value.userprincipalname

Using Microsoft Graph to print the userprincipalname of 5 users in the tenant.

.EXAMPLE
$Token = Connect-AzureDevicelogin -Interactive -Resource 'https://management.azure.com'
$Headers = @{'Authorization' = "Bearer $Token" }
$SubscriptionsURI = 'https://management.azure.com/subscriptions?api-version=2019-11-01'
$Subscriptions = Invoke-RestMethod -Method GET -Uri $SubscriptionsURI -Headers $Headers
$Subscriptions.value.displayName

Using Azure Resource Manager (ARM) to print the display name for all the subscriptions the user has access to.

.NOTES

#>
function Connect-AzureDevicelogin {
    [cmdletbinding()]
    param( 
        [Parameter()]
        $ClientID = 'asdfasdf<szdf',
        
        [Parameter()]
        [switch]$Interactive,
        
        [Parameter()]
        $TenantID = 'asdfasdfasdfasdf',
        
        [Parameter()]
        $Resource = "https://graph.microsoft.com/",
        
        # Timeout in seconds to wait for user to complete sign in process
        [Parameter(DontShow)]
        $Timeout = 300
    )
    try {
        <#
        $DeviceCodeRequestParams = @{
            Method = 'POST'
            Uri    = "https://login.microsoftonline.com/$TenantID/oauth2/devicecode"
            Body   = @{
                resource  = $Resource
                client_id = $ClientId
            }
        }
        $DeviceCodeRequest = Invoke-RestMethod @DeviceCodeRequestParams
        #>

        # Step 1: Try to get authorization code
        # As seen in https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow#request-an-authorization-code

        <#
$AuthCodeUrl=@'
https://login.microsoftonline.com/$TenantID/oauth2/v2.0/authorize?
client_id=$ClientId
&response_type=code
&redirect_uri=http%3A%2F%2Flocalhost%2Fmyapp%2F
&scope=offline_access%20openid%20Presence.Read
'@
#>

$AuthCodeUrl="https://login.microsoftonline.com/$TenantID/oauth2/v2.0/authorize?" + 
"client_id=$ClientId" + 
"&response_type=code" +
"&redirect_uri=http%3A%2F%2Flocalhost%2Fmyapp%2F" + 
"&scope=offline_access%20openid%20Presence.Read"


        Write-Output $AuthCodeUrl

        Start-Sleep -Second 300

        $AuthCodeRequestParams = @{
            Method = 'POST'
            Uri    = "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/authorize"
            Body   = @{
                resource  = $Resource
                client_id = $ClientId
                response_type = 'code'
                redirect_uri = 'http%3A%2F%2Flocalhost%2Fmyapp%2F'
                scope = "offline_access%20openid%20Presence.Read"
            }
        }
        $AuthCodeRequest = Invoke-RestMethod @AuthCodeRequestParams

        

        Write-Output $AuthCodeRequest

        Start-Sleep -Second 300

        if ($Interactive.IsPresent) {
            Write-Host 'Trying to open a browser with login prompt. Please sign in.' -ForegroundColor Yellow
            Start-Sleep -Second 1
            $PostParameters = @{otc = $AuthCodeRequest.user_code }
            $InputFields = foreach ($entry in $PostParameters.GetEnumerator()) {
                "<input type=`"hidden`" name=`"$($entry.Name)`" value=`"$($entry.Value)`">"
            }
            $PostUrl = "https://login.microsoftonline.com/common/oauth2/deviceauth"
            $LocalHTML = @"
        <!DOCTYPE html>
<html>
 <head>
  <title>&hellip;</title>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <script type="text/javascript">
   function dosubmit() { document.forms[0].submit(); }
  </script>
 </head>
 <body onload="dosubmit();">
  <form action="$PostUrl" method="POST" accept-charset="utf-8">
   $InputFields
  </form>
 </body>
</html>
"@
            $TempPage = New-TemporaryFile
            $TempPage = Rename-Item -Path $TempPage.FullName ($TempPage.FullName -replace '$', '.html') -PassThru    
            Out-File -FilePath $TempPage.FullName -InputObject $LocalHTML
            Start-Process $TempPage.FullName
        }
        else {
            Write-Host $DeviceCodeRequest.message -ForegroundColor Yellow
        }

        $TokenRequestParams = @{
            Method = 'POST'
            Uri    = "https://login.microsoftonline.com/$TenantId/oauth2/token"
            Body   = @{
                grant_type = "urn:ietf:params:oauth:grant-type:device_code"
                code       = $DeviceCodeRequest.device_code
                client_id  = $ClientId
            }
        }
        $TimeoutTimer = [System.Diagnostics.Stopwatch]::StartNew()
        while ([string]::IsNullOrEmpty($TokenRequest.access_token)) {
            if ($TimeoutTimer.Elapsed.TotalSeconds -gt $Timeout) {
                throw 'Login timed out, please try again.'
            }
            $TokenRequest = try {
                Invoke-RestMethod @TokenRequestParams -ErrorAction Stop
            }
            catch {
                $Message = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($Message.error -ne "authorization_pending") {
                    throw
                }
            }
            Start-Sleep -Seconds 1
        }
        Write-Output $TokenRequest.access_token
    }
    finally {
        try {
            Remove-Item -Path $TempPage.FullName -Force -ErrorAction Stop
            $TimeoutTimer.Stop()
        }
        catch {
            # We don't care about errors here
        }
    }
}

Connect-AzureDevicelogin