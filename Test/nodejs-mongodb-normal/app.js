const express = require('express')
const app = express()
const port = process.env.PORT || 80
const mongoPass = "elMongoPass"
privateIp1= "192.168.3.4"
privateIp2= "192.168.3.5"


app.get('/', (req, res) => {
  res.send('Hello Node World! /local /privip1 /privip2')
});
app.get('/local', (req, res) => {
  var mongoClient = require("mongodb").MongoClient;
  mongoClient.connect("mongodb://jcbagtas-test-account:"+ mongoPass +"@jcbagtas-test-fw-backend.southeastasia.cloudapp.azure.com:10255/?ssl=true&tlsAllowInvalidCertificates=true&directConnection=true&retrywrites=false&maxIdleTimeMS=120000&appName=@jcbagtas-test-account@", function (err, client) {
      client.connect((err) => {
          const collection = client.db('jcbagtas-test-account').collection('testCollection');
          mongostring=collection.dbName
          console.log(mongostring)
           res.send('Hello Node World! Your database is ' + mongostring)
      });
    });
})

app.get('/privip1', (req, res) => {
  var mongoClient = require("mongodb").MongoClient;
  mongoClient.connect("mongodb://jcbagtas-test-account:"+ mongoPass +"@"+privateIp1+":10255/?ssl=true&tlsAllowInvalidCertificates=true&directConnection=true&retrywrites=false&maxIdleTimeMS=120000&appName=@jcbagtas-test-account@", function (err, client) {
      client.connect((err) => {
          const collection = client.db('jcbagtas-test-account').collection('testCollection');
          mongostring=collection.dbName
          console.log(mongostring)
           res.send('Hello Node World! Your database is ' + mongostring)
      });
    });
})
app.get('/privip2', (req, res) => {
  var mongoClient = require("mongodb").MongoClient;
  mongoClient.connect("mongodb://jcbagtas-test-account:"+ mongoPass +"@"+privateIp2+":10255/?ssl=true&tlsAllowInvalidCertificates=true&directConnection=true&retrywrites=false&maxIdleTimeMS=120000&appName=@jcbagtas-test-account@", function (err, client) {
      client.connect((err) => {
          const collection = client.db('jcbagtas-test-account').collection('testCollection');
          mongostring=collection.dbName
          console.log(mongostring)
           res.send('Hello Node World! Your database is ' + mongostring)
      });
    });
})
app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`)
})
