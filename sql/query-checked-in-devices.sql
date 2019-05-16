SELECT
 [DRA].[SCL] AS [School],
 [DRA].[ID] AS [ID],
 STU.LN + ', ' + STU.FN AS [StudentName],
 [STU].[SEM] AS [StuEmail],
 CONVERT(VARCHAR(10),[DRA].[DT],101) AS [Issued],
 CASE WHEN [DRA].[CC] = 'A' THEN 'A - Excellent'
      WHEN [DRA].[CC] = 'B' THEN 'B - Good'
	  WHEN [DRA].[CC] = 'C' THEN 'C - Fair'
	  WHEN [DRA].[CC] = 'M' THEN 'M - Lost/Missing'
	  WHEN [DRA].[CC] = 'S' THEN 'S - Stolen (Need Police Report)'
	  WHEN [DRA].[CC] = 'Z' THEN 'Z - Beyond Repair'
 ELSE 'To Be Decided' END AS [Condition], 
 CASE WHEN [DRA].[CD] = 'L' THEN 'L - Loaner Return'
      WHEN [DRA].[CD] = 'N' THEN 'N - No Protection Plan'
	  WHEN [DRA].[CD] = 'P' THEN 'P - 1st Protection Plan Replace'
	  WHEN [DRA].[CD] = 'R' THEN 'R - Returned (No Damage)'
	  WHEN [DRA].[CD] = 'U' THEN 'U - 2nd Protection Plan Replace'
	  WHEN [DRA].[CD] = 'V' THEN 'V - 3rd Protection Plan Replace'
	  WHEN [DRA].[CD] = 'W' THEN 'W - Warranty Replace'
	  WHEN [DRA].[CD] = 'X' THEN 'X - Other'
 ELSE 'Reason Not Specified' END AS [ReturnCode],
 CONVERT(VARCHAR(10),[DRA].[RD],101) AS [Returned],
 [DRA].[DD] as [Last Ticket Date],
 [DRI].[BC] AS Barcode,
 [DRI].[SR] AS SerialNumber,
 [DRI].[MAC] AS MACAddress,
 [DRA].[CO] AS [Comment],
 CASE WHEN [STU].[U6] = 'Y' THEN 'Yes' 
 ELSE 'No' END AS [ProtectionPlan],
 [DRA].[DTS] AS TimeStamp,
 [DRA].[RIN],
CASE WHEN STU.SC = 1 THEN 'CS'
     WHEN STU.SC = 2 THEN 'PV'
     WHEN STU.SC = 3 THEN 'FV'
     WHEN STU.SC = 35 THEN 'IC'
     WHEN STU.SC = 10 THEN 'FV'
     WHEN STU.SC = 5 THEN 'BJ'
     WHEN STU.SC = 6 THEN 'CJ'
     WHEN STU.SC = 7 THEN 'MJ'
     WHEN STU.SC = 8 THEN 'AFC'
	    WHEN STU.SC = 9 THEN 'OB'
     WHEN STU.SC = 11 THEN 'OK'
     WHEN STU.SC = 12 THEN 'CH'
     WHEN STU.SC = 13 THEN 'CI'
     WHEN STU.SC = 16 THEN 'HO'
     WHEN STU.SC = 18 THEN 'JM'
     WHEN STU.SC = 19 THEN 'LV' 
     WHEN STU.SC = 20 THEN 'MA' 
     WHEN STU.SC = 21 THEN 'ND' 
     WHEN STU.SC = 23 THEN 'LCC' 
     WHEN STU.SC = 24 THEN 'PA' 
     WHEN STU.SC = 25 THEN 'EW' 
     WHEN STU.SC = 26 THEN 'RO' 
     WHEN STU.SC = 27 THEN 'SH' 
     WHEN STU.SC = 28 THEN 'SV' 
     WHEN STU.SC = 91 THEN 'OK' 
 ELSE 'DO' END AS siteAbbr

FROM (SELECT [STU].* FROM STU WHERE DEL = 0)
 STU RIGHT JOIN ((SELECT [DRA].* FROM DRA WHERE DEL = 0)
 DRA LEFT JOIN (SELECT [DRI].* FROM DRI WHERE DEL = 0)
 DRI ON [DRI].[RID] = [DRA].[RID] AND [DRI].[RIN] = [DRA].[RIN]) ON [STU].[ID] = [DRA].[ID]

WHERE
 DRA.DD IS NULL
 AND DRA.CD <> 'R' 
 AND DRA.RID = 1
 AND DRA.CD <> 'L'
 AND (NOT STU.TG > ' ') AND STU.SC IN ( 1,2,3,5,6,7,8,9,10,11,12,13,16,17,18,19,20,21,23,24,25,26,27,28 )
 AND DRA.RD IS NOT NULL
 AND ( DRA.RD > '2019-4-1' ) -- Older enteries can be ignored
ORDER BY DRA.RD,DRA.DD;