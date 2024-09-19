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

Name: pull_condition_occurrence_ICD_HSP_2

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_condition_occurrence_ICD_HSP_2. 

	Its purpose is to query data from Epic Clarity and append this data to CONDITION_OCCURRENCE_ClarityHosp_ICD
	which will be used later in app_condition_occurrence_ICD_HSP_2.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/
USE EpicCare;

IF EXISTS (	SELECT NULL
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'CONDITION_OCCURRENCE_ClarityHosp_ICD')
	DROP TABLE OMOP_Clarity.CONDITION_OCCURRENCE_ClarityHosp_ICD;


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

SELECT DISTINCT 
	SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID)) AS person_id
	,AoU_Driver.AoU_ID
	,PAT_ENC_DX.CONTACT_DATE
	,PAT_ENC_DX.PAT_ENC_CSN_ID
	,PAT_ENC_HSP.[HOSP_DISCH_TIME]
	,[ATTEND_FROM_DATE]
	,[ATTEND_TO_DATE]
	,PRIMARY_DX_YN
	,DISCH_DISP_C
	,HSP_ATND_PROV.PROV_ID

	,T_Diagnosis.icd10_code
	,T_Diagnosis.icd9_code

	--------------------------------------------
	,'pull_CONDITION_OCCURRENCE--ClarityHosp--ICD' AS ETL_Module


INTO OMOP_Clarity.CONDITION_OCCURRENCE_ClarityHosp_ICD

FROM EpicClarity.dbo.PAT_ENC_DX

	INNER JOIN EpicClarity.dbo.PAT_ENC_HSP
		ON PAT_ENC_DX.PAT_ENC_CSN_ID = PAT_ENC_HSP.PAT_ENC_CSN_ID

	LEFT JOIN EpicClarity.dbo.HSP_ATND_PROV
		ON PAT_ENC_HSP.PAT_ENC_CSN_ID = HSP_ATND_PROV.PAT_ENC_CSN_ID
			AND [HOSP_DISCH_TIME] BETWEEN [ATTEND_FROM_DATE]
				AND COALESCE([ATTEND_TO_DATE], GETDATE())

	INNER JOIN OMOP.AoU_Driver
		ON PAT_ENC_DX.PAT_ID = OMOP.AoU_Driver.Epic_Pat_id

	left JOIN T_Diagnosis
		ON PAT_ENC_DX.DX_ID = T_Diagnosis.DX_ID

