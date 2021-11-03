function ImportVarsFromCSV{
  <#
    .NOTES
    ===========================================================================
    Created by:    Carlos Mestre del Pino
    Date:          13/08/2021
    Organization:  ITQ
    Blog:          http://www.mestredelpino.com
    Twitter:       @mestredelpino
    ===========================================================================

    .DESCRIPTION
        Creates environmental variables from a .csv file by using the file path
    .EXAMPLE
        ImportVarsFromCSV -Path .\path\with\file.csv
    .NOTES
        Your .csv file must start with: Variable, Value
#>
  Param(
    [Parameter(Mandatory=$true)][String]$Path
  )
  $variables = Import-Csv $Path -Delimiter ","
  foreach($item in $variables){"{0} = {1}" -f $item.Variable,$item.Value
#  New-Variable -Name $item.Variable -Value $item.Value -scope global -Force
  New-Item -Name $item.Variable -value $item.Value -ItemType Variable -Path Env: -Force
  New-Variable -Name $item.Variable -Value $item.Value -scope global -Force
  }

}

function Get-ESXIHost{
  <#
    .NOTES
    ===========================================================================
    Created by:    Ariel Cabral
    Date:          13/08/2021
    Organization:  ITQ
    Blog:          http://www.mestredelpino.com
    Twitter:       @
    ===========================================================================

    .DESCRIPTION
        Extracts one of the esxi hosts in a vSphere environment (requires Connect-VIServer)
    .EXAMPLE
        Get-ESXIHost -vmc_server_name -vmc_user -vmc_psswd
    .NOTES

#>
  Param(
    [Parameter(Mandatory=$true)][String]$vmc_server_name,
    [Parameter(Mandatory=$true)][String]$vmc_user,
    [Parameter(Mandatory=$true)][String]$vmc_psswd
  )
    Connect-VIServer $vmc_server_name -User $vmc_user -Password $vmc_psswd
    $your_esxi_host = (Get-Datacenter -PipelineVariable dc | Get-Cluster -PipelineVariable cluster | where-object {$_.Name -eq "Cluster-1"} | get-vmhost  |Select @{N = 'Host'; E = {$_.Name}}|select -last 1).Host
    return $your_esxi_host
}

function Get-VMCCredentials-From-TFState{
  <#
    .NOTES
    ===========================================================================
    Created by:    Carlos Mestre del Pino
    Date:          13/08/2021
    Organization:  ITQ
    Blog:          http://www.mestredelpino.com
    Twitter:       @mestredelpino
    ===========================================================================

    .DESCRIPTION
        Extracts VMC credentials (fqdn, username and password) from a remote terraform.tf state file and sets them as Terraform variables
    .EXAMPLE
        Get-VMCCredentials-From-TFState -TFState_Path .\path\with\file.tfstate
    .NOTES

#>
  Param(
    [Parameter(Mandatory=$true)][String]$TFState_Path,
    [Parameter(Mandatory=$true)][String]$SDDC_name

  )
  $terraform_state_p1 = (Get-Content $TFState_Path -Raw) | ConvertFrom-Json
  foreach($resource in $terraform_state_p1.resources){
    if($resource.type -eq "vmc_sddc" -and $resource.instances.attributes.sddc_name -eq $SDDC_name){
      [uri]$url = $resource.instances.attributes.vc_url
      $domain = $url.Authority -replace '^www\.'
      New-Variable -Name "TF_VAR_vsphere_url" $domain -scope global -Force
      New-Variable -Name "TF_VAR_vsphere_user" -Value $resource.instances.attributes.cloud_username -scope global -Force
      New-Variable -Name "TF_VAR_vsphere_password" -Value $resource.instances.attributes.cloud_password -scope global -Force
    }
  }
}


function Get-DatastoreURL{
  <#
    .NOTES
    ===========================================================================
    Created by:    Carlos Mestre del Pino
    Date:          13/08/2021
    Organization:  ITQ
    Blog:          http://www.mestredelpino.com
    Twitter:       @mestredelpino
    ===========================================================================

    .DESCRIPTION
        Extracts one of the esxi hosts in a vSphere environment (requires Connect-VIServer)
    .EXAMPLE
        Get-DatastoreURL -DatastoreName "WorkloadDatastore"
    .NOTES
#>
  Param(
    [Parameter(Mandatory=$true)][String]$DatastoreName
  )
  $datastore = Get-Datastore -Name $DatastoreName
  $datastoreURL = $datastore.ExtensionData.info.url
  return $datastoreURL
}

function CSV_to_JSON{
  <#
    .NOTES
    ===========================================================================
    Created by:    Carlos Mestre del Pino
    Date:          13/08/2021
    Organization:  ITQ
    Blog:          http://www.mestredelpino.com
    Twitter:       @mestredelpino
    ===========================================================================

    .DESCRIPTION
        Converts a csv file with variables into a json file
    .EXAMPLE
        CSV_to_JSON -csv_file_path "path\to\file.csv" -json_file_path "path\to\new\file.json"
    .NOTES
        Your .csv file must start with: Variable, Value
   #>
#>
  Param(
    [Parameter(Mandatory=$true)][String]$csv_file_path,
    [Parameter(Mandatory=$true)][String]$json_file_path
  )

$data = @{}
Import-Csv $csv_file_path | ForEach-Object {
    $data[$_.Variable] += @($_.Value)
}
$csv = $data.Keys | ForEach-Object {
    $_ + ',' + ($data[$_] -join ',')
}
$count = 1
$obj = [PSCustomObject]@{
    ($csv[0] -split ",")[0] = ($csv[0] -split ",")[1]
}
do {
    $obj | Add-Member -MemberType Noteproperty -Name ($csv[$count] -split ",")[0] -Value ($csv[$count] -split ",")[1]
    $count++
}
until($count -eq $csv.Count)
$obj | ConvertTo-Json > $json_file_path
}
