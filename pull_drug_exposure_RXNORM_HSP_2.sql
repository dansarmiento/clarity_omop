/*******************************************************************************
# Copyright 2020 Spectrum Health 
# http://www.spectrumhealth.org
#
# Unless required by applicable law or agreed to in writing, this software
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
# either express or implied.
#
********************************************************************************/

/*******************************************************************************

Name: pull_drug_exposure_RXNORM_HSP_2

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_drug_exposure_RXNORM_HSP_2.sql. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[DRUG_EXPOSURE_ClarityHosp_RXNORM]
	which will be used later in app_drug_exposure_RXNORM_HSP_2.sql.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[DRUG_EXPOSURE_ClarityHosp_RXNORM] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;

IF EXISTS (
		SELECT NULL
		
		FROM INFORMATION_SCHEMA.TABLES
		
		WHERE TABLE_NAME = 'DRUG_EXPOSURE_ClarityHosp_RXNORM'
		)
	DROP TABLE OMOP_Clarity.DRUG_EXPOSURE_ClarityHosp_RXNORM;


SELECT DISTINCT SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID)) AS person_id
	,AoU_ID
	,PAT_ENC_HSP.PAT_ENC_CSN_ID
	,ORDER_MED.AUTHRZING_PROV_ID
	,ORDER_END_TIME
	,ORDER_START_TIME
	,[RXNORM_CODES].[RXNORM_CODE]
	,[RXNORM_CODES].[RXNORM_TERM_TYPE_C]
	,ZC_RXNORM_TERM_TYPE.NAME AS ZC_RXNORM_TERM_TYPE_name
	,END_DATE
	,ORDER_MED.RSN_FOR_DISCON_C
	,ZC_RSN_FOR_DISCON.NAME AS ZC_RSN_FOR_DISCON_name
	,REFILLS
	,QUANTITY
	,ZC_MED_UNIT.[NAME] AS ZC_MED_UNIT_NAME
	,[MAR_ADMIN_INFO].[SIG]
	,[MAR_ADMIN_INFO].LINE AS MAR_ADMIN_INFO_LINE
	,EDITED_LINE
	,MAR_ACTION_C
	,REASON_C
	,MAR_ENC_CSN
	,[MAR_ADMIN_INFO].[ORDER_MED_ID]
	,CLARITY_MEDICATION.medication_ID
	,CLARITY_MEDICATION.NAME AS CLARITY_MEDICATION_NAME
	,ORDER_MED.[MED_ROUTE_C]
	,ZC_ADMIN_ROUTE.NAME AS ZC_ADMIN_ROUTE_NAME
	,ORDER_STATUS_C
	,'DRUG_EXPOSURE--ClarityHosp--RXNORM' AS ETL_Module

INTO OMOP_Clarity.DRUG_EXPOSURE_ClarityHosp_RXNORM
FROM EpicCare.OMOP.AoU_Driver

INNER JOIN EpicClarity.dbo.PAT_ENC_HSP
	ON AoU_Driver.Epic_Pat_id = PAT_ENC_HSP.PAT_ID

INNER JOIN [EpicClarity].[dbo].[ORDER_MED]
	ON ORDER_MED.PAT_ENC_CSN_ID = PAT_ENC_HSP.PAT_ENC_CSN_ID

INNER JOIN [EpicClarity].[dbo].CLARITY_MEDICATION
	ON ORDER_MED.[MEDICATION_ID] = CLARITY_MEDICATION.[MEDICATION_ID]

INNER JOIN [EpicClarity].[dbo].[MAR_ADMIN_INFO]
	ON [ORDER_MED].[ORDER_MED_ID] = [MAR_ADMIN_INFO].[ORDER_MED_ID]

INNER JOIN [EpicClarity].[dbo].[ZC_MED_UNIT]
	ON ORDER_MED.HV_DOSE_UNIT_C = ZC_MED_UNIT.[DISP_QTYUNIT_C]

LEFT JOIN [EpicClarity].[dbo].ZC_RSN_FOR_DISCON
	ON ORDER_MED.RSN_FOR_DISCON_C = ZC_RSN_FOR_DISCON.RSN_FOR_DISCON_C

LEFT JOIN omop.provider
	ON ORDER_MED.AUTHRZING_PROV_ID = provider.[provider_source_value]

LEFT JOIN [EpicClarity].[dbo].ZC_ADMIN_ROUTE
	ON ORDER_MED.MED_ROUTE_C = ZC_ADMIN_ROUTE.MED_ROUTE_C

INNER JOIN [EpicClarity].[dbo].[RXNORM_CODES]
	ON ORDER_MED.MEDICATION_ID = [RXNORM_CODES].MEDICATION_ID

INNER JOIN [EpicClarity].[dbo].ZC_RXNORM_TERM_TYPE
	ON [RXNORM_CODES].[RXNORM_TERM_TYPE_C] = ZC_RXNORM_TERM_TYPE.RXNORM_TERM_TYPE_C

WHERE [START_DATE] IS NOT NULL
	--AND ZC_RXNORM_TERM_TYPE.[RXNORM_TERM_TYPE_C] <> 2 --2 - Precise Ingredient
	AND ORDER_STATUS_C NOT IN (
		4 --4 - CANCELED
		,6 --6 - HOLDING
		,7 --7 - DENIED
		,8 --8 - SUSPEND
		,9 --9 - DISCONTINUED
		)
	AND MAR_ACTION_C NOT IN (
		2 --2 - Missed
		,4 --4 - Canceled Entry
		,8 --8 - Stopped
		,15 --15 - See Alternative
		)

GO

/****** Object:  Index [NonClusteredIndex-20200320-105821]    Script Date: 3/20/2020 11:02:11 AM ******/
CREATE NONCLUSTERED INDEX [NonClusteredIndex-medication_ID] ON [OMOP_Clarity].[DRUG_EXPOSURE_ClarityHosp_RXNORM]
(
	[medication_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 85) ON [PRIMARY]
GO

/****** Object:  Index [NonClusteredIndex-20200320-110137]    Script Date: 3/20/2020 11:02:46 AM ******/
CREATE NONCLUSTERED INDEX [NonClusteredIndex-MAR_ADMIN_INFO_LINE] ON [OMOP_Clarity].[DRUG_EXPOSURE_ClarityHosp_RXNORM]
(
	[MAR_ADMIN_INFO_LINE] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 85) ON [PRIMARY]
GO