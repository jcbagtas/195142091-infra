# Assumptions and Decisions

Document any assumptions and decisions you have made.

## Managed Services

To fully utilize Azure Bicep, I decided to go and use Azure Managed Services for everything that the infrastructure might need.

## Network and Data Handling

After knowing that the client's data are sensitive I considered using Azure App Service Environment which is an Azure App Service feature that provides a fully isolated and dedicated environment for securely running App Service apps at high scale.

However, due to personal budget issues I decided to use an App Service Plan running on a Premium Host and secured via the Access Restriction feature.

Azure CosmosDB offers its own Application Firewall as well. But to centralize the inbound access, I decided to use the more robust Azure Firewall.

I utilized Azure Private Endpoint as well to make sure that all network interface are linked privately using private IP Addresses.

Azure Application Gateway is used as the reverse proxy which can be secured via NSG attached in its subnet.

Azure Firewall is used as a backend access for the Admin endpoints such as the CosmosDB and SFTP.

## Known Issues

1. App Gateway Cannot whitelist IP Addresses
1. SSL Termination for Firewall and App Gateway Transactions
1. A Better way to deploy Apps