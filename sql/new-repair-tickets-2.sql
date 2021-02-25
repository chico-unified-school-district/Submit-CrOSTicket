SELECT
  -- KACE Asset Tag/Barcode
  -- Asset Tag Number = Barcode
  [DRI].[BC] AS [Asset Tag Number],
  -- KACE Status
  'New' AS [STATUS],
  -- Condition
  CASE WHEN [DRA].[CD] = 'D' THEN 'Damaged'
  WHEN [DRA].[CD] = 'M' THEN 'Lost'
  WHEN [DRA].[CD] = 'R' THEN 'No Hardware Damage' 
  WHEN [DRA].[CD] = 'S' THEN 'Stolen w Police report'
  WHEN [DRA].[CD] = 'V' THEN 'Recovered/Reactivated'
  WHEN [DRA].[CD] = 'W' THEN 'No Hardware Damage'
 ELSE 'No Hardware Damage' END AS [Condition],
  -- KACE Site
  CASE 
  WHEN STU.SC = 1 THEN 'Chico High School'
  WHEN STU.SC = 2 THEN 'Pleasant Valley High School'
  WHEN STU.SC = 3 THEN 'Fair View'
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
 ELSE 'District Office' END AS Site,
  -- KACE Student ID Number
  [DRA].[ID] AS [Student ID Number],
  -- KACE Student Name
  STU.LN + ', ' + STU.FN AS [Student Name],
  -- KACE Warranty Date
  CONVERT(VARCHAR(10),[DRI].[RM],101) AS [Warranty Date],
  -- KACE REPAIR COUNT LOGIC HERE
  1 AS [Repair Count],
  --
  -- KACE Parent Email
  [STU].[PEM] AS [Parent Email],
  -- KACE Date Issued to Student
  [DRA].[DT] AS [Date Issued to Student],
  -- KACE Damage Code
  CASE 
  
  WHEN [DRA].[CC] = 'E' THEN 'Keycap Missing'
  WHEN [DRA].[CC] = 'K' THEN 'Keyboard Malfunction'
  WHEN [DRA].[CC] = 'L' THEN 'LCD Cracked'
  WHEN [DRA].[CC] = 'N' THEN 'LCD Display'
  WHEN [DRA].[CC] = 'O' THEN 'Wi-Fi'
  WHEN [DRA].[CC] = 'P' THEN 'Battery'
  WHEN [DRA].[CC] = 'Q' THEN 'Liquid Damage'
  WHEN [DRA].[CC] = 'S' THEN 'Power Port'
  WHEN [DRA].[CC] = 'T' THEN 'TouchPad'
  WHEN [DRA].[CC] = 'U' THEN 'other'
  WHEN [DRA].[CC] = 'V' THEN 'Sound Issues'
  WHEN [DRA].[CC] = 'X' THEN 'Microphone'
  WHEN [DRA].[CC] = 'Y' THEN 'Camera'
 ELSE 'NO Condition' END AS [Damage Code],
  --  KACE Date Check-in by Student
  CONVERT(VARCHAR(10),[DRA].[RD],101) AS [Date Check-in by Student],
  -- KACE Category
  'Chromebook 1:1'AS [Category],
  -- KACE Device Model
  CASE
    WHEN [DRI].[WH] = 'G5' THEN 'HP G5'
    WHEN [DRI].[WH] = 'G6' THEN 'HP G6'
    WHEN [DRI].[WH] = 'G7' THEN 'HP G7'
    ELSE ' ' END AS [Device Model],
  -- KACE Owner
  --'samAccountName' AS [Owner],
  -- KACE Comment
  [DRA].[CO] AS [Comment],
  -- Other Data
  [STU].[SEM] AS [Student Email],
  [DRA].[DD] as [Last Ticket Date],
  [DRI].[SR] AS [SerialNumber],
  [DRA].[DTS] AS TimeStamp,
  [DRA].[RIN]

FROM (SELECT [STU].*
  FROM STU
  WHERE DEL = 0)
 STU RIGHT JOIN ((SELECT [DRA].*
  FROM DRA
  WHERE DEL = 0)
 DRA LEFT JOIN (SELECT [DRI].*
  FROM DRI
  WHERE DEL = 0)
 DRI ON [DRI].[RID] = [DRA].[RID] AND [DRI].[RIN] = [DRA].[RIN]) ON [STU].[ID] = [DRA].[ID]

WHERE
 --DRI.BC = 'CB201800014887' AND STU.ID = 12345    AND
 (DRA.CC IN ( 'E', 'K','L','N','O','P','Q','S','T','U', 'V', 'X', 'Y' )    or DRA.CD in ('D')) AND
 DRA.DD IS NULL      AND
 
 DRA.RID IN (1,3,6)
  AND (NOT STU.TG > ' ') AND STU.SC IN ( 1,2,3,5,6,7,8,9,10,11,12,13,16,17,18,19,20,21,23,24,25,26,27,28,91 )
  AND DRA.RD IS NOT NULL
  AND ( DRA.RD > '2020-12-14' )
-- Older enteries can be ignored
ORDER BY DRA.RD,DRA.DD