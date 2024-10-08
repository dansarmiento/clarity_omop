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

Name: pull_NOTE_HSP_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_NOTE_HSP_2.sql. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[NOTE_ClarityHosp_ALL]
	which will be used later in app_NOTE_HSP_2.sql.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[NOTE_ClarityHosp_ALL] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/
USE EpicCare;

IF EXISTS (
		SELECT NULL
		
		FROM INFORMATION_SCHEMA.TABLES
		
		WHERE TABLE_NAME = 'NOTE_ClarityHosp_ALL'
		)
	DROP TABLE OMOP_Clarity.NOTE_ClarityHosp_ALL;


SELECT DISTINCT --[HNO_INFO].[NOTE_ID]
	SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID)) AS person_id
	,AoU_ID
	,[NOTE_ENC_INFO].[ENTRY_INSTANT_DTTM]
	,ZC_NOTE_TYPE_IP.NAME AS ZC_NOTE_TYPE_IP_NAME
	,ZC_NOTE_TYPE_IP.TYPE_IP_C
	,hno_info.AMB_NOTE_YN
	,PAT_ENC_HSP.PAT_ENC_CSN_ID
	,[NOTE_ENC_INFO].[NOTE_ID]
	,[NOTE_ENC_INFO].CONTACT_DATE_REAL
	,PAT_ENC_HSP.BILL_ATTEND_PROV_ID
	,[HNO_INFO].IP_NOTE_TYPE_C
	,[HNO_NOTE_TEXT].[LINE]
	,[HNO_NOTE_TEXT].[NOTE_CSN_ID]
	,[HNO_NOTE_TEXT].[CONTACT_DATE]
	,[HNO_NOTE_TEXT].[CM_CT_OWNER_ID]
	,[HNO_NOTE_TEXT].[CHRON_ITEM_NUM]
	,[HNO_NOTE_TEXT].[NOTE_TEXT]
	,[HNO_NOTE_TEXT].[IS_ARCHIVED_YN]
	,'NOTE--ClarityHosp--ALL' AS ETL_Module

INTO OMOP_Clarity.NOTE_ClarityHosp_ALL

FROM EpicClarity.dbo.PAT_ENC_HSP

INNER JOIN OMOP.AoU_Driver
	ON PAT_ENC_HSP.PAT_ID = OMOP.AoU_Driver.Epic_Pat_id

INNER JOIN [EpicClarity].[dbo].[HNO_INFO]
	ON hno_info.PAT_ENC_CSN_ID = PAT_ENC_HSP.PAT_ENC_CSN_ID

INNER JOIN [EpicClarity].[dbo].[ZC_NOTE_TYPE_IP]
	ON [HNO_INFO].IP_NOTE_TYPE_C = [ZC_NOTE_TYPE_IP].TYPE_IP_C

INNER JOIN [EpicClarity].[dbo].[NOTE_ENC_INFO]
	ON [HNO_INFO].[NOTE_ID] = [NOTE_ENC_INFO].[NOTE_ID]



INNER JOIN [EpicClarity].[dbo].[HNO_NOTE_TEXT]
	ON [NOTE_ENC_INFO].[NOTE_ID] = [EpicClarity].[dbo].[HNO_NOTE_TEXT].[NOTE_ID]
		AND [NOTE_ENC_INFO].CONTACT_DATE_REAL = [HNO_NOTE_TEXT].CONTACT_DATE_REAL


WHERE [ENTRY_INSTANT_DTTM] IS NOT NULL

