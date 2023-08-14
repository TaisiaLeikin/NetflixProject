ALTER TABLE CovidCountryData
ADD CountryID INT IDENTITY(1, 1)

/*Add column CountryID to NetflixCountries*/

ALTER TABLE NetflixCountries
ADD  CountryID INT 


/*Update column CountryID with data from NetflixCountries*/

UPDATE  NetflixCountries
SET 	 CountryID = C.CountryID
From 	 CovidCountryData C
		join NetflixCountries NC
			on NC.CountryName = C.Country
;

GO
CREATE VIEW NetflixCountriesCovid AS

WITH CTE AS
(
SELECT C.Continent, C.Population, NC.CountryName, CONVERT(VARCHAR(30),CD.Date,3) as DATE ,CD.DailyNewCases, CD.ActiveCases, CD.DailyNewDeaths,
(CASE WHEN C.Continent = 'Asia' THEN 4
			WHEN C.Continent = 'Australia/Oceania' THEN 4
			WHEN C.Continent = 'Europe' THEN 2
			WHEN C.Continent = 'Africa' THEN 2
			WHEN C.Continent = 'North America' THEN
				CASE WHEN NC.CountryName = 'Greenland' THEN 2
				WHEN NC.CountryName NOT IN ('USA', 'Canada') THEN 3
				ELSE 1 END
			WHEN C.Continent = 'South America' THEN 3
			END) as RegionID
FROM NetflixCountries NC
JOIN CovidCountryData C ON NC.CountryName=C.Country 
JOIN CovidDailyData CD ON NC.CountryName=CD.Country
)


SELECT RegionID, CountryName, DATE, DATEPART(Quarter, Date) as Quarter, Year(Date) AS Year, SUM(Population) as SUMPopulation, SUM(DailyNewCases) as SUMDailyNewCases 
,SUM(DailyNewDeaths) AS SUMDailyNewDeaths, ROUND((SUM(DailyNewCases)/SUM(Population) *100), 3)  AS IllnessPCT
FROM CTE
GROUP BY RegionID,  CountryName, DATE, DATEPART(Quarter, Date), Year(Date)

;

GO 

CREATE VIEW NetflixAndCompetitors AS 

WITH CTE AS
(
SELECT CompetitorID, Year, ROUND(SubscribersMillions, 2) AS SubscribersMillions  , ROUND(RevenueBillions, 2) AS RevenueBillions, PremiumPlanPrice FROM Competition


UNION ALL

SELECT SubscribersSum.Year, SubscribersSum.NetflixSubscribers, RevenueSum.NetflixRevenue, NetflixPlans.Price
FROM 
 (SELECT Year, ROUND(SUM(SubscribersQuarterEndM),2) as NetflixSubscribers FROM NetflixRevenueSubscribers WHERE Quarter = 4 GROUP BY Year) AS SubscribersSum JOIN
(SELECT Year, ROUND(SUM(RevenueBillions),2) as NetflixRevenue FROM NetflixRevenueSubscribers GROUP BY Year) AS RevenueSum
 ON SubscribersSum.Year=RevenueSum.Year
 JOIN  (SELECT Year, ROUND(Price,2) as Price FROM NetflixPlanPrices WHERE NetflixPlan = 'Premium') AS NetflixPlans ON RevenueSum.Year = NetflixPlans.Year
)

SELECT ROW_NUMBER() OVER (ORDER BY YEAR) AS ID , *, DENSE_RANK () OVER (PARTITION BY Year ORDER BY RevenueBillions ASC) AS RevenueRank, 
DENSE_RANK() OVER (PARTITION BY Year ORDER BY SubscribersMillions ASC ) AS SubscribersRank, 
DENSE_RANK() OVER (PARTITION BY Year ORDER BY PremiumPlanPrice DESC) AS PriceRank 
FROM CTE  
WHERE Year BETWEEN 2019 AND 2022
 ;

GO


