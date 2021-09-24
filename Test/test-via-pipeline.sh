#!/bin/bash
az config set extension.use_dynamic_install=yes_without_prompt

paramFile=$1
projectName=$(cat $paramFile | jq -cr ".parameters.ProjectName.value")

az webapp deployment user set --user-name deployer200 --password roadTo200k

mongoPass=$(az cosmosdb keys list -g "${projectName}-rg" --name "${projectName}-test-account" --query primaryMasterKey --output tsv)

echo "Allow Agent from Firewall"

fwPip=$(az network public-ip show -g "${projectName}-rg" -n "${projectName}-Test-fw-backend-ip" --query "ipAddress" --output tsv)
source=$(curl ifconfig.me)
az network firewall nat-rule create --collection-name agent-public-access --dest-addr $fwPip  --destination-ports 10255 --firewall-name "${projectName}-fw" --name agent-mongodb-inbound --protocols TCP --resource-group "${projectName}-rg" --translated-port 10255 --translated-address 192.168.3.4 --priority 2000 --action Dnat --source-addresses $source

echo "===== START PYTHON APP DEPLOYMENT ====="

sudo rm -rf "pythondeploy"
mkdir -p "pythondeploy"
cd pythondeploy
pwd

pythonGitUrl=$(az webapp deployment source config-local-git --name ${projectName}-test-internal-webapp-python-1 -g ${projectName}-rg | jq -cr ".url")
newPythonGitUrl=$(echo $pythonGitUrl | sed 's/deployer200/deployer200:roadTo200k/g')
git init
git remote add pythonGit $newPythonGitUrl
git pull pythonGit master

cp -a "../python-mongodb-normal/." .

sed -i "s/elMongoPass/$mongoPass/g" app.py

git add . && git commit -m "Deploy test python app."
git push pythonGit master --force

sed -i "s/$mongoPass/elMongoPass/g" app.py
cd ../
sudo rm -rf "pythondeploy"
echo "===== FINISH PYTHON APP DEPLOYMENT ====="




echo "===== START NODE APP DEPLOYMENT ====="

sudo rm -rf "nodedeploy"
mkdir -p "nodedeploy"
cd nodedeploy
pwd

nodeGitUrl=$(az webapp deployment source config-local-git --name ${projectName}-test-internal-webapp-node-1 -g ${projectName}-rg | jq -cr ".url")
newNodeGitUrl=$(echo $nodeGitUrl | sed 's/deployer200/deployer200:roadTo200k/g')
git init
git remote add nodejsGit $newNodeGitUrl
git pull nodejsGit master


cp -a "../nodejs-mongodb-normal/." .

sed -i "s/elMongoPass/$mongoPass/g" app.js

git add . && git commit -m "Deploy test node app."
git push nodejsGit master --force

sed -i "s/$mongoPass/elMongoPass/g" app.js
cd ../
sudo  rm -rf "nodedeploy"
echo "===== FINISH NODE APP DEPLOYMENT ====="


internalAppAccess="Invalid"
internalMongoDbAccess="Invalid"
externalAppAccess="Invalid"
externalMongoDbAccess="Invalid"
externalPythonMongo="Invalid"
externalNodeMongo="Invalid"

echo "CHECK PRIVATE ASSETS PRIVACY"

