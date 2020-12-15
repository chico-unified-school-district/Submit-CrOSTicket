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
 [Parameter(Mandatory = $false)]
 [string]$DefaultOwner,
 [Parameter(Mandatory = $True)]
 [string]$TargetAddress,
	[SWITCH]$WhatIf
)

# Imported Functions
. .\lib\Add-Log.ps1 # Format Log entries
. .\lib\Invoke-SqlCommand.ps1 # Useful function for querying SQL and returning results
. .\lib\Select-Site.ps1

# Processing
$newRepairQuery = Get-Content -Path '.\sql\new-repair-tickets-2.sql' -Raw
$closedTickerQuery = Get-Content -Path '.\sql\closed-ticket.sql' -Raw
$messageTemplate = Get-Content -Path '.\lib\HelpDesk-Message.txt' -Raw

$stopTime = Get-Date "5:00pm"
"Runs every 60 minutes. Stops at $stopTime."
do {
 # Begin Do Loop
 $newRepairDevices = Invoke-SqlCommand -Server $SQLServer -Database $SQLDatabase -Cred $SISCredential -Query $newRepairQuery
 $closedTicketDevices = Invoke-SqlCommand -Server $SQLServer -Database $SQLDatabase -Cred $SISCredential -Query $closedTickerQuery

 $allDevices = $null
 $allDevices = $newRepairDevices+$closedTicketDevices
 if ($allDevices) {  Add-Log info ('Devices to process: {0}' -f  $allDevices.count) }

 foreach ($dev in $allDevices ) {
  # Begin Device Processing
  Write-Debug ( "`nProcess {0} ?" -f $dev.'Asset Tag Number' )
  # Write-Host ($dev | Out-String) -ForegroundColor Blue

  # Special Repair Location for tickets with a Status of 'Closed'
  if ($dev.'Status' -eq 'Closed') { $repairLocation = 'No Repair Needed'
  } else { $repairLocation = 'Tech Center' }

  # $messageData #'s correspond to the format operator placeholders in HelpDesk-Message.txt
  $messageData = @(
   $dev.'Asset Tag Number'         # 0
   $dev.'Status'                   # 1
   $dev.'Condition'                # 2
   $dev.'site'                     # 3
   $dev.'Student ID Number'        # 4
   $dev.'Student Name'             # 5
   $dev.'Repair Count'             # 6
   $dev.'Parent Email'             # 7
   $dev.'Date Issued to Student'   # 8
   $dev.'Date Check-in by Student' # 9
   $dev.'Device Model'             #10
   $dev.'Category'                 #11
   $DefaultOwner                   #12
   $dev.'Damage Code'              #13
   $dev.'Warranty Date'            #14
   $repairLocation                 #15
   $dev.'Comment'                  #16
  )

  # This can be used to look up the corresponding helpdesk ticket in KACE.
  Write-Verbose ( "{0} - Chromebook Turn-In - {1}" -f $dev.'Site', $dev.'Asset Tag Number' )
  
  # Fill in 'Last Ticket Date' [DRA].[DD] field to prevent duplicate tickets
  Add-Log update ( '{0} {1} {2}' -f $dev.'Student ID Number', $dev.rin, $dev.'Date Check-in by Student' )
  $updateDDCommand = ( Get-Content -Path .\sql\update-dd.sql -Raw ) -f $dev.'Student ID Number', $dev.rin, $dev.'Date Check-in by Student'
  Invoke-SqlCommand -Server $SQLServer -Database $SQLDatabase -Cred $SISCredential -SqlCommand $updateDDCommand -WhatIf:$WhatIf
  
  $mailParams = @{
   To         = ('<{0}>' -f $TargetAddress)
   # Bcc = '<testing@company.com>'
   From       = $EmailCredential.Username # a no reply account works bext
   Subject    = ( "{0} - Chromebook Turn-In - {1}" -f $dev.'Student ID Number', $dev.'Asset Tag Number')
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

 }  # End Device Processing

 if (!$WhatIf) {
  Write-Verbose "Next run at $((Get-Date).AddHours(1))."
  Start-Sleep -Seconds (60 * 60)
 }
} until ( $WhatIf -or ((Get-Date) -ge $stopTime) )
# End Do Loop