USE [BusinessAnalysis]
GO
------------------------------------------------------------------------------
--Drop and create all the tables and constraints used to split bundled music and merch items and get their weighted price
-----------------------------------------------------------------------------



DROP TABLE [dbo].[BUNDLE]
GO

CREATE TABLE [dbo].[BUNDLE](
	[BUNDLE_ID] [int] IDENTITY(1,1) NOT NULL,
	[BUNDLE_UPC] [varchar](255) NULL,
	[BUNDLE_VARIANT] [varchar](255) NULL,
	[BUNDLE_SIZE] [varchar](255) NULL,
	[BUNDLE_NAME] [varchar](255) NULL,
	[BUNDLE_DIST_ID] [int] NULL,
	[BUNDLE_PRICE] [float] NULL
) ON [PRIMARY]
GO



ALTER TABLE [dbo].[BUNDLE_ARCHIVE] DROP CONSTRAINT [DF__BUNDLE_AR__CREAT__5D21AF45]
GO

ALTER TABLE [dbo].[BUNDLE_ARCHIVE] DROP CONSTRAINT [DF__BUNDLE_AR__CREAT__5C2D8B0C]
GO

ALTER TABLE [dbo].[BUNDLE_ARCHIVE] DROP CONSTRAINT [DF__BUNDLE_AR__ACCOU__5B3966D3]
GO

DROP TABLE [dbo].[BUNDLE_ARCHIVE]
GO


