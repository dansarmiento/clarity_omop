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

Name: pull_observation_ICD_SNOMED_HSP_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_observation_ICD_SNOMED_HSP_2.sql. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[OBSERVATION_ClarityHosp_SNOMED_ICD]
	which will be used later in app_observation_ICD_SNOMED_HSP_2.sql.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[OBSERVATION_ClarityHosp_SNOMED_ICD] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;
IF EXISTS (
		SELECT NULL
		
		FROM INFORMATION_SCHEMA.TABLES
		
		WHERE TABLE_NAME = 'OBSERVATION_ClarityHosp_SNOMED_ICD'
		)
	DROP TABLE OMOP_Clarity.OBSERVATION_ClarityHosp_SNOMED_ICD;


WITH T_SNO_CODE
AS (
	SELECT DISTINCT CLARITY_EDG.DX_ID
		,CLARITY_EDG.DX_NAME
		,replace([SNOMED_CONCEPT].[CONCEPT_ID], 'SNOMED#', '') AS SNOMED_code
		,SNOMED_CONCEPT.FULLY_SPECIFIED_NM
		,[EDG_CURRENT_ICD10].code AS icd10_code
		,[EDG_CURRENT_ICD9].code AS icd9_code
	
	FROM [EpicClarity].[dbo].CLARITY_EDG
	
		LEFT JOIN [EpicClarity].[dbo].[EDG_CURRENT_ICD10]
			ON CLARITY_EDG.DX_ID = [EDG_CURRENT_ICD10].DX_ID
		
		LEFT JOIN [EpicClarity].[dbo].[EDG_CURRENT_ICD9]
			ON CLARITY_EDG.DX_ID = [EDG_CURRENT_ICD9].DX_ID
		
		LEFT JOIN [EpicClarity].[dbo].EXTERNAL_CNCPT_MAP
			ON CLARITY_EDG.DX_ID = EXTERNAL_CNCPT_MAP.ENTITY_VALUE_NUM
		
		LEFT JOIN [EpicClarity].[dbo].CONCEPT_MAPPED
			ON EXTERNAL_CNCPT_MAP.MAPPING_ID = CONCEPT_MAPPED.MAPPING_ID
		
		LEFT JOIN [EpicClarity].[dbo].SNOMED_CONCEPT
			ON CONCEPT_MAPPED.CONCEPT_ID = SNOMED_CONCEPT.CONCEPT_ID
	
	WHERE (
			EXTERNAL_CNCPT_MAP.ENTITY_INI = 'EDG'
			AND EXTERNAL_CNCPT_MAP.ENTITY_ITEM = 0.1
			)
	)

SELECT DISTINCT SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID)) AS person_id
	,AoU_ID
	,PAT_ENC_DX.CONTACT_DATE
	,PAT_ENC_DX.PAT_ENC_CSN_ID
	,T_SNO_CODE.DX_ID
	,T_SNO_CODE.DX_NAME
	,T_SNO_CODE.SNOMED_code
	,T_SNO_CODE.FULLY_SPECIFIED_NM
	,T_SNO_CODE.icd10_code
	,T_SNO_CODE.icd9_code
	,PAT_ENC_HSP.BILL_ATTEND_PROV_ID
	,'OBSERVATION--ClarityHosp--SNOMED_ICD' AS ETL_Module

INTO OMOP_Clarity.OBSERVATION_ClarityHosp_SNOMED_ICD

FROM EpicClarity.dbo.PAT_ENC_DX

	INNER JOIN EpicClarity.dbo.PAT_ENC_HSP
		ON PAT_ENC_DX.PAT_ENC_CSN_ID = PAT_ENC_HSP.PAT_ENC_CSN_ID

		LEFT JOIN EpicClarity.dbo.HSP_ATND_PROV
		ON PAT_ENC_HSP.PAT_ENC_CSN_ID = HSP_ATND_PROV.PAT_ENC_CSN_ID
			AND [HOSP_DISCH_TIME] BETWEEN [ATTEND_FROM_DATE]
				AND COALESCE([ATTEND_TO_DATE], GETDATE())

	INNER JOIN OMOP.AoU_Driver
		ON PAT_ENC_DX.PAT_ID = OMOP.AoU_Driver.Epic_Pat_id

	--------Concept Mapping--------------------
	INNER JOIN T_SNO_CODE
		ON PAT_ENC_DX.DX_ID = T_SNO_CODE.DX_ID