# CHECK INTERNAL PYTHON AND NODE APPS ACCESS
echo "CHECK INTERNAL PYTHON AND NODE APPS ACCESS"
internalPy=$(curl -i -s -k https://${projectName}-test-internal-webapp-python-1.azurewebsites.net/ | grep -c "HTTP/2 403")
internalNo=$(curl -i -s -k https://${projectName}-test-internal-webapp-python-1.azurewebsites.net/ | grep -c "HTTP/2 403")

internalTotal=$((internalPy + internalNo))

if [ $internalTotal -eq 2 ];then
    internalAppAccess="Private"
fi

# CHECK INTERNAL COSMOSDB-MONGODB ACCESS
echo "CHECK INTERNAL COSMOSDB-MONGODB ACCESS"
internalMongo=$(mongosh ${projectName}-test-account.mongo.cosmos.azure.com:10255 -u ${projectName}-test-account -p $mongoPass --tls --tlsAllowInvalidCertificates)

internalMongoTotal=$(echo $internalMongo | grep -c "direct: primary] test")

internalMongoTotal=$((internalMongoTotal + 0))

if [ $internalMongoTotal -eq 0 ];then
    internalMongoDbAccess="Private"
fi

# CHECK PUBLIC ASSETS
echo "CHECK PUBLIC ASSETS"

externalPy=$(curl -i -s -k https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/node/ | grep -c "HTTP/2 200")
externalNo=$(curl -i -s -k https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/python/ | grep -c "HTTP/2 200")

externalTotal=$((externalPy + externalNo))

if [ $externalTotal -eq 2 ];then
    externalAppAccess="Accessible via App Gateway"
fi

# CHECK EXTERNAL COSMOSDB-MONGODB ACCESS
echo "CHECK EXTERNAL COSMOSDB-MONGODB ACCESS"
externalMongo=$(echo exit | mongosh ${projectName}-test-fw-backend.southeastasia.cloudapp.azure.com:10255 -u ${projectName}-test-account -p $mongoPass --tls --tlsAllowInvalidCertificates)

externalMongoTotal=$(echo $externalMongo | grep -c "direct: primary] test")

externalMongoTotal=$((externalMongoTotal + 0))

if [ $externalMongoTotal -eq 1 ];then
    externalMongoDbAccess="Accessible via Firewall"
fi

# CHECK EXTERNAL PYTHON MONGO APPS ACCESS
echo "CHECK EXTERNAL PYTHON MONGO APPS ACCESS"
echo "Sleeping for 30 seconds for the Initial Deployments to stabalize..."
sleep 30
externalPyMong1=$(curl -i -s -k https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/python/privip1 | grep -c "HTTP/2 200")
externalPyMong2=$(curl -i -s -k https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/python/privip2 | grep -c "HTTP/2 200")

externalNoMong1=$(curl -i -s -k https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/node/privip1 | grep -c "HTTP/2 200")
externalNoMong2=$(curl -i -s -k https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/node/privip2 | grep -c "HTTP/2 200")

externalPyMongTotal=$((externalPyMong1 + externalPyMong2))
externalNoMongTotal=$((externalNoMong1 + externalNoMong2))

if [ $externalPyMongTotal -eq 2 ];then
    externalPythonMongo="Accessible via Firewall"
fi
if [ $externalNoMongTotal -eq 2 ];then
    externalNodeMongo="Accessible via Firewall"
fi

# CHECK SFTP
echo "CHECK SFTP"
echo "Please check SFTP Manually. ${projectName}-test-fw-backend.southeastasia.cloudapp.azure.com:2222"

referenceUrls="https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/python/privip1, https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/python/privip2, https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/node/privip1, https://${projectName}-test-public-gateway.southeastasia.cloudapp.azure.com/node/privip2, ${projectName}-test-fw-backend.southeastasia.cloudapp.azure.com:10255, ${projectName}-test-fw-backend.southeastasia.cloudapp.azure.com:2222"

jq -n --arg internalAppAccess "$internalAppAccess" --arg internalMongoDbAccess "$internalMongoDbAccess" --arg externalAppAccess "$externalAppAccess" --arg externalMongoDbAccess "$externalMongoDbAccess" --arg externalPythonMongo "$externalPythonMongo" --arg externalNodeMongo "$externalNodeMongo" --arg referenceUrls "$referenceUrls" '{result: {internalAppAccess:$internalAppAccess, internalMongoDbAccess:$internalMongoDbAccess, externalAppAccess: $externalAppAccess, externalMongoDbAccess:$externalMongoDbAccess, externalPythonMongo:$externalPythonMongo, externalNodeMongo:$externalNodeMongo, referenceUrls:$referenceUrls}}' > test-results.json


