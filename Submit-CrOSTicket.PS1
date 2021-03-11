<#
.SYNOPSIS
 Submit-CrOSTicket.PS1 Checks Aeries for returned Chromebooks and generates a helpdesk ticket in KACE and
 moves associated devices to the CART OU in Gsuite to apply the 'clear profile' policy.
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

function submitTicket ($deviceResults,[string]$type) {
 begin {Write-Verbose "Submit Tickets - Processing $type"}
 process {
  foreach ($dev in $deviceResults ) {
   # Begin Device Processing
   Write-Debug ( "`n`n============ Process {0} ? ==============`n" -f $dev.'Asset Tag Number' )

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
 
   # This can be used to look up the corresponding helpdesk ticket in KACE
   Write-Verbose ( "{0} - Chromebook Turn-In - {1}" -f $dev.'Site', $dev.'Asset Tag Number' )
 
   # Fill in 'Last Ticket Date' [DRA].[DD] field to prevent duplicate tickets
   $updateDDFields = $dev.'Student ID Number', $dev.rin, $dev.'Date Check-in by Student'
   Add-Log update ( 'DRA.DD (Ticket Date) Updated where ID {0} RIN {1} Check-In Date {2}' -f $updateDDFields  ) -WhatIf:$WhatIf
   $updateDDCommand = ( Get-Content -Path .\sql\update-dd.sql -Raw ) -f $updateDDFields
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
 }
 end {}
 # if ($dev.'Asset Tag Number' -eq 'CB202000024328') { EXIT } # Not sure why this is still here
} # End submitTicket Function

$ENV:GAM_DEVICE_MAX_RESULTS = 100
$gam = '.\lib\gam-64\gam.exe'
$crosFields = "annotatedUser,annotatedAssetId,orgUnitPath,deviceId,status"
$targOU = '/Chromebooks/Cart'

function moveToCart ($deviceResults,[string]$type) {
 # moveToCart function moves all processed devices with a valid devid_id/barcode to the '/Chromebooks/Cart' OU
 begin {Write-Verbose "Move To Cart - Processing $type"}
 process {
  foreach ($dev in $deviceResults) {
   $barCode = $dev.'Asset Tag Number'
   # find the device in gsuite
   ($gamDeviceRaw = .$gam print cros query "asset_id: $barCode" fields $crosFields) *>$null
   # $gamDeviceRaw.count
   if ($gamDeviceRaw.count -eq 2){ # make sure there is 1 header row and exactly 1 result row
    $gamDevice = $gamDeviceRaw | ConvertFrom-Csv
    $id = $gamDevice.deviceId
    if ($id){
     if ($WhatIf){ ".$gam update cros $id ou $targOU"
     } else { .$gam update cros $id ou $targOU }
     Add-Log gsuitemove ('{0},{1} moved to {2}' -f $barCode, $id, $targOU) -WhatIf:$WhatIf
    } else { Add-Log warning ('{0} barcode/Asset Tag device id not set' -f $barCode) }
   } else { 
    Add-Log warning ('{0} barcode/Asset Tag too few or too many results from cros query.Asset Tag Likely not in Gsuite.' -f $barCode) 
   }
   if ($gamDeviceRaw.count -gt 2){
    Add-Log error 'Too many devices returned. Check and reconcile conflicting barcode/Asset Tag assignment in SIS/GSuite'
    $gamDeviceRaw
   }
  } # end foreach dev
 } # end process block
 end {}
}

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
 if ( $newRepairDevices ) {
  # Add-Log info ('New Repair Devices to process: {0}' -f $newRepairDevices.count)
  submitTicket -deviceResults $newRepairDevices -Type newRepairDevices
  moveToCart -deviceResults $newRepairDevices -Type newRepairDevices
 }

 if ( $closedTicketDevices ) {
  # Add-Log info ('Closed Ticket Devices to process: {0}' -f $newRepairDevices.count)
  # submitTicket -deviceResults $closedTicketDevices -type closedTicketDevices  # disabled due to KACE overload
  moveToCart -deviceResults $closedTicketDevices -type closedTicketDevices
 }

 if (!$WhatIf) {
  $waitHours = 1
  Write-Verbose "Next run at $((Get-Date).AddHours($waitHours))."
  Start-Sleep -Seconds (60 * 60)
 }
} until ( $WhatIf -or ((Get-Date) -ge $stopTime) )
# End Do Loop