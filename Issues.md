## Errors

### Supported Combination

**Issue:** Cannot have EncryptRMSTemplate with anything but Exchange
Set-DlpComplianceRule: |Microsoft.Exchange.Management.UnifiedPolicy.ErrorActionLocationSupportException|Using the 'EncryptRMSTemplate' parameter isn't supported for files in SharePoint or OneDrive. Either remove this
parameter or specify only the 'ExchangeLocation' parameter.

**Solution:** Tool need to have combination checks in planning to cause failure. In this instance have this rule action with a policy that has more than just Exchange should error during the plan stage

---
**Issue:** Keeps trying to update the policy despite all settings being present, this could be due to Device being listed but no property set. this is likely causing it to try an apply an invalid setting on the policy that is marked as incorrect

---
**Issue:** Multiple auths occcur because we disconnect after executing the main commands

**Solution:** Have a dedicated authentication function that does this first, then runs through everything with a single disconnection at the end

---
---
**Issue:** Removing locations from a DLP Policy does nothing, eg you you remove a location ro disable the location in the yaml does not result in this being removed

**Solution:** When running the set-dlpcompliancepolicy there is a number of switches like RemoveExchangeLocation that accepts either ALL or comma separated valued. This will need to look at current configuration, compare against new configuration then in the final set command have both -AddExchangeLocation and -RemoveExchangeLocation with the related items, or in the case of location being disable or enabled weither one set to an All value

Set-DlpCompliancePolicy -AddExchangeLocation 'All' -Priority '0' -Identity 'cb2662e6-fd09-4357-9448-ff3da81b6fe1' -Mode 'Enable' -Comment 'Protects financial data from unauthorized sharing'
