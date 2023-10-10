
--- Sales Table ---

with CostTable as (
select 
PPCH.ProductID, 
PPCH.StandardCost, 
StartDate,
ISNULL(EndDate,getdate()) as 'NewEndDate'
from [Production].[ProductCostHistory] as PPCH)

,ListPriceTable as (
select
PPLP.ProductID,
ListPrice,
StartDate,
isnull(EndDate,GETDATE()) as 'AmendedEndDate'
from Production.ProductListPriceHistory as PPLP)

select
SSOH.SalesOrderID,
SalesOrderDetailID,
CustomerID,
OrderDate,
OrderQty,
SSOD.ProductID,
ssod.UnitPrice,
ssod.UnitPriceDiscount,
(select StandardCost 
from CostTable 
where SSOD.ProductID = ProductID and OrderDate between StartDate and NewEndDate) as StandardCost,
(select ListPrice 
from ListPriceTable 
where SSOD.ProductID = ProductID and OrderDate between StartDate and AmendedEndDate) as ListPrice,
(select StandardCost 
from CostTable 
where SSOD.ProductID = ProductID and OrderDate between StartDate and NewEndDate) * OrderQty as TotalCost,
SSOD.LineTotal as Revenue,
SSOD.LineTotal - ((select StandardCost 
from CostTable 
where SSOD.ProductID = ProductID and OrderDate between StartDate and NewEndDate) * OrderQty) as Profit,
PP.[Name],
convert(varchar(4), YEAR(SSOH.OrderDate)) + '-Q' + convert(varchar(4), datepart(quarter, SSOH.OrderDate)) as YearQuarter,
year(ssoh.OrderDate) as OrderYear,
format(ssoh.OrderDate,'yyyy-MM') as YearMonth,
sst.[Name] as Region, 
sst.[Group] as Continent,
ppsc.[Name] as SubCategory,
ppc.[Name] as Category,
	case
		when [OnlineOrderFlag] = 0 then 'Reseller'
		else 'Online'
	end as Channel
from Sales.SalesOrderDetail as SSOD
inner join Sales.SalesOrderHeader as SSOH
on SSOD.SalesOrderID = SSOH.SalesOrderID
left join Production.Product as PP
on PP.ProductID = SSOD.ProductID
left join [Sales].[SalesTerritory] as SST
on SST.TerritoryID = SSOH.TerritoryID
inner join Production.ProductSubcategory as PPSC
on PPSC.ProductSubcategoryID = PP.ProductSubcategoryID
inner join Production.ProductCategory as PPC
on PPC.ProductCategoryID = PPSC.ProductCategoryID


 --- Cusomer Table ---

 select
ssoh.CustomerID,
SSOH.SalesOrderID,
SSOH.SubTotal,
ssoh.OnlineOrderFlag,
ssoh.OrderDate,
CX.*,
	case
		when [HouseOwnerFlag] = 1 then 'Yes'
		else 'No'
	end as HouseOwner
from AdventureWorks2019.Sales.SalesOrderHeader as SSOH
left join AdventureWorksDW2019.dbo.DimCustomer as CX
on SSOH.CustomerID = CX.CustomerKey
where SSOH.OnlineOrderFlag = 1


 --- Work Order Table ---
select 
PP.ProductID,
PP.[Name] as ProductName,
PSC.[Name] as ProductSubCategory,
SR.[Name] as ScrapReason,
PP.DaysToManufacture,
WO.StartDate,
WO.EndDate,
WO.DueDate,
PL.[Name],
WOR.PlannedCost,
WOR.ActualCost,
datediff(day,WO.DueDate,WO.EndDate) as Delay,
year(WO.DueDate) as OrderYear,
	case
		when datediff(day,WO.DueDate,WO.EndDate) <= 0 then 'On Time'
		when datediff(day,WO.DueDate,WO.EndDate) < 5 then 'Low'
		when datediff(day,WO.DueDate,WO.EndDate) < 9 then 'Medium'
		when datediff(day,WO.DueDate,WO.EndDate) < 17 then 'High'
		else 'Critical'
	end as DelayGroup
from [Production].[Product] as PP
inner join [Production].[WorkOrder] as WO
on pp.ProductID = wo.ProductID
left join [Production].[ProductSubcategory] as PSC
on PP.ProductSubcategoryID = PSC.ProductSubcategoryID
left join [Production].[ScrapReason] as SR
on WO.ScrapReasonID = SR.ScrapReasonID
left join [Production].[WorkOrderRouting] as WOR
on WO.WorkOrderID = WOR.WorkOrderID
left join [Production].[Location] as PL
on WOR.LocationID = PL.LocationID


  --- Location Cost Table ---
select PL.Name,year(WR.ScheduledStartDate) as OrderYear,WR.PlannedCost,wr.ActualCost
from [Production].[WorkOrderRouting] as WR
left join [Production].[Location] as PL
on WR.LocationID = PL.LocationID
group by PL.Name


 --- Freight Table ---
select 
distinct poh.PurchaseOrderID,sm.[Name] as ShipMethod, 
poh.Freight as Freight, 
year(OrderDate) as ShipYear
from [Purchasing].[PurchaseOrderHeader] as poh
inner join [Purchasing].[PurchaseOrderDetail] as pod
on poh.PurchaseOrderID = pod.PurchaseOrderID
left join [Purchasing].[ShipMethod] as sm
on poh.ShipMethodID = sm.ShipMethodID
order by poh.PurchaseOrderID


 --- Rejected % ---
 select 
sum(ReceivedQty) as TotalReceived, 
sum(RejectedQty) as TotalRejected, 
(sum(RejectedQty) / sum(ReceivedQty)) * 100 as PercentageRejected
from Purchasing.PurchaseOrderDetail