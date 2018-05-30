param( 
    [System.Collections.ObjectModel.KeyedCollection[[string], [Microsoft.MetadirectoryServices.ConfigParameter]]]  
    $ConfigParameters,
    [PSCredential]
    $PSCredential
)

Set-PSDebug -Strict

$anchorAttribute = 'Mail'
$attributes = @('DisplayName')

Import-Module (Join-Path -Path ([Environment]::GetEnvironmentVariable('TEMP', [EnvironmentVariableTarget]::Machine)) -ChildPath 'xADSyncPSConnectorModule.psm1') -Verbose:$false

$schema = New-xADSyncPSConnectorSchema

$schemaType = New-xADSyncPSConnectorSchemaType -Name 'Guest'

$schemaType | Add-xADSyncPSConnectorSchemaAttribute -Name $anchorAttribute -DataType String -SupportedOperation ImportExport -Anchor

foreach ($attr in $attributes)
{
    $schemaType | Add-xADSyncPSConnectorSchemaAttribute -Name $attr -DataType String -SupportedOperation ImportExport
}

$schema.Types.Add($schemaType)

Write-Output $schema