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
 .\Submit-CrOSTicket.PS1 -SISServer mySISServer $SISData mySISDatabse -SISCred $sisCred -EmailCredential $EmailCredential
 .EXAMPLE
 .\Submit-CrOSTicket.PS1 -SISServer mySISServer $SISData mySISDatabse -SISCred $sisCred -EmailCredential $EmailCredential -Verbose -WhatIf -Debug
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
 [System.Management.Automation.PSCredential]$SQLCredential,
 [Parameter(Mandatory = $True)]
 [Alias('MailCred')]
 [System.Management.Automation.PSCredential]$EmailCredential,
 [Parameter(Mandatory = $false)]
 [string]$TicketOwner,
 [Parameter(Mandatory = $True)]
 [string]$TargetAddress,
 [Alias('wi')]
	[SWITCH]$WhatIf
)

Import-Module -Name 'dbatools', 'CommonScriptFunctions'

$sqlParams = @{
 Server     = $SQLServer
 Database   = $SQLDatabase
 Credential = $SQLCredential
}

function submitTicket ($deviceResults, [string]$type) {
 begin { Write-Verbose "Submit Tickets - Processing $type" }
 process {
  foreach ($dev in $deviceResults ) {
   # Special Repair Location for tickets with a Status of 'Closed'
   if ($dev.'Status' -eq 'Closed') {
    $repairLocation = 'No Repair Needed'
   }
   else { $repairLocation = 'Tech Center' }

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
    $TicketOwner                    #12
    $dev.'Damage Code'              #13
    $dev.'Warranty Date'            #14
    $repairLocation                 #15
    $dev.'Comment'                  #16
   )

   # This can be used to look up the corresponding helpdesk ticket in KACE
   Write-Verbose ( "{0} - Chromebook Turn-In - {1}" -f $dev.'Site', $dev.'Asset Tag Number' )

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
   $emailLogVars = $MyInvocation.MyCommand.Name, $dev.'Student ID Number' , $dev.'Asset Tag Number'
   Write-Host ("{0},{1},{2},Helpdesk Ticket Created" -f $emailLogVars ) -F DarkBlue
   if ( $WhatIf ) { $to, $messageBody }
   else { Send-MailMessage @mailParams }

  }  # End Device Processing
 }
} # End submitTicket Function

# $ENV:GAM_DEVICE_MAX_RESULTS = 100
$gam = '.\bin\gam.exe'
$crosFields = "annotatedUser,annotatedAssetId,orgUnitPath,deviceId,status"
$targOU = '/Chromebooks/Cart'

function moveToCart ($deviceResults, [string]$type) {
 # moveToCart function moves all vaild devices with a valid devid_id/barcode to the '/Chromebooks/Cart' OU
 begin { Write-Verbose "Move To Cart - Processing $type" }
 process {
  foreach ($dev in $deviceResults) {
   Write-Debug ( "`n`n============ moveToCart {0} ? ==============`n" -f $dev.'Asset Tag Number' )
   $barCode = $dev.'Asset Tag Number'
   # find the device in gsuite
   ($gamDeviceRaw = .$gam print cros query "asset_id: $barCode" fields $crosFields) *>$null
   # $gamDeviceRaw.count
   if ($gamDeviceRaw.count -eq 2) {
    # make sure there is 1 header row and exactly 1 result row
    $gamDevice = $gamDeviceRaw | ConvertFrom-Csv
    $id = $gamDevice.deviceId
    if ($id) {
     if ($WhatIf) {
      Write-Host ("{0},.$gam update cros $id ou $targOU" -f $MyInvocation.MyCommand.Name) -F DarkCyan
     }
     else {
      # Skip Devices where RID = 6. These need to stay put.
      if ($dev.rid -ne 6) {
       Write-Host ('{0},{1},{2}' -f $MyInvocation.MyCommand.Name, $dev.'Student ID Number' , $barCode, $targOU) -F DarkMagenta
       .$gam update cros $id ou $targOU
      }
     }
    }
    else {
     Write-Host ('{0} barcode/Asset Tag too few or too many results from cros query.Asset Tag Likely not in Gsuite.' -f $barCode)
    }
    if ($gamDeviceRaw.count -gt 2) {
     Write-Host ('{0},Many devices returned. Check and reconcile conflicting barcode/Asset Tag assignment in SIS/GSuite' -f $MyInvocation.MyCommand.Name)
     $gamDeviceRaw
    }
   }
  }
 } # end process block
} # end function moveToCart

function updateDDField  ($deviceResults, [string]$type) {
 begin { Write-Verbose "Update DD Field - Processing $type" }
 Process {
  foreach ($dev in $deviceResults) {
   Write-Debug ( "`n`n============ updateDDField {0} ? ==============`n" -f $dev.'Asset Tag Number' )
   $barCode = $dev.'Asset Tag Number'
   # Fill in 'Last Ticket Date' [DRA].[DD] field to prevent duplicate tickets
   $sqlVars = "id=$($dev.'Student ID Number')", "rin=$($dev.rin)", "rd=$($dev.'Date Check-in by Student')"
   # Write-Host ('{0},DRA.DD (Ticket Date) Updated where ID {0} RIN {1} Check-In Date {2}' -f $MyInvocation.MyCommand.Name)
   Write-Host ('{0},DRA.DD (Ticket Date) Updated where ID {0} RIN {1} Check-In Date {2}' -f $MyInvocation.MyCommand.Name)
   $updateDDSql = Get-Content -Path .\sql\update-dd.sql -Raw
   if (-not$WhatIf) { New-SqlOperation @sqlParams -Query $updateDDSql -Parameters $sqlVars }
  }
 }
} # end function updateDDField

# Processing
if ($WhatIf) { Show-TestRun }
Clear-SessionData

$newRepairQuery = Get-Content -Path '.\sql\new-repair-tickets-2.sql' -Raw
$closedTickerQuery = Get-Content -Path '.\sql\closed-ticket.sql' -Raw
$messageTemplate = Get-Content -Path '.\lib\HelpDesk-Message.txt' -Raw

$stopTime = Get-Date "5:00pm"
"Runs every 60 minutes. Stops at $stopTime."
do {
 # Begin Do Loop

 $newRepairDevices = New-SqlOperation @sqlParams -Query $newRepairQuery
 $closedTicketDevices = New-SqlOperation @sqlParams -Query $closedTickerQuery
 # 'derpins=================='
 #  $newRepairDevices.count

 if ( $newRepairDevices ) {
  Write-Host ('New Repair Devices to process: {0}' -f $newRepairDevices.count)
  submitTicket -deviceResults $newRepairDevices -Type newRepairDevices
  moveToCart -deviceResults $newRepairDevices -Type newRepairDevices
  updateDDField -deviceResults $newRepairDevices -type newRepairDevices # move these into moveToCart function
 }

 if ( $closedTicketDevices ) {
  Write-Host ('Closed Ticket Devices to process: {0}' -f $closedTicketDevices.count)
  # submitTicket disabled for this device entry type due to ticket KACE overload!
  moveToCart -deviceResults $closedTicketDevices -type closedTicketDevices
  updateDDField -deviceResults $closedTicketDevices -type closedTicketDevices# move these into moveToCart function
 }

 if (!$WhatIf) {
  $waitHours = 1
  Write-Host "Next run at $((Get-Date).AddHours($waitHours))."
  Start-Sleep -Seconds (60 * 60)
 }
} until ( $WhatIf -or ((Get-Date) -ge $stopTime) )
# End Do Loop
if ($WhatIf) { Show-TestRun }
Clear-SessionData