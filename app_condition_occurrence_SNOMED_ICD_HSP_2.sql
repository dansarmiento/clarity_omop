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
Name: app_condition_occurrence_SNOMED_ICD_HSP_2

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
		
Description: This script is the 2nd it a two-part process.  It is used in conjunction with 
	(and following) pull_condition_occurrence_SNOMED_ICD_HSP_2. 

	Its purpose is to join the data in CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD to the OMOP concept table
	to return standard concept ids, and append this data to [OMOP].[condition_occurrence].

Structure: (if your structure is different, you will have to modify the code to match)
	Database:EpicCare
	Schemas: EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE epiccare;

WITH 

T_SOURCE
AS (
	SELECT concept_id
		,concept_code
	
	FROM omop.concept AS C
	
	WHERE C.vocabulary_id IN ('SNOMED')
		AND (
			C.invalid_reason IS NULL
			OR C.invalid_reason = ''
			)
		AND C.domain_id = 'Condition'
	)
,

T_ICD_SOURCE
AS (
	SELECT concept_id
		,concept_code
		,replace(concept_NAME,'"','') as concept_name
	FROM omop.concept AS C
	WHERE C.vocabulary_id IN (
			'ICD9CM',
			'ICD10CM'
			)
		AND (
			C.invalid_reason IS NULL
			OR C.invalid_reason = ''
			)
		AND C.domain_id = 'Condition'
	)

,
T_CONCEPT
AS (
	SELECT c2.concept_id AS CONCEPT_ID
		,C1.concept_id AS SOURCE_CONCEPT_ID
	
	FROM omop.concept c1
	
		JOIN omop.concept_relationship cr
			ON c1.concept_id = cr.concept_id_1
				AND cr.relationship_id = 'Maps to'
		
		JOIN omop.concept c2
			ON c2.concept_id = cr.concept_id_2
	
	WHERE c2.standard_concept = 'S'
		AND (
			c2.invalid_reason IS NULL
			OR c2.invalid_reason = ''
			)
		AND c2.domain_id = 'Condition'
	)



INSERT INTO OMOP.condition_occurrence (
	[person_id]
	,[condition_concept_id]
	,[condition_start_date]
	,[condition_start_datetime]
	,[condition_end_date]
	,[condition_end_datetime]
	,[condition_type_concept_id]
	,[stop_reason]
	,[provider_id]
	,[visit_occurrence_id]
	,[condition_source_value]
	,[condition_source_concept_id]
	,[condition_status_source_value]
	,[condition_status_concept_id]
	, ETL_Module

	)

SELECT DISTINCT 
	CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.person_id
	,t_sno_concept.CONCEPT_ID AS condition_concept_id
	,CONVERT(DATE, CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.CONTACT_DATE) AS condition_start_date
	,CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.CONTACT_DATE AS condition_start_datetime
	,CONVERT(DATE, CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.[HOSP_DISCH_TIME]) AS condition_end_date
	,CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.[HOSP_DISCH_TIME] AS condition_end_datetime
	,CASE 
		WHEN PRIMARY_DX_YN = 'Y'
			THEN '44786627'
		ELSE '44786629'
		END AS condition_type_concept_id
	,CASE 
		WHEN DISCH_DISP_C = 20
			THEN 'Expired'
		ELSE 'Discharged'
		END AS stop_reason
	,provider.provider_id AS provider_id
	,visit_occurrence.[visit_occurrence_id] AS visit_occurrence_id

-- returns ICD10 codes after switch date-----
	,CASE
		WHEN CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.CONTACT_DATE >= '2015-10-01'
		THEN 	left(t_icd10_source.concept_code + ':' + t_icd10_source.concept_NAME,50)
		ELSE	left(t_icd9_source.concept_code + ':' + t_icd9_source.concept_NAME,50)
	END AS condition_source_value
	,CASE
		WHEN CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.CONTACT_DATE >= '2015-10-01'
		THEN	t_icd10_source.CONCEPT_ID 
		ELSE 	t_icd10_source.CONCEPT_ID
	END AS condition_source_concept_id
--------------------------------------------

	,'Final diagnosis' AS condition_status_source_value
	,4230359 AS condition_status_concept_id
	, 'CONDITION_OCCURRENCE--ClarityHosp--ICD'	AS ETL_Module 

FROM OMOP_Clarity.CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD

	INNER JOIN omop.visit_occurrence
		ON CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.PAT_ENC_CSN_ID = visit_occurrence.visit_source_value

	LEFT OUTER JOIN omop.provider
		ON CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.PROV_ID = provider.[provider_source_value]

--------Concept Mapping--------------------

	INNER JOIN T_SOURCE as t_sno_source
		ON CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.SNOMED_code = t_sno_source.concept_code 

	INNER JOIN T_ICD_SOURCE as t_icd9_source 
			ON CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.icd9_code = t_icd9_source.concept_code

	INNER JOIN T_ICD_SOURCE as t_icd10_source 
			ON CONDITION_OCCURRENCE_ClarityHosp_SNOMED_ICD.icd10_code = t_icd10_source.concept_code

	INNER JOIN T_CONCEPT as t_sno_concept
		ON t_sno_concept.SOURCE_CONCEPT_ID = t_sno_source.concept_ID

	INNER JOIN T_CONCEPT as t_icd9_concept
		ON t_icd9_concept.SOURCE_CONCEPT_ID = t_icd9_source.concept_ID

	INNER JOIN T_CONCEPT as t_icd10_concept
		ON t_icd10_concept.SOURCE_CONCEPT_ID = t_icd10_source.concept_ID
		
-------------------------------------------