-- delete nullable Price rows from NetflixPlanPrices
DELETE 
FROM	NetflixPlanPrices 
WHERE	Price IS NULL;

-- Netflixcountries -------------------------------------------

-- delete nullable CountryID rows from Netflixcountries
DELETE
FROM	NetflixCountries
WHERE	CountryID IS NULL


-- define CountryID column not nullable
ALTER TABLE NetflixCountries 
ALTER COLUMN CountryID INT NOT NULL;


-- define PK in Netflixcountries table
ALTER TABLE Netflixcountries
ADD CONSTRAINT PK_NetflixCountries_CountryID PRIMARY KEY (CountryID)

-- CovidDailyData -------------------------------------------

-- create ID column with row number 
ALTER TABLE CovidDailyData 
ADD ID INT IDENTITY(1,1) NOT NULL;

-- create PK in CovidDailyData table 
ALTER TABLE CovidDailyData
ADD CONSTRAINT PK_CovidDailyData_ID PRIMARY KEY (ID)

-- NetflixMarketCap -------------------------------------------

-- convert Year to not nullable
ALTER TABLE NetflixMarketCap 
ALTER COLUMN Year INT NOT NULL

-- convert Quarter to not nullable
ALTER TABLE NetflixMarketCap 
ALTER COLUMN Quarter INT NOT NULL;

-- create composite PK to NetflixMarketCap
ALTER TABLE NetflixMarketCap
ADD CONSTRAINT PK_NetflixMarketCap_Year_Quarter PRIMARY KEY (Year, Quarter)


-- NetflixRevenueSubscribers -------------------------------------------

-- add column CompetitorID to NetflixRevenueSubscribers
ALTER TABLE NetflixRevenueSubscribers
ADD CompetitorID INT NOT NULL 
CONSTRAINT NetflixRevenueSubscribers_CompetitorID DEFAULT 7;

-- create FK
ALTER TABLE NetflixRevenueSubscribers
ADD CONSTRAINT FK_NetflixRevenueSubscribers_CompetitorID FOREIGN KEY (CompetitorID)
    REFERENCES Competitors (CompetitorID)

;
--- view to compare revenues of current year to previous year 
GO

CREATE VIEW CompareRevToPreviousYear AS
WITH Totals AS
(
SELECT	Year
		,SUM(RevenueBillions) AS TotalRevenue		
FROM	NetflixRevenueSubscribers
GROUP BY Year
)
SELECT  *
		,LEAD(TotalRevenue) OVER (ORDER BY Year DESC) PreviousYearRevenue
FROM	Totals

;
-------------------------------------------------------------------------------
--- view to compare revenues of current year to same period YTD

;
GO

CREATE OR ALTER   VIEW [dbo].[CompareRevToPreviousQuarter] AS
WITH Totals AS
(
SELECT	Year
		,Quarter
		,SUM(RevenueBillions) * 1000000000 AS TotalRevenue		
FROM	NetflixRevenueSubscribers
GROUP BY Year
		,Quarter
)
, PreviousQuarter AS
(
SELECT  *
		,LAG(TotalRevenue) OVER (ORDER BY Year, Quarter ASC) PreviousQuarterRevenue
FROM	Totals
)
SELECT	a.Year
		,a.Quarter
		,ROUND(a.TotalRevenue, 2) TotalRevenue
		,ROUND(a.PreviousQuarterRevenue, 2) PreviousQuarterRevenue
		,ROUND(b.TotalRevenue, 2) AS YTD
FROM	PreviousQuarter a
		LEFT JOIN PreviousQuarter b 
			ON b.Quarter = a.Quarter
				AND b.Year = a.Year - 1

;
SELECT * FROM  CompareRevToPreviousQuarter
----Descriptive Statistics - The most informative tables

 --Netflix And Competitors
