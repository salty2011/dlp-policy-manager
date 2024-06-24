# DLP Policy Manager

> [!WARNING]
> This is in active development and not ready for use. check back later.

## Overview
The purpose of this powershell module is to provide a declarative means for deploying DLP Policies in Microsoft 365. Conceptually this aims to be like other orchestation tools like terraform etc where you describe your infrastructure in code and it will deploy that.

### Limitations
1. Microsoft provides no API endpoint for Purview Compliance, only the Powershell ExchangeOnlineManagement module exists.

2. The Data Loss Prevention commands in the module are some what unique in their operation

Im sure there will be others are further development continues.

## Getting Started

## Authentication
DPM is heavily reliant on the ExchangeOnlineManagement module witch currently also include all the commandlets from IPPS when Connect-IPPSession is performed.
Because this designed with the view of running within a pipeline DPM is setup specifically to authenticate using non interactive methods. You will need to setup the service principal using the following settings

**Service Principal Setup**
- Permissions: Exchange.ManageAsApp
- Auth: Certificate Based

**Required to Connect**
- AppID
- Azure Organization url (that will be the onmicrosoft.com address for your tenant)
- Cert Thumbprint to Auth

## Backlog

- [ ] Complete core functions setup
- [ ] Review licensing
- [ ] Validation checks for yml https://github.com/salty2011/dlp-policy-manager/issues/1
- [ ] Add pester tests https://github.com/salty2011/dlp-policy-manager/issues/3