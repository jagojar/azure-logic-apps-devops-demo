$rgName="logapps-devops-demo-rg"
$location="westus3"

az group create --name $rgName --location $location --tags SecurityControl=Ignore SecurityContext=Ignore

az deployment group create --resource-group $rgName --template-file main.bicep --parameters main.bicepparam