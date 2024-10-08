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

Name: pull_NOTE_ANES_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_NOTE_ANES_2.sql. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[NOTE_ClarityANES_ALL]
	which will be used later in app_NOTE_ANES_2.sql.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[NOTE_ClarityANES_ALL] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;
 
IF EXISTS (
		SELECT NULL
		
		FROM INFORMATION_SCHEMA.TABLES
		
		WHERE TABLE_NAME = 'NOTE_ClarityANES_ALL'
		)
	DROP TABLE OMOP_Clarity.NOTE_ClarityANES_ALL;


SELECT  SUBSTRING(AoU_Driver.AoU_ID, 2, LEN(AoU_Driver.AoU_ID)) AS person_id
	,AoU_Driver.AoU_ID
	,PAT_ENC_AMB.PAT_ID
	-----hospital encounter---------
	,pat_enc_hsp.PAT_ENC_CSN_ID
	--------------------------------
	,PAT_ENC_AMB.HSP_ACCOUNT_ID
	,PAT_ENC_AMB.IP_DOC_CONTACT_CSN
	,PAT_ENC_AMB.ENC_TYPE_C
	,PAT_ENC_AMB.ZC_DISP_ENC_TYPE_NAME
	,PAT_ENC_AMB.pat_or_adm_link_csn as pat_or_adm_link_PAT_ENC_CSN_ID
	,[NOTE_ENC_INFO].[ENTRY_INSTANT_DTTM]
	,ZC_NOTE_TYPE_IP.NAME AS ZC_NOTE_TYPE_IP_NAME
	,ZC_NOTE_TYPE_IP.TYPE_IP_C
	,hno_info.AMB_NOTE_YN
	,[NOTE_ENC_INFO].[NOTE_ID]
	,[NOTE_ENC_INFO].CONTACT_DATE_REAL
	,PAT_ENC_AMB.visit_PROV_ID
	,[HNO_INFO].IP_NOTE_TYPE_C
	,[HNO_NOTE_TEXT].[LINE]
	,[HNO_NOTE_TEXT].[NOTE_CSN_ID]
	,[HNO_NOTE_TEXT].[CONTACT_DATE]
	,[HNO_NOTE_TEXT].[CM_CT_OWNER_ID]
	,[HNO_NOTE_TEXT].[CHRON_ITEM_NUM]
	,[HNO_NOTE_TEXT].[NOTE_TEXT]
	,[HNO_NOTE_TEXT].[IS_ARCHIVED_YN]
	,'NOTE--ClarityANES--ALL' AS ETL_Module

INTO OMOP_Clarity.NOTE_ClarityANES_ALL

FROM EpicCare.OMOP.AoU_Driver

INNER JOIN OMOP_Clarity.VISIT_OCCURRENCE_ClarityAMB_ALL AS PAT_ENC_AMB
	ON AoU_Driver.Epic_Pat_id = PAT_ENC_AMB.PAT_ID

-- associates anethesia EVENT to hospital encounter
  INNER JOIN [EpicClarity].[dbo].[F_AN_RECORD_SUMMARY] on PAT_ENC_AMB.pat_enc_csn_id = [F_AN_RECORD_SUMMARY].[AN_53_ENC_CSN_ID]
  inner join [EpicClarity].[dbo].[AN_HSB_LINK_INFO] on [F_AN_RECORD_SUMMARY].AN_EPISODE_ID=[AN_HSB_LINK_INFO].SUMMARY_BLOCK_ID
  inner join [EpicClarity].[dbo].pat_enc_hsp on [AN_HSB_LINK_INFO].[AN_BILLING_CSN_ID]=pat_enc_hsp.pat_enc_csn_id

  
INNER JOIN [EpicClarity].[dbo].[HNO_INFO]
	ON  PAT_ENC_AMB.PAT_ENC_CSN_ID= hno_info.PAT_ENC_CSN_ID

INNER JOIN [EpicClarity].[dbo].[ZC_NOTE_TYPE_IP]
	ON [HNO_INFO].IP_NOTE_TYPE_C = [ZC_NOTE_TYPE_IP].TYPE_IP_C

INNER JOIN [EpicClarity].[dbo].[NOTE_ENC_INFO]
	ON [HNO_INFO].[NOTE_ID] = [NOTE_ENC_INFO].[NOTE_ID]

INNER JOIN [EpicClarity].[dbo].[HNO_NOTE_TEXT]
	ON [NOTE_ENC_INFO].[NOTE_ID] = [EpicClarity].[dbo].[HNO_NOTE_TEXT].[NOTE_ID]
		AND [NOTE_ENC_INFO].CONTACT_DATE_REAL = [HNO_NOTE_TEXT].CONTACT_DATE_REAL

WHERE
	PAT_ENC_AMB.ENC_TYPE_C = 53 -- Anesthesia EVENT

