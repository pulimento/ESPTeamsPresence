1) try to log in using the device flow approach:

- To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code C28M3LMWE to authenticate.
- A configuration issue is preventing authentication - check the error message from the server for details. You can modify the configuration in the application registration portal. See https://aka.ms/msal-net-invalid-client for details.  Original exception: AADSTS7000218: The request body must contain the following parameter: 'client_assertion' or 'client_secret'.
Trace ID: f737fc67-6196-402c-95ef-0336447fdc00
Correlation ID: 06ad3700-c509-40a4-9051-bb0081b81ebc
Timestamp: 2021-05-25 21:45:12Z
Press any key to exit

Login OK, but no way to get access tokens.

It seems that the solution is: 

Allow public client flows on Azure App, and
add a platform (remove web, and add mobile and desktop)
https://nishantrana.me/2020/12/01/fixed-aadsts7000218-the-request-body-must-contain-the-following-parameter-client_assertion-or-client_secret/
https://github.com/Azure-Samples/active-directory-dotnetcore-devicecodeflow-v2#register-the-client-app-active-directory-dotnet-deviceprofile
https://github.com/MicrosoftDocs/azure-docs/issues/61446

También lo he probado en un proyecto de consola que sigue el mismo approach: https://github.com/azure-samples/active-directory-dotnet-desktop-msgraph-v2



2) try to log in using the SPAs approach (not device code-based, but using a redirect uri)

See: https://github.com/MicrosoftDocs/azure-docs/issues/61446

You end doing a request with the browser, something like this:

$AuthCodeUrl="https://login.microsoftonline.com/$TenantID/oauth2/v2.0/authorize?" + 
"client_id=$ClientId" + 
"&response_type=code" +
"&redirect_uri=http%3A%2F%2Flocalhost%2Fmyapp%2F" + 
"&scope=offline_access%20openid%20Presence.Read"

But you need to configure (in Azure) to have the exact same redirect URI that you're using with your request

https://docs.microsoft.com/en-us/answers/questions/183594/aadsts500113-no-reply-address-is-registered-for-th.html