SELECT CS.Name,  ROUND(AVG(NC.RevenueBillions),2) as AvgRevenue, MIN(NC.RevenueBillions) as MinRevenue, MAX(NC.RevenueBillions) as MaxRevenue, ROUND(STDEV(NC.RevenueBillions), 2) as STDRevenue
,  ROUND(AVG(NC.SubscribersMillions),2) as AvgSubscribers, MIN(NC.SubscribersMillions) as MinSubscribers, MAX(NC.SubscribersMillions) as MaxSubscribers, ROUND(STDEV(NC.SubscribersMillions), 2 ) as STDSubscribers
, AVG(NC.PremiumPlanPrice) as AvgPrice, MIN(NC.PremiumPlanPrice) as MinPrice, MAX(NC.PremiumPlanPrice) as MaxPrice , MIN(NC.Year) as MinYear, MAX(NC.Year) as MaxYear
FROM NetflixAndCompetitors NC JOIN Competitors CS ON NC.CompetitorID = CS.CompetitorID
GROUP BY CS.Name

--Netflix Countries Covid

SELECT R.RegionName, COUNT(DISTINCT NCC.CountryName) as CountriesCount
, ROUND(AVG(NCC.SUMPopulation),2) as AvgPopulation, MIN(NCC.SUMPopulation) as MinPopulation , MAX(NCC.SUMPopulation) as MaxPopulation, ROUND(STDEV(NCC.SUMPopulation), 2) as STDPopulation
, ROUND(AVG(NCC.SUMDailyNewCases),2) as AvgDailyNewCases, MIN(NCC.SUMDailyNewCases) as MinDailyNewCases , MAX(NCC.SUMDailyNewCases) as MaxDailyNewCases, ROUND(STDEV(NCC.SUMDailyNewCases), 2) as STDDailyNewCases
, ROUND(AVG(NCC.SUMDailyNewDeaths),2) as AvgDailyNewDeaths, MIN(NCC.SUMDailyNewDeaths) as MinDailyNewDeaths , MAX(NCC.SUMDailyNewDeaths) as MaxDailyNewDeaths, ROUND(STDEV(NCC.SUMDailyNewDeaths), 2) as STDDailyNewDeaths
, Min(Year) as MinYear, MAX(Year) as MaxYear
FROM NetflixCountriesCovid NCC JOIN Regions R ON NCC.RegionID = R.RegionID
GROUP BY R.RegionName


--Netflix Revenue Subscribers

SELECT R.RegionName, MIN(NRS.Year) as MinYear, MAX(NRS.Year) as MaxYear,
ROUND(AVG(NRS.RevenueBillions),2) as AverageRevenue, MIN(NRS.RevenueBillions) as MinRevenue, MAX(NRS.RevenueBillions) as MaxRevenue, ROUND(STDEV(NRS.RevenueBillions),2) as STDRevenue,
ROUND(AVG(NRS.SubscribersQuarterEndM),2) as AverageSubscribers, MIN(NRS.SubscribersQuarterEndM) as MinSubscribers, MAX(NRS.SubscribersQuarterEndM) as MaxSubscribers, ROUND(STDEV(NRS.SubscribersQuarterEndM),2) as STDSubscribers
FROM NetflixRevenueSubscribers NRS JOIN Regions R ON NRS.RegionID=R.RegionID
GROUP BY R.RegionName

--Netflix Market Capital
SELECT Min(Year) as MinYear, MAX(Year) as MaxYear, 
ROUND(AVG(ValueBillions),2) as AverageValue, MIN(ValueBillions) as MinValue, MAX(ValueBillions) as MaxValue, ROUND(STDEV(ValueBillions),2) as STDValue
FROM NetflixMarketCap


--Global Streaming Revenue

SELECT Min(Year) as MinYear, MAX(Year) as MaxYear, 
ROUND(AVG(GlobalStreamingRevenue),2) as AverageGlobalRevenue, MIN(GlobalStreamingRevenue) as MinGlobalRevenue,
MAX(GlobalStreamingRevenue) as MaxGlobalRevenue, ROUND(STDEV(GlobalStreamingRevenue),2) as STDGlobalRevenue
FROM GlobalStreamingRevenue

