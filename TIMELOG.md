# Simple Time Log

Include a simple time log of the activities you have performed.

## Day 1

- Planning
- Research

## Day 2

- Research
- Finalize Requirements and Update Diagram

## Day 3

- Created Personal Azure and ADO Accounts
- Created Azure Repo
- Documentation

## Day 4

- Write Bicep Base Components

## Day 5

- Review Base
- Cleanup code
- Refactor code for Modular Structure

## Day 6

- Premium App Services will be used instead of App Service Environments due to Personal Budget limitations
- To compensate on data privacy, the demo will be done using P1V1 ASP with Access Restriction
- Firewall and App Gateway strategy is still intact

## Day 7

- Decided to create the simplest form of the components, just to serve a secure Web Apps
- Function apps will not be included due to assessment constraints
- Devised a plan for MVP: One pipeline to create the environment from bottom up as well as a single test file to determine the health of the hosted web apps
- Successfully created a webapp hosted in app service with direct-access restriction but can be publicly accessed via app gateway that has a WAF layer.

## Day 8

- Create and tested the secured Cosmos DB Environment
- No direct access to the official endpoint

## Day 9

- Created an on demand SFTP server that utilizes Storage Account as persistent storage

## Day 10

- Tested all assets
  - Cosmos DB via Python and Node
  - SFTP and Cosmos DB direct via Firewall endpoint

## Day 11

- Revamp Diagram
- Planned CICD for infrastructure

## Day 12

- Created Pipeline for Project

## Day 13

- Created final Pipeline for end-to-end deployment
  - 1 parameter file, 1 PFX file as inputs
  - 1 stage to test (what-if)
  - 1 stage to deploy (create)
  - 1 stage to Test
  - 1 test result artifact

## Day 14

- Upload to GitHub for public access
- Final Run for presentation
