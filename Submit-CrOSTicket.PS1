<#
.SYNOPSIS
 Submit-CrOSTicket.PS1 Checks Aeries for returned Chromebooks and generates a helpdesk ticket in KACE
.DESCRIPTION
 Query Aeries, generate a formatted email body and subject, send this data to the KACE helpdesk system
.PARAMETER SISCOnnection
 A string containing a database server name and database name in the format 'ServerName\DatabaseName'
.PARAMETER SISCredential
 A credential object with permissions to Aeries Database(s)
.PARAMETER EmailCredential
 A credential object with permissions to send an email to the KACE helpdesk system
.PARAMETER WhatIf
 Switch to turn testing mode on or off.
.EXAMPLE
 .\Submit-CrOSTicket.PS1 -SISConn $sisConn -SISCred $sisCred -EmailCredential $EmailCredential
 .EXAMPLE
 .\Submit-CrOSTicket.PS1 -SISConn $sisConn -SISCred $sisCred -EmailCredential $EmailCredential -Verbose -WhatIf -Debug
.INPUTS
 A string containing a database server name and database name in the format 'ServerName\DatabaseName'
 A credential object with permissions to Aeries Database(s)
 A credential object with permissions to send an email to the KACE helpdesk system
.OUTPUTS
 Log messages are output to the console.

 Helpdesk tickets are created via KACE's email api.

 Aeries database fields are updated to prevent duplicate ticket creation in KACE.
.NOTES
 Tag number standardized at 14 characters. This may change in the future.
#>
#Requires -Version 5.0

[cmdletbinding()]
param (
 # SQL server name
 [Parameter(Mandatory = $True)]
 [Alias('SISServer')]
 [string]$SQLServer,
 # SQL database name
 [Parameter(Mandatory = $True)]
 [Alias('SISDatabase', 'SISDB')]
 [string]$SQLDatabase,
 # Aeries SQL user account with SELECT permission to STU table 
 [Parameter(Mandatory = $True)]
 [Alias('SISCred')]
 [System.Management.Automation.PSCredential]$SISCredential,
 [Parameter(Mandatory = $True)]
 [Alias('MailCred')]
 [System.Management.Automation.PSCredential]$EmailCredential,
 [Parameter(Mandatory = $True)]
 [string]$TargetAddress,
	[SWITCH]$WhatIf
)

# Imported Functions
. .\lib\Add-Log.ps1 # Format Log entries
. .\lib\Invoke-SqlCommand.ps1 # Useful function for querying SQL and returning results
. .\lib\Select-Site.ps1

# Processing
$sisQuery = Get-Content -Path .\sql\query-checked-in-devices.sql -Raw
$messageTemplate = Get-Content -Path .\lib\HelpDesk-Message.txt -Raw

$stopTime = Get-Date "5:00pm"
"Runs every 60 minutes. Stops at $stopTime."
do {
 # Begin Do Loop
 $checkInCrOSDevices = Invoke-SqlCommand -Server $SQLServer -Database $SQLDatabase -Cred $SISCredential -Query $sisQuery
 foreach ($dev in $checkInCrOSDevices) {
  # Begin Device Processing
  Write-Debug ( "Process {0} ?" -f $dev.'Asset Tag Number' )
  # $messageData #'s correspond to the format operator placeholders in HelpDesk-Message.txt
  $messageData = @(
   $dev.'Asset Tag Number'
   $dev.'Status'
   $dev.'Condition'
   $dev.'site'
   $dev.'Student ID Number'
   $dev.'Student Name'
   $dev.'Repair Count'
   $dev.'Parent Email'
   $dev.'Date Issued to Student'
   $dev.'Date Check-in by Student'
   $dev.'Device Model'
   $dev.'Category'
   $dev.'Owner'
   $dev.'Comment'
  )

  # This can be used to look up the corresponding helpdesk ticket in KACE.
  Write-Verbose ( "{0} - Chromebook Turn-In - {1}" -f $dev.'Site', $dev.'Asset Tag Number' )

  $mailParams = @{
   # To         = '<servicedesk@kbox1.chicousd.org>'
   To         = ('<{0}>' -f $TargetAddress)
   # Bcc = '<jcooper@chicousd.org>'
   From       = $EmailCredential.Username # no-reply@chicousd.org
   Subject    = ( "{0} - Chromebook Turn-In - {1}" -f $dev.siteAbbr, $dev.Barcode)
   BodyAsHtml = $false
   Body       = ( $messageBody = $messageTemplate -f $messageData )
   SMTPServer = 'smtp.office365.com'
   Cred       = $EmailCredential
   UseSSL     = $True
   Port       = 587
  }
  
  Add-Log email ("{0},Helpdesk Ticket Created" -f $dev.'Asset Tag Number' ) -WhatIf:$WhatIf
  if ( $WhatIf ) { $to, $messageBody }
  else { Send-MailMessage @mailParams }

  # Add-Log update ( "{0},{1},{2},DRA 'Last Ticket Date' set" -f $dev.id,$dev.rin,$dev.Returned )
  $updateDDCommand = ( Get-Content -Path .\sql\update-dd.sql -Raw ) -f $dev.id, $dev.rin, $dev.Returned
  Invoke-SqlCommand -Server $SQLServer -Database $SQLDatabase -Cred $SISCredential -SqlCommand $updateDDCommand -WhatIf:$WhatIf

 }  # End Device Processing

 if (!$WhatIf) {
  Write-Verbose "Next run at $((Get-Date).AddHours(1))."
  Start-Sleep -Seconds (60 * 60)
 }
} until ( $WhatIf -or ((Get-Date) -ge $stopTime) )
# End Do Loop