
# GET ALL FOLDERS THAT NEED TO BE RUN (THOSE STARTING WITH "phase")
$folders = get-ChildItem .\ | where {$_.name -like "phase*"}

Import-Module ./vmware/powerCLI_modules/pwshFunctions.psd1

# SET THE VARIABLES ON THE CSV FILES AS ENVIRONMENTAL VARIABLES

$variable_files = Get-ChildItem .\variables | Where-Object {$_.Name -like '*.csv'}
foreach($file in $variable_files){
  ImportVarsFromCSV -Path $file
}

# CONVERT VARIABLES INTO JSON AND OUTPUT IT (FOR FURTHER TERRAFORM USAGE)
$new_path = ".\variables_json\"

if (Test-Path -Path $new_path){
} else{
  mkdir $new_path
}

foreach($file in $variable_files){
  $file_name = (Get-Item $file).Basename
  CSV_to_JSON -csv_file_path $file -json_file_path "$new_path$file_name.json"
}

foreach ($folder in $folders){
  cd $folder
  $folder_name = $folder.Name
# CHECK WHICH FOLDERS ARE TERRAFORM PHASES
  $searchresults = Get-ChildItem . | Where-Object {$_.Name -like '*.tf'}
  $searchresults_pwsh = Get-ChildItem . | Where-Object {$_.Name -like '*.ps1'}
  $pwsh_file = $searchresults_pwsh.Name

  if ($searchresults -ne $null) {
    if($folder_name -eq "phase1"){
      terraform init
      Invoke-Expression -Command "terraform plan -out $folder_name.tfplan"
      Invoke-Expression -Command "terraform apply '$folder_name.tfplan'"
    if($searchresults_pwsh -ne $null) {
      $powershell_file = $searchresults_pwsh.Name
     Write-host $searchresults_pwsh.Name
     Invoke-Expression -Command ".\$pwsh_file"
    }
    }
  }
}

cd ..


