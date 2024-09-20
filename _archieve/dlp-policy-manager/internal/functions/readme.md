# Internal > Functions
All functions here are used internal to the powershell module and are not directly exposed

## Check-Requirements
Performs a check of required modules listed in requirements.txt and advised if anything is missing

|Switch|Description|
|------|-----------|
|RequirementsFilePath|Path to the requirements.txt|
|InstallMissing|Any modules not present will be installed|

The format of the requirements.txt is as follows

```text
ExchangeOnlineManagement=>3.9.0
powershell-yaml=0.40.7
```
**Syntax**: ModuleName{Operator}Version

|Operator|Description|
|--------|-----------|
| =      | Must be the specified version|
| =>     | Must be equal or greater than version|
| =<     | Must be equal or less than version|