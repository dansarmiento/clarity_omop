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

Name: pull_condition_occurrence_ICD_AMB_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_condition_occurrence_ICD_AMB_2.sql. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[CONDITION_OCCURRENCE_ClarityAMB_ICD]
	which will be used later in app_condition_occurrence_ICD_AMB_2.sql.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[CONDITION_OCCURRENCE_ClarityAMB_ICD] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;


IF EXISTS (
		SELECT NULL
		
		FROM INFORMATION_SCHEMA.TABLES
		
		WHERE TABLE_NAME = 'CONDITION_OCCURRENCE_ClarityAMB_ICD'
		)
	DROP TABLE OMOP_Clarity.CONDITION_OCCURRENCE_ClarityAMB_ICD;

WITH T_Diagnosis
AS (
	SELECT DISTINCT CLARITY_EDG.DX_ID
		,CLARITY_EDG.DX_NAME
		,[EDG_CURRENT_ICD10].code AS icd10_code
		,[EDG_CURRENT_ICD9].code AS icd9_code
	
	FROM [EpicClarity].[dbo].CLARITY_EDG
	
		LEFT JOIN [EpicClarity].[dbo].[EDG_CURRENT_ICD10]
			ON CLARITY_EDG.DX_ID = [EDG_CURRENT_ICD10].DX_ID
		
		LEFT JOIN [EpicClarity].[dbo].[EDG_CURRENT_ICD9]
			ON CLARITY_EDG.DX_ID = [EDG_CURRENT_ICD9].DX_ID
	)

SELECT DISTINCT SUBSTRING(AoU_Driver.AoU_ID, 2, LEN(AoU_Driver.AoU_ID)) AS person_id
	,AoU_Driver.AoU_ID
	,PAT_ENC_AMB.PAT_ID
	,PAT_ENC_AMB.PAT_ENC_CSN_ID
	,PAT_ENC_AMB.HSP_ACCOUNT_ID


	,PAT_ENC_AMB.IP_DOC_CONTACT_CSN
	,PAT_ENC_AMB.ENC_TYPE_C
	,PAT_ENC_AMB.ZC_DISP_ENC_TYPE_NAME
	,PAT_ENC_AMB.pat_or_adm_link_csn as pat_or_adm_link_PAT_ENC_CSN_ID
	,PAT_ENC_AMB.CONTACT_DATE
	,PAT_ENC_AMB.VISIT_PROV_ID
	,PRIMARY_DX_YN
	,T_Diagnosis.DX_ID
	,T_Diagnosis.DX_NAME
	,T_Diagnosis.icd10_code
	,T_Diagnosis.icd9_code
	,'CONDITION_OCCURRENCE_ClarityAMB_ICD' AS ETL_Module

INTO OMOP_Clarity.CONDITION_OCCURRENCE_ClarityAMB_ICD

FROM

EpicCare.OMOP.AoU_Driver

INNER JOIN OMOP_Clarity.VISIT_OCCURRENCE_ClarityAMB_ALL AS PAT_ENC_AMB
	ON AoU_Driver.Epic_Pat_id = PAT_ENC_AMB.PAT_ID

 	INNER JOIN EpicClarity.dbo.PAT_ENC_DX

		ON PAT_ENC_AMB.PAT_ENC_CSN_ID = PAT_ENC_DX.PAT_ENC_CSN_ID

	INNER JOIN T_Diagnosis
		ON PAT_ENC_DX.DX_ID = T_Diagnosis.DX_ID

WHERE PAT_ENC_AMB.ENC_TYPE_C <> 3