CREATE TABLE [dbo].[BUNDLE_ARCHIVE](
	[RECORDSEQ] [int] NULL,
	[DISTRIBUTORID] [int] NULL,
	[FORMATTYPEID] [int] NULL,
	[FILEDATE] [date] NULL,
	[PRODUCT_ID] [varchar](255) NULL,
	[VARIANT_ID] [varchar](255) NULL,
	[VARIANT_TYPE] [varchar](255) NULL,
	[DESCRIPTION] [varchar](255) NULL,
	[AMOUNT] [numeric](18, 4) NULL,
	[AMOUNTUSD] [numeric](18, 4) NULL,
	[QUANTITY] [int] NULL,
	[ACCOUNTNAME] [varchar](255) NULL,
	[CREATEDATE] [datetime] NULL,
	[CREATEUSER] [varchar](255) NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[BUNDLE_ARCHIVE] ADD  DEFAULT ('N/A') FOR [ACCOUNTNAME]
GO

ALTER TABLE [dbo].[BUNDLE_ARCHIVE] ADD  DEFAULT (getdate()) FOR [CREATEDATE]
GO

ALTER TABLE [dbo].[BUNDLE_ARCHIVE] ADD  DEFAULT (user_name()) FOR [CREATEUSER]
GO

USE [BusinessAnalysis]
GO

ALTER TABLE [dbo].[BUNDLE_DISTRIBUTOR] DROP CONSTRAINT [DF__BUNDLE_DI__BUNDL__4B02FF0A]
GO

DROP TABLE [dbo].[BUNDLE_DISTRIBUTOR]
GO


CREATE TABLE [dbo].[BUNDLE_DISTRIBUTOR](
	[BUNDLE_DIST_ID] [int] NULL,
	[BUNDLE_ID] [int] NULL,
	[BUNDLE_DIST_NAME] [varchar](255) NULL,
	[BUNDLE_DIST_ACCT] [varchar](255) NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[BUNDLE_DISTRIBUTOR] ADD  DEFAULT ('N/A') FOR [BUNDLE_DIST_ACCT]
GO

USE [BusinessAnalysis]
GO

/****** Object:  Table [dbo].[BUNDLE_ITEM]    Script Date: 1/25/2020 9:54:15 AM ******/
DROP TABLE [dbo].[BUNDLE_ITEM]
GO

/****** Object:  Table [dbo].[BUNDLE_ITEM]    Script Date: 1/25/2020 9:54:15 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BUNDLE_ITEM](
	[BUNDLE_ITEM_ID] [int] IDENTITY(1,1) NOT NULL,
	[BUNDLE_ITEM_UPC] [varchar](255) NULL,
	[BUNDLE_ITEM_NAME] [varchar](255) NULL,
	[BUNDLE_ID] [int] NULL,
	[BUNDLE_ITEM_PRICE] [float] NULL
) ON [PRIMARY]
GO





------------------------------------------------------------------------------
-- Create all the views used to split bundled music and merch items and get their weighted price
-----------------------------------------------------------------------------



GO
USE [BusinessAnalysis]
GO



CREATE VIEW [dbo].[BUNDLE_ITEM_TOTALS]

AS

SELECT
	I.BUNDLE_ID BUNDLE_ID
	,B.BUNDLE_UPC BUNDLE_UPC
	,SUM(BUNDLE_ITEM_PRICE) ITEM_TOTAL
FROM
	BUNDLE_ITEM I 
	JOIN BUNDLE B ON I.BUNDLE_ID = B.BUNDLE_ID
GROUP BY
	I.BUNDLE_ID
	,B.BUNDLE_UPC
GO


GO
USE [BusinessAnalysis]
GO



CREATE VIEW [dbo].[BUNDLE_LINES]

AS

SELECT 
	T.BUNDLE_UPC
	,BUNDLE_ITEM_UPC
	,BUNDLE_ITEM_NAME
	,BUNDLE_PRICE
	,BUNDLE_ITEM_PRICE
	,BUNDLE_ITEM_PRICE/ITEM_TOTAL AS BUNDLE_WEIGHT
	,(BUNDLE_ITEM_PRICE/ITEM_TOTAL) * BUNDLE_PRICE AS BUNDLE_LINE_PRICE
FROM
	BUNDLE B
	JOIN BUNDLE_ITEM I ON B.BUNDLE_ID = I.BUNDLE_ID 
	JOIN BUNDLE_DISTRIBUTOR D ON D.BUNDLE_ID = B.BUNDLE_ID
	JOIN BUNDLE_ITEM_TOTALS T ON B.BUNDLE_ID = T.BUNDLE_ID
GO


------------------------------------------------------------------------------
--Create the procedure used to split bundled music and merch items and get their weighted price
-----------------------------------------------------------------------------



GO
USE [BusinessAnalysis]
GO



CREATE PROCEDURE [dbo].[BREAKOUT_BUNDLES]
(
@FILEDATE DATE
,@ACCOUNT VARCHAR(255)
--,@DISTRIBUTORID INT
--,@FORMATTYPEID INT
--,@TABLE VARCHAR(255)
--,@WHSE VARCHAR(3)
)

AS

--ARCHIVE AND PUT BUNDLE LINES INTO TEMP TABLE
	INSERT INTO BUNDLE_ARCHIVE
	(
		RECORDSEQ 		 
		,DISTRIBUTORID 	 
		,FORMATTYPEID 	 
		,FILEDATE 		 
		,PRODUCT_ID      
		,VARIANT_ID		 
		,VARIANT_TYPE	 
		,DESCRIPTION     
		,AMOUNT 		 
		,AMOUNTUSD 		 
		,QUANTITY 		 
		,ACCOUNTNAME     
	)
	SELECT
		ODS.recordSeq
		,207
		,1
		,ODS.filedate
		,ODS.product_id 
		,ODS.variant_id
		,ODS.variant_title
		,ODS.product_title
		,ODS.net_sales 
		,ODS.net_sales
		,ODS.net_quantity
		,ODS.AccountName
	FROM 
		ODS.DBO.Shopify ODS
	WHERE 
		FILEDATE = @FILEDATE 
		AND ACCOUNTNAME = @ACCOUNT
		AND PRODUCT_TITLE LIKE '%BUNDLE%'
		AND variant_title IS NOT NULL
 

--TEMP TABLE
	IF OBJECT_ID('tempdb.dbo.#ODS_BUNDLES', 'U') IS NOT NULL
	DROP TABLE #ODS_BUNDLES;

	SELECT * INTO 
		#ODS_BUNDLES
	FROM 
		ODS.DBO.Shopify ODS
	WHERE 
		FILEDATE = @FILEDATE 
		AND ACCOUNTNAME = @ACCOUNT
		AND PRODUCT_TITLE LIKE '%BUNDLE%'
		AND variant_title IS NOT NULL


--ADD IN NEW ROWS WITH ITEMS AND PRORATED PRICES


	INSERT INTO ODS.dbo.Shopify 
           SELECT
		   [filedate]					 = OB.filedate--				
           ,[AccountName]				 = OB.AccountName--			
           ,[day]						 = OB.day--					
           ,[adjustment]				 = OB.adjustment--			
           ,[cancelled]					 = OB.cancelled--				
           ,[financial_status]			 = OB.financial_status--	
           ,[fulfillment_status]		 = OB.fulfillment_status--	
           ,[order_id]					 = OB.order_id--				
           ,[order_name]				 = OB.order_name--			
           ,[sale_kind]					 = OB.sale_kind	--			
           ,[sale_line_type]			 = OB.sale_line_type--		
           ,[billing_city]				 = OB.billing_city--		
           ,[billing_company]			 = OB.billing_company--		
           ,[billing_region]			 = OB.billing_region--		
           ,[billing_country]			 = OB.billing_country--		
           ,[product_id]				 = OB.product_id--			
           ,[product_price]				 = BL.BUNDLE_ITEM_PRICE			
           ,[product_title]				 = BL.BUNDLE_ITEM_NAME			
           ,[product_type]				 = OB.product_type		
           ,[product_vendor]			 = OB.product_vendor		
           ,[variant_id]				 = BL.BUNDLE_ITEM_UPC			
           ,[variant_sku]				 = OB.variant_sku			
           ,[variant_title]				 = OB.variant_title			
           ,[shipping_city]				 = OB.shipping_city			
           ,[shipping_region]			 = OB.shipping_region		
           ,[shipping_country]			 = OB.shipping_country		
           ,[referrer_host]				 = OB.referrer_host			
           ,[referrer_name]				 = OB.referrer_name			
           ,[referrer_path]				 = OB.referrer_path			
           ,[referrer_source]			 = OB.referrer_source		
           ,[referrer_url]				 = OB.referrer_url			
           ,[total_sales]				 = BL.BUNDLE_ITEM_PRICE			
           ,[discounts]					 = OB.discounts				
           ,[gross_sales]				 = BL.BUNDLE_ITEM_PRICE			
           ,[net_sales]					 = BL.BUNDLE_ITEM_PRICE				
           ,[orders]					 = OB.orders				
           ,[returns]					 = OB.returns				
           ,[shipping]					 = OB.shipping				
           ,[taxes]						 = OB.taxes					
           ,[net_quantity]				 = OB.net_quantity			
           ,[ordered_item_quantity]		 = OB.ordered_item_quantity	
           ,[returned_item_quantity]	 = OB.returned_item_quantity
           ,[fix_upc]					 = BL.BUNDLE_ITEM_UPC			
           ,[distributorid]				 = OB.distributorid			
           ,[createDate]				 = OB.createDate			
           ,[createUser]				 = OB.createUser			
           ,[jobnumber]					 = OB.jobnumber				
           ,[formattypeid]				 = OB.formattypeid			
           ,[countryid]					 = OB.countryid				
           ,[albumid]					 = OB.albumid				
           ,[new_variant_sku]			 = OB.new_variant_sku
	--select * 
	FROM 
		#ODS_BUNDLES OB
		LEFT JOIN BUNDLE_LINES BL
		ON OB.product_id = BL.BUNDLE_UPC
	WHERE
		FILEDATE = @FILEDATE 
		AND ACCOUNTNAME = @ACCOUNT


--DELETE BUNDLE ROWS IF ARCHIVED
	DELETE FROM ODS.DBO.SHOPIFY
	WHERE RECORDSEQ IN 
		(SELECT RECORDSEQ
		FROM #ODS_BUNDLES)
	AND FILEDATE = @FILEDATE 
	AND ACCOUNTNAME = @ACCOUNT
	AND PRODUCT_TITLE LIKE '%BUNDLE%'
	AND variant_title IS NOT NULL
		

SELECT * FROM #ODS_BUNDLES	


--TODO

/*
USE BusinessAnalysis
GO

CREATE PROCEDURE BREAKOUT_BUNDLES(
@FILEDATE DATE
@DISTRIBUTORID INT
@FORMATTYPEID INT
@TABLE VARCHAR(255)
@ACCOUNT VARCHAR(255)
@WHSE VARCHAR(3)
)

AS

CREATE TABLE BUNDLE_DISTRIBUTOR(
	BUNDLE_DIST_ID INT
	,BUNDLE_ID INT
	,BUNDLE_DIST_NAME VARCHAR (255)
	,BUNDLE_DIST_ACCT VARCHAR (255) DEFAULT ('N/A')
)

insert into BUNDLE_DISTRIBUTOR
(BUNDLE_DIST_ID 
,BUNDLE_ID 
,BUNDLE_DIST_NAME 
,BUNDLE_DIST_ACCT)
values ( 207, 1, 'SHOPIFY', 'VARESE')    


DROP TABLE DBO.BUNDLE
CREATE TABLE BUNDLE(
	BUNDLE_ID INT IDENTITY(1,1)
	,BUNDLE_UPC VARCHAR (255)
	,BUNDLE_VARIANT VARCHAR (255)
	,BUNDLE_SIZE VARCHAR (255)
	,BUNDLE_NAME VARCHAR (255)
	,BUNDLE_DIST_ID INT
	,BUNDLE_PRICE FLOAT)
)

INSERT INTO BUNDLE
	(BUNDLE_UPC
	,BUNDLE_VARIANT
	,BUNDLE_SIZE
	,BUNDLE_NAME
	,BUNDLE_DIST_ID 
	,BUNDLE_PRICE)
VALUES
	('1732905074786'
	,'16126033526882'
	,'XL'
	,'Varèse Sarabande: 40 Years of Great Film Music 1978-2018 (CD Bundle)'
	,207
	,19.98)


recordSeq	filedate	AccountName	day	adjustment	cancelled	financial_status	fulfillment_status	order_id	order_name	sale_kind	sale_line_type	billing_city	billing_company	billing_region	billing_country	product_id	product_price	product_title	product_type	product_vendor	variant_id	variant_sku	variant_title	shipping_city	shipping_region	shipping_country	referrer_host	referrer_name	referrer_path	referrer_source	referrer_url	total_sales	discounts	gross_sales	net_sales	orders	returns	shipping	taxes	net_quantity	ordered_item_quantity	returned_item_quantity	fix_upc	distributorid	createDate	createUser	jobnumber	formattypeid	countryid	albumid	new_variant_sku
238414	2019-11-15	Varese	2019-11-05 00:00:00.000	No	No	paid	fulfilled	1851480604770	VS44085	order	product	Malden	NULL	Massachusetts	United States	1732905074786	19.98	Varèse Sarabande: 40 Years of Great Film Music 1978-2018 (CD Bundle)	Release	Varѐse Sarabande	16126033526882	NULL	XL	Malden	Massachusetts	United States	NULL	NULL	NULL	Direct	NULL	19.98	0	19.98	19.98	1	0	0	0	1	1	0	NULL	NULL	2019-12-02 14:48:49.620	CONCORD\kevqua	NULL	NULL	NULL	NULL	NULL

CREATE TABLE BUNDLE_ITEM(
	BUNDLE_ITEM_ID INT IDENTITY(1,1)
	,BUNDLE_ITEM_UPC VARCHAR (255)
	,BUNDLE_ITEM_NAME VARCHAR (255)
	,BUNDLE_ID INT
	,BUNDLE_ITEM_PRICE FLOAT
)

BEGIN TRAN
INSERT INTO BUNDLE_ITEM
	(BUNDLE_ITEM_UPC 
	,BUNDLE_ITEM_NAME 
	,BUNDLE_ID 
	,BUNDLE_ITEM_PRICE)
VALUES
	 ('888072062993', 'Varèse Sarabande: 40 Years of Great Film Music 1978-2018 (CD Bundle)-CD	', 1, 	7.5)
	,('888072082519', 'Varèse Sarabande: 40 Years of Great Film Music 1978-2018 (CD Bundle)-Tee XL',	1, 	5.423064067)
	,('888072082540', 'Varèse Sarabande: 40 Years of Great Film Music 1978-2018 (CD Bundle)-Bag',	1, 	3.232980501)
	,('888072082571', 'Varèse Sarabande: 40 Years of Great Film Music 1978-2018 (CD Bundle)-Pin Set',	1, 	3.823955432)

COMMIT TRAN

SELECT * FROM BUNDLE_ITEM	

DROP TABLE BUNDLE_ARCHIVE
CREATE TABLE BUNDLE_ARCHIVE(
	RECORDSEQ INT
	,DISTRIBUTORID INT
	,FORMATTYPEID INT
	,FILEDATE DATE
	,PRODUCT_ID VARCHAR(255)
	,VARIANT_ID VARCHAR(255)
	,VARIANT_TYPE VARCHAR(255)
	,DESCRIPTION VARCHAR(255)
	,AMOUNT NUMERIC(18, 4) 
	,AMOUNTUSD NUMERIC(18, 4)
	,QUANTITY INT
	,ACCOUNTNAME VARCHAR (255) DEFAULT ('N/A')
	,CREATEDATE DATETIME DEFAULT (GETDATE())
	,CREATEUSER VARCHAR(255) DEFAULT (CURRENT_USER)
)

SELECT * FROM BUNDLE_ARCHIVE

INSERT INTO BUNDLE_ARCHIVE
(
	RECORDSEQ 		 
	,DISTRIBUTORID 	 
	,FORMATTYPEID 	 
	,FILEDATE 		 
	,PRODUCT_ID      
	,VARIANT_ID		 
	,VARIANT_TYPE	 
	,DESCRIPTION     
	,AMOUNT 		 
	,AMOUNTUSD 		 
	,QUANTITY 		 
	,ACCOUNTNAME     
)
SELECT
	ODS.recordSeq
	,207
	,1
	,'2019-11-15'
	,ODS.product_id 
	,ODS.variant_id
	,ODS.variant_title
	,ODS.product_title
	,ODS.net_sales 
	,ODS.net_sales
	,ODS.net_quantity
	,ODS.AccountName
FROM 
	ODS.DBO.Shopify ODS
WHERE 
	FILEDATE = '2019-11-15' 
	AND ACCOUNTNAME = 'VARESE'
	AND PRODUCT_TITLE LIKE '%BUNDLE%'
	AND variant_title IS NOT NULL


recordSeq	filedate	AccountName	day						adjustment	cancelled	financial_status	fulfillment_status	order_id			order_name		sale_kind	sale_line_type	billing_city	billing_company	billing_region	billing_country	product_id		product_price	product_title															product_type	product_vendor		variant_id		variant_sku	variant_title	shipping_city	shipping_region	shipping_country	referrer_host	referrer_name	referrer_path	referrer_source	referrer_url	total_sales	discounts	gross_sales	net_sales	orders	returns	shipping	taxes	net_quantity	ordered_item_quantity	returned_item_quantity	fix_upc	distributorid	createDate				createUser		jobnumber	formattypeid	countryid	albumid	new_variant_sku
238414	2019-11-15	Varese		2019-11-05 00:00:00.000	No			No			paid				fulfilled			1851480604770		VS44085			order		product			Malden			NULL			Massachusetts	United States	1732905074786	19.98			Varèse Sarabande: 40 Years of Great Film Music 1978-2018 (CD Bundle)	Release			Varѐse Sarabande	16126033526882	NULL		XL				Malden			Massachusetts	United States		NULL			NULL			NULL			Direct			NULL			19.98		0			19.98		19.98		1		0		0			0		1				1						0						NULL	NULL			2019-12-02 14:48:49.620	CONCORD\kevqua	NULL		NULL			NULL		NULL	NULL
	


CREATE VIEW BUNDLE_ITEM_TOTALS

AS

SELECT
	I.BUNDLE_ID BUNDLE_ID
	,B.BUNDLE_UPC BUNDLE_UPC
	,SUM(BUNDLE_ITEM_PRICE) ITEM_TOTAL
FROM
	BUNDLE_ITEM I 
	JOIN BUNDLE B ON I.BUNDLE_ID = B.BUNDLE_ID
GROUP BY
	I.BUNDLE_ID
	,B.BUNDLE_UPC


GO 

ALTER VIEW BUNDLE_LINES

AS

SELECT 
	T.BUNDLE_UPC
	,BUNDLE_ITEM_UPC
	,BUNDLE_ITEM_NAME
	,BUNDLE_PRICE
	,BUNDLE_ITEM_PRICE
	,BUNDLE_ITEM_PRICE/ITEM_TOTAL AS BUNDLE_WEIGHT
	,(BUNDLE_ITEM_PRICE/ITEM_TOTAL) * BUNDLE_PRICE AS BUNDLE_LINE_PRICE
FROM
	BUNDLE B
	JOIN BUNDLE_ITEM I ON B.BUNDLE_ID = I.BUNDLE_ID 
	JOIN BUNDLE_DISTRIBUTOR D ON D.BUNDLE_ID = B.BUNDLE_ID
	JOIN BUNDLE_ITEM_TOTALS T ON B.BUNDLE_ID = T.BUNDLE_ID

*/





