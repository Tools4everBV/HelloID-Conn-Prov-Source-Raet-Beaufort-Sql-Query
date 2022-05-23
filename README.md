# HelloID-Conn-Prov-Source-Raet-Beaufort-Sql-Query

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />

## Versioning
| Version | Description | Date |
| - | - | - |
| 1.1.0   | Updated logging and added thresholds filter to exclude contracts of past (outside of specified threshold) | 2022/05/23  |
| 1.0.0   | Initial release | 2021/05/20  |

<!-- TABLE OF CONTENTS -->
## Table of Contents
- [HelloID-Conn-Prov-Source-Raet-Beaufort-Sql-Query](#helloid-conn-prov-source-raet-beaufort-sql-query)
  - [Versioning](#versioning)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
    - [Mappings](#mappings)
    - [Scope](#scope)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction
_HelloID-Conn-Prov-Source-Raet-Beaufort-Sql-Query is a _source_ connector. By using this connector you will have the ability to retrieve employee and contract data from the HR Core Pulic On-Premises (previously known as Beaufort) HR system. The data will be queried directly from the SQL database itself and therefore has to be run On-Prem.
The HelloID connector consists of the template scripts shown in the following table.


| Action          | Action(s) Performed                                                         | Comment                           | 
| --------------- | --------------------------------------------------------------------------- | --------------------------------  |
| persons.ps1     | Query all employees inlcuding their contract (and optionally position) data | The use of positions is optional. The default setting is to no include positions, but this can be changed accordingly in the configuration  |
| departments.ps1 | Query all departments and managers of departments                           | The manager of a department is defined by a specific manager type code. The default for this is "MGR", but can be changed accordingly in the configuration |


## Getting started
### Connection settings
The following settings are required to run the source import.

| Setting             | Description                                                                                     | Mandatory   |
| ------------------- | ----------------------------------------------------------------------------------------------- | ----------- |
| Connection string   | The connection string used to connect to the SQL DB.                                            | Yes         |
| Manager type code   | The value for the manager type code. Default is "MGR". Other example: SLR.                      | Yes         |
| Include positions   | Include positions yes/no.                                                                       | No          |
| End date threshold  | The amount of days a contract can be in the past before being excluded from the imported data.  | Yes         |

### Prerequisites
- ODBC driver
- Service account (or SQL account) with permissions to reade the database. The default queries require permission to the following tables:

| Database table            | Description            |
| ------------------------- | ---------------------- |
| dpib004                   | Costcenters table      |
| dpib010                   | Persons table          |
| dpib015                   | Departments table      |
| dpic200                   | Employers table        |
| dpic202                   | Institutions table     |
| dpic300                   | Contracts table        |
| dpic310                   | Positions table        |
| dpic351                   | Professions table      |

### Remarks
 - Currently, we only support up to 2 layers of upper departments.

### Mappings
A basic person and contract mapping is provided. Make sure to further customize these accordingly.

### Scope
The data collection retrieved by the queries is a default set which is sufficient for HelloID to provision persons.
The queries can be changed by the customer itself to meet their requirements.

## Getting help
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/