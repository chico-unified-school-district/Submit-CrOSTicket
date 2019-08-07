SELECT
 [DRA].[SCL] AS [School],
 [DRA].[ID] AS [ID],
 STU.LN + ', ' + STU.FN AS [StudentName],
 [STU].[PEM] AS [ParentEmail],
 CONVERT(VARCHAR(10),[DRA].[DT],101) AS [Date Issued to Students],
 CASE WHEN [DRA].[CC] = 'K' THEN 'Keyboard Malfunction'
      WHEN [DRA].[CC] = 'L' THEN 'LCD'
	  WHEN [DRA].[CC] = 'P' THEN 'Battery'
	  WHEN [DRA].[CC] = 'T' THEN 'TouchPad'
	  WHEN [DRA].[CC] = 'U' THEN 'other'
	  WHEN [DRA].[CC] = 'W' THEN 'Final Check-in w/o Cord'
 ELSE 'NO Condition' END AS [Damage Code], 
 CASE WHEN [DRA].[CD] = 'D' THEN 'Damaged'
      WHEN [DRA].[CD] = 'M' THEN 'Lost'
	  WHEN [DRA].[CD] = 'R' THEN 'Returned (No Damage)'
	  WHEN [DRA].[CD] = 'S' THEN 'Stolen w Police report'
	  WHEN [DRA].[CD] = 'V' THEN 'Recovered/Reactivated'
 ELSE 'No Code' END AS [ReturnCode],
 CONVERT(VARCHAR(10),[DRA].[RD],101) AS [Returned Date],

 [DRA].[DD] as [Last Ticket Date],
 [DRI].[BC] AS Barcode,
 [DRI].[SR] AS SerialNumber,
 [DRA].[CO] AS [Comment],
 
 [DRA].[DTS] AS TimeStamp,
 [DRA].[RIN],
CASE WHEN STU.SC = 1 THEN 'Chico High School'
     WHEN STU.SC = 2 THEN 'Pleasant Valley High School'
     WHEN STU.SC = 3 THEN 'Fair View'
     WHEN STU.SC = 35 THEN 'Inspire School of Arts and Sciences'
     WHEN STU.SC = 10 THEN 'Fair View'
     WHEN STU.SC = 5 THEN 'Bidwell Junior High'
     WHEN STU.SC = 6 THEN 'Chico Junior High'
     WHEN STU.SC = 7 THEN 'Marsh Junior High'
     WHEN STU.SC = 8 THEN 'Academy for Change'
	 WHEN STU.SC = 9 THEN 'Oak Bridge'
     WHEN STU.SC = 11 THEN 'Oakdale'
     WHEN STU.SC = 12 THEN 'Chapman'
     WHEN STU.SC = 13 THEN 'Citrus'
     WHEN STU.SC = 16 THEN 'Hooker Oak'
     WHEN STU.SC = 18 THEN 'McManus'
    WHEN STU.SC = 19 THEN 'Loma Vista'
     WHEN STU.SC = 20 THEN 'Marigold' 
     WHEN STU.SC = 21 THEN 'Neal Dow' 
     WHEN STU.SC = 23 THEN 'Little Chico Creek' 
     WHEN STU.SC = 24 THEN 'Parkview' 
     WHEN STU.SC = 25 THEN 'Emma Wilson' 
     WHEN STU.SC = 26 THEN 'Rosedale' 
     WHEN STU.SC = 27 THEN 'Shasta' 
     WHEN STU.SC = 28 THEN 'Sierra View' 
     WHEN STU.SC = 91 THEN 'Oakdale' 
 ELSE 'District Office' END AS siteAbbr

FROM (SELECT [STU].* FROM STU WHERE DEL = 0)
 STU RIGHT JOIN ((SELECT [DRA].* FROM DRA WHERE DEL = 0)
 DRA LEFT JOIN (SELECT [DRI].* FROM DRI WHERE DEL = 0)
 DRI ON [DRI].[RID] = [DRA].[RID] AND [DRI].[RIN] = [DRA].[RIN]) ON [STU].[ID] = [DRA].[ID]

WHERE
 DRA.DD IS NULL
 AND DRA.CD <> 'R'
 AND DRA.CD <> ' '
 AND DRA.RID = 1

 AND (NOT STU.TG > ' ') AND STU.SC IN ( 1,2,3,5,6,7,8,9,10,11,12,13,16,17,18,19,20,21,23,24,25,26,27,28 )
 AND DRA.RD IS NOT NULL
 AND ( DRA.RD > '2019-8-1' ) -- Older enteries can be ignored
ORDER BY DRA.RD,DRA.DD