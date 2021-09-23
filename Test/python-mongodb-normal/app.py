# SIMPLE PYTHON APP To Test MongoDB Connectivity

# Run this
# Update mongoPass variable, get the password from Azure Portal
# python3 -m venv .venv
# source .venv/bin/activate
# pip install -r requirements.txt
# Then `flask run`
# Using a Browser go to 127.0.0.1:5000/local
# Using a Browser go to jcbagtas-test-public-gateway.southeastasia.cloudapp.azure.com/python/online
# 
# Deploy this using VSCODE Azure App Services
#
# Note: ssl_cert_reqs=CERT_NONE is equivalent to an SSL termination
#

from flask import Flask
app = Flask(__name__)
import pymongo


# UPDATE THIS BEFORE DEPLOYING! By default, CosmosDB deploys MongoDB on These private IPs. (192.168.3.4 and .3.5) 
mongoPass = "elMongoPass"

privateIp1= "192.168.3.4"
privateIp2= "192.168.3.5"

@app.route("/")
def home():
    return "Nothing feels like 127.0.0.1"

@app.route("/local")
def local():
    ## for local machine
    uri = "mongodb://jcbagtas-test-account:" + mongoPass + "@jcbagtas-test-fw-backend.southeastasia.cloudapp.azure.com:10255/?ssl=true&ssl_cert_reqs=CERT_NONE&directConnection=true&retrywrites=false&maxIdleTimeMS=120000&appName=@jcbagtas-test-account@test"
    client = pymongo.MongoClient(uri)
    names = client.list_database_names()
    namestr = ','.join(names)
    if namestr != "":
        return "Hello, Python World! We are connected to the Database via Firewall Whitelist! Databases: [" + namestr + "]"
    return "Hello, Python World! No database connected"

@app.route("/privip1")
def privone():
    ## Use this when connecting from inside an App Service
    uri2 = "mongodb://jcbagtas-test-account:" + mongoPass + "@"+ privateIp1 +":10255/?ssl=true&ssl_cert_reqs=CERT_NONE&directConnection=true&retrywrites=false&maxIdleTimeMS=120000&appName=@jcbagtas-test-account@test"
    client = pymongo.MongoClient(uri2)

    names = client.list_database_names()
    namestr = ','.join(names)
    if namestr != "":
        return "Hello, Python World! We are connected to the Database Privately! Databases: [" + namestr + "]"
    return "Hello, Python World! No database connected"


@app.route("/privip2")
def privtwo():
    ## Use this when connecting from inside an App Service
    uri3 = "mongodb://jcbagtas-test-account:" + mongoPass + "@"+ privateIp2 +":10255/?ssl=true&ssl_cert_reqs=CERT_NONE&directConnection=true&retrywrites=false&maxIdleTimeMS=120000&appName=@jcbagtas-test-account@test"
    client = pymongo.MongoClient(uri3)

    names = client.list_database_names()
    namestr = ','.join(names)
    if namestr != "":
        return "Hello, Python World! We are connected to the Database Privately! Databases: [" + namestr + "]"
    return "Hello, Python World! No database connected"

