# HelloID-Conn-Prov-Source-Raet-Beaufort-Sql-Query

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />

Raet (on-premise) - Source

HelloID provisioning source connector for Raet On-Premises based on SQL DB queries.
Please remember This is the first version of this connector. Any feedback will be appreciated!

<!-- TABLE OF CONTENTS -->
## Table of Contents
* [Introduction](#introduction)
* [Getting Started](#getting-started)
  * [Source](#source)
  * [Target](#target)
  * [Mappings](#mappings)
  * [Scope](#scope)
* [Setup the PowerShell connector](#setup-the-powershell-connector)

## Introduction
The interface to communicate with Beaufort On-Premises is through a set of Oracle or SQL DB queries.

For this connector we use the Sql database and queries.

<!-- GETTING STARTED -->
## Getting Started

By using this connector you will have the ability to retrieve employee and contract data from the HR Core Pulic On-Premises (previously known as Beaufort) HR system.

Connecting to Raet is done using ODBC connection. 

### Mappings
A basic person and contract mapping is provided. Make sure to further customize these accordingly.

### Scope

The data collection retrieved by the queries is a default set which is sufficient for HelloID to provision persons.
The queries can be changed by the customer itself to meet their requirements.

<!-- USAGE EXAMPLES -->
## Setup the PowerShell connector

1. Add a new 'Source System' to HelloID and make sure to import all the necessary files.

    - [ ] configuration.json
    - [ ] mapping.json
    - [ ] persons.ps1
    - [ ] departments.ps1

2. Fill in the required fields on the 'Configuration' tab.

![image](./assets/config.png)

_For more information about our HelloID PowerShell connectors, please refer to our general [Documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) page_

# HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
