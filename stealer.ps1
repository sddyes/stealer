

irm : {"message": "The request body contains invalid JSON.", "code": 50109}
Au caractère Ligne:71 : 5
+     irm $wh -Method Post -Body (@{content="❌ EXCEPTION: $errorMsg"}|C ...
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation : (System.Net.HttpWebRequest:HttpWebRequest) [Invoke-RestMethod], WebEx
   ception
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeRestMethodCommand
