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

Name: pull_condition_occurrence_SNOMED_ICD_AMB_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_condition_occurrence_SNOMED_ICD_AMB_2.sql. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[CONDITION_OCCURRENCE_ClarityAMB_SNOMED_ICD]
	which will be used later in app_condition_occurrence_SNOMED_ICD_AMB_2.sql.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[CONDITION_OCCURRENCE_ClarityAMB_SNOMED_ICD] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;


IF EXISTS (
		SELECT NULL
		
		FROM INFORMATION_SCHEMA.TABLES
		
		WHERE TABLE_NAME = 'CONDITION_OCCURRENCE_ClarityAMB_SNOMED_ICD'
		)
	DROP TABLE OMOP_Clarity.CONDITION_OCCURRENCE_ClarityAMB_SNOMED_ICD;

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

	,T_SNO_CODE.DX_ID
	,T_SNO_CODE.DX_NAME
	,T_SNO_CODE.FULLY_SPECIFIED_NM
	,T_SNO_CODE.icd10_code
	,T_SNO_CODE.icd9_code
	,T_SNO_CODE.SNOMED_code
	,'CONDITION_OCCURRENCE--ClarityAMB--SNOMED_ICD' AS ETL_Module

INTO OMOP_Clarity.CONDITION_OCCURRENCE_ClarityAMB_SNOMED_ICD

FROM

EpicCare.OMOP.AoU_Driver

INNER JOIN OMOP_Clarity.VISIT_OCCURRENCE_ClarityAMB_ALL AS PAT_ENC_AMB
	ON AoU_Driver.Epic_Pat_id = PAT_ENC_AMB.PAT_ID

 	INNER JOIN EpicClarity.dbo.PAT_ENC_DX

		ON PAT_ENC_AMB.PAT_ENC_CSN_ID = PAT_ENC_DX.PAT_ENC_CSN_ID

	INNER JOIN T_SNO_CODE
		ON PAT_ENC_DX.DX_ID = T_SNO_CODE.DX_ID

WHERE PAT_ENC_AMB.ENC_TYPE_C <> 3