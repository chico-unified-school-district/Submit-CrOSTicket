function Select-Site ($siteAbbreviation) {
 # siteAbbreviation needs to be set to all UPPER CASE 
 # for switch regex to work properly
 $site = $siteAbbreviation.ToUpper()
 switch -Regex ($site) {
  'SH|FV|JM|BJ|AFC|OK' {'emontes'} # Zone A
  'PV|MA|LV|SV' {'htort'} # Zone B
  'CS|EW|RO' {'mdeir'} # Zone C
  'CJ|CI|CH|ND|HO' {'tyler.ward'} # Zone D
  'MJ|LC|PA|OB|DO|CY' {'ADossantos'} # Zone E
  default {'Computer Techs Team'}
 }
}