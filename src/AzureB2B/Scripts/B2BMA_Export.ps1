param(    
    [System.Collections.ObjectModel.KeyedCollection[[string], [Microsoft.MetadirectoryServices.ConfigParameter]]]
    $ConfigParameters,
    [Microsoft.MetadirectoryServices.Schema]
    $Schema,
    [Microsoft.MetadirectoryServices.OpenExportConnectionRunStep]
    $OpenExportConnectionRunStep,
    [System.Collections.Generic.IList[Microsoft.MetaDirectoryServices.CSEntryChange]]
    $CSEntries,
    [PSCredential]
    $PSCredential
)

Set-PSDebug -Strict

Import-Module (Join-Path -Path ([Microsoft.MetadirectoryServices.MAUtils]::MAFolder) -ChildPath 'xADSyncPSConnectorModule.psm1') -Verbose:$false

##TODO: build path dynamically (Get-Module AzureADPreview).Path
$graph = "C:\Program Files\WindowsPowerShell\Modules\AzureADPreview\2.0.1.2\Microsoft.Open.MS.GraphBeta.Client.dll"
[System.Reflection.Assembly]::LoadFrom($graph) | Out-Null


function CreateCustomPSObject
{
    param
    (
        $PropertyNames = @()
    )
    $template = New-Object -TypeName System.Object

    foreach ($property in $PropertyNames)
    {
        $template | Add-Member -MemberType NoteProperty -Name $property -Value $null
    }

    return $template
}

$csentryChangeResults = New-GenericObject System.Collections.Generic.List Microsoft.MetadirectoryServices.CSEntryChangeResult

$columnsToExport = @()
foreach ($attribute in $Schema.Types[0].Attributes)
{
    $columnsToExport += $attribute.Name
    Write-Verbose "Added attribute $($attribute.Name) to export list"
}

Write-Verbose "Loaded $($columnsToExport.Count) attributes to export" 

$invitations = @()
foreach ($entry in $CSEntries)
{
    Write-Verbose "Processing object $($entry.Identifier)"

    [bool]$objectHasAttributes = $false
    $baseObject = CreateCustomPSObject -PropertyNames $columnsToExport

    if ($entry.ModificationType -ne 'Delete')
    {
        foreach ($attribute in $columnsToExport)
        {                              
            if (($entry.AttributeChanges.Contains($attribute)) -eq $false -and ($entry.AnchorAttributes.Contains($attribute) -eq $false))
            {
                continue
            }
            
            if ($entry.AnchorAttributes[$attribute].Value)
            {
                $baseObject.$attribute = $entry.AnchorAttributes[$attribute].Value
                $objectHasAttributes = $true
            }
            elseif ($entry.AttributeChanges[$attribute].ValueChanges[0].Value)
            {
                $baseObject.$attribute = $entry.AttributeChanges[$attribute].ValueChanges[0].Value
                $objectHasAttributes = $true
            }            
        }

        if ($objectHasAttributes)
        {
            $invitations += $baseObject
        }
		$csentryChangeResult = [Microsoft.MetadirectoryServices.CSEntryChangeResult]::Create($entry.Identifier, $null, "Success")
    } 

    $csentryChangeResults.Add($csentryChangeResult) 
    Write-Verbose "Completed processing object $($entry.Identifier)"   
}


# Invitation variables

##TODO: Fix xADSyncPSConnectorModule.psm1 when scope not provided
#$tenant = Get-xADSyncPSConnectorSetting -Name 'Server' -Scope Global -ConfigurationParameters $ConfigParameters
$tenant = $ConfigParameters['Server'].Value
Write-Verbose "Tenant Domain is $tenant"
$redirectUrl = "https://myapps.microsoft.com/$tenant"
Write-Verbose "Setting redirect URL to $redirectUrl"
$messageInfo = New-Object Microsoft.Open.MSGraph.Model.InvitedUserMessageInfo
$messageInfo.customizedMessageBody = Get-xADSyncPSConnectorSetting -Name 'MessageBody' -Scope Global -ConfigurationParameters $ConfigParameters
Write-Verbose "Setting message body to $($messageInfo.customizedMessageBody)"
$sendMessage = [bool]::Parse((Get-xADSyncPSConnectorSetting -Name 'SendMessage' -Scope Global -ConfigurationParameters $ConfigParameters))
Write-Verbose "Setting send message to $sendMessage"


##TODO: Add Try/Catch
Connect-AzureAD -Credential $PSCredential -TenantDomain $tenant | Out-Null


foreach ($email in $invitations)
{
	Write-Verbose "Sending invitation to $($email.Mail) - $($email.DisplayName)"
	New-AzureADMSInvitation -InvitedUserEmailAddress $email.Mail `
							-InvitedUserDisplayName $email.DisplayName `
							-InviteRedirectUrl $redirectUrl `
							-InvitedUserMessageInfo $messageInfo `
							-SendInvitationMessage $sendMessage `
							| Out-Null
}



$result = New-Object -TypeName Microsoft.MetadirectoryServices.PutExportEntriesResults

$closedType = [Type] "Microsoft.MetadirectoryServices.PutExportEntriesResults"
return [Activator]::CreateInstance($closedType, $csentryChangeResults) 
