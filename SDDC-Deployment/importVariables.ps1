
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



