
# GET ALL FOLDERS THAT NEED TO BE RUN (THOSE STARTING WITH "phase")
$folders = get-ChildItem .\ | where {$_.name -like "phase*"}

Import-Module ./vmware/powerCLI_modules/pwshFunctions.psd1

ImportVarsFromCSV ./variables/vmc_variables.csv
ImportVarsFromCSV ./variables/vpn_variables.csv
ImportVarsFromCSV ./variables/aws_variables.csv


foreach ($folder in $folders){
  cd $folder
  $folder_name = $folder.Name
  $folder_name
# CHECK WHICH FOLDERS ARE TERRAFORM PHASES
  $searchresults = Get-ChildItem . | Where-Object {$_.Name -like '*.tf'}
  if ($searchresults -ne $null) {
    if($folder_name -eq "phase1"){
    }
    else{
      Write-Host "Starting $folder_name"
      terraform init
      Invoke-Expression -Command "terraform plan -out $folder_name.tfplan"
      Invoke-Expression -Command "terraform apply '$folder_name.tfplan'"
    }
  }
  else {
    Write-Host "Starting $folder_name"
    $searchresults | foreach {$_.Path}
    get-ChildItem | Where-Object {$_.Name -like '*.ps1'} | % {  & $_.FullName }
    Write-Host "$folder_name was successfull" -fore green
    cd ..
  }
}
cd ..