;
GO
--Creating regional view for covid analysis

CREATE VIEW VW_NetflixRegionsCovid AS

WITH CTE AS
(
SELECT
	C.Continent, 
	C.Population,
	NC.CountryName,
	CONVERT(VARCHAR(30),CD.Date,3) as DATE ,
	CD.DailyNewCases, CD.ActiveCases, CD.DailyNewDeaths,

(CASE WHEN C.Continent = 'Asia' THEN 4
			WHEN C.Continent = 'Australia/Oceania' THEN 4
			WHEN C.Continent = 'Europe' THEN 2
			WHEN C.Continent = 'Africa' THEN 2
			WHEN C.Continent = 'North America' THEN
				CASE WHEN NC.CountryName = 'Greenland' THEN 2
				WHEN NC.CountryName NOT IN ('USA', 'Canada') THEN 3
				ELSE 1 END
			WHEN C.Continent = 'South America' THEN 3
			END) as RegionID
FROM NetflixCountries NC
JOIN CovidCountryData C ON NC.CountryName=C.Country 
JOIN CovidDailyData CD ON NC.CountryName=CD.Country
)


SELECT 
	RegionID, 
	DATEPART(Quarter, Date) as Quarter,
	Year(Date) AS Year, SUM(DISTINCT Population) As SumPopulation,
	SUM(DailyNewCases) as SUMNewCases,
	SUM(DailyNewDeaths) AS SUMNewDeaths,
FROM CTE
GROUP BY RegionID, DATEPART(Quarter, Date), Year(Date)

;

--Creating view for covid and revenue analysis
GO 

CREATE VIEW VW_CovidAndRevenues AS
SELECT  NRC.RegionID, NRC.Quarter, NRC.Year, NRC.SumPopulation as Population, NRC.SUMNewCases as NewCases, NRC.SUMNewDeaths as NewDeaths
, NRS.RevenueBillions as Revenue, NRS.SubscribersQuarterEndM
FROM VW_NetflixRegionsCovid NRC JOIN NetflixRevenueSubscribers NRS ON NRC.RegionID = NRS.RegionID
AND NRC.Year = NRS.Year AND NRC.Quarter = NRS.Quarter



;
--creating view for global analysis vs netflix in years instead quarters
GO

CREATE VIEW VW_NetflixAndGlobalRevenue AS

WITH CTE AS
(
SELECT Year as Year, ROUND(SUM(RevenueBillions),2) As NetflixYearRevenue
FROM NetflixRevenueSubscribers
GROUP BY Year
)

SELECT A.Year,
	A.NetflixYearRevenue,
	GSR.GlobalStreamingRevenue,
	ROUND(A.NetflixYearRevenue/GSR.GlobalStreamingRevenue *100, 2) AS PCTNetflixGlobal,
	ROUND(GSR.GlobalStreamingRevenue-A.NetflixYearRevenue, 2)  AS GlobalRevenueWithoutNetflix
FROM CTE A JOIN GlobalStreamingRevenue GSR 
ON A.Year = GSR.Year


;
GO

CREATE VIEW VW_NetflixRevenueSubscribersNew AS

WITH CTE AS
(
SELECT Year, Quarter, RegionID, 
SubscribersQuarterEndM,
LAG(SubscribersQuarterEndM) OVER (PARTITION BY RegionID ORDER BY Year ASC, Quarter ASC) AS PreviousQuarterSubscribers
FROM NetflixRevenueSubscribers
)

SELECT * , ROUND(SubscribersQuarterEndM - PreviousQuarterSubscribers, 2) AS SubscribersDiffMillions
FROM CTE 
;
GO

ALTER VIEW VW_SumData AS

SELECT Year, SUM(SubscribersQuarterEndM) As YearSubscribers
FROM NetflixRevenueSubscribers
WHERE Quarter = 4
GROUP BY Year


;
































