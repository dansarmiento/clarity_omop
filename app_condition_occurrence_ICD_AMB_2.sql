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
Name: app_condition_occurrence_ICD_AMB_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
		
Description: This script is the 2nd it a two-part process.  It is used in conjunction with 
	(and following) pull_condition_occurrence_ICD_AMB_2.sql. 

	Its purpose is to join the data in [OMOP_Clarity].[CONDITION_OCCURRENCE_ClarityAMB_ICD] to the OMOP concept table
	to return standard concept ids, and append this data to [OMOP].[condition_occurrence].

Structure: (if your structure is different, you will have to modify the code to match)
	Database:EpicCare
	Schemas: EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/


USE epiccare;


WITH 
T_ICD_SOURCE
AS (
	SELECT concept_id
		,concept_code
		,replace(concept_NAME, '"', '') AS concept_name
	
	FROM OMOP.concept AS C
	
	WHERE C.vocabulary_id IN (
			'ICD9CM'
			,'ICD10CM'
			)
		AND (
			C.invalid_reason IS NULL
			OR C.invalid_reason = ''
			)
		AND C.domain_id = 'Condition'
	)
,T_CONCEPT
AS (
	SELECT c2.concept_id AS CONCEPT_ID
		,C1.concept_id AS SOURCE_CONCEPT_ID
	
		FROM OMOP.concept c1
		
		INNER JOIN OMOP.concept_relationship cr
			ON c1.concept_id = cr.concept_id_1
				AND cr.relationship_id = 'Maps to'
		
		INNER JOIN OMOP.concept c2
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
	,ETL_Module
	)

SELECT DISTINCT CONDITION_OCCURRENCE_ClarityAMB_ICD.person_id
	--,t_icd10_concept.CONCEPT_ID AS OBSERVATION_concept_id

	,CASE 
		WHEN CONDITION_OCCURRENCE_ClarityAMB_ICD.CONTACT_DATE >= '2015-10-01'
			THEN t_icd10_concept.CONCEPT_ID
		ELSE t_icd9_concept.CONCEPT_ID
		END AS OBSERVATION_concept_id

	,CONVERT(DATE, CONDITION_OCCURRENCE_ClarityAMB_ICD.CONTACT_DATE) AS condition_start_date
	,CONDITION_OCCURRENCE_ClarityAMB_ICD.CONTACT_DATE AS condition_start_datetime
	,CONVERT(DATE, CONDITION_OCCURRENCE_ClarityAMB_ICD.CONTACT_DATE) AS condition_end_date
	,CONDITION_OCCURRENCE_ClarityAMB_ICD.CONTACT_DATE AS condition_end_datetime
	,CASE 
		WHEN PRIMARY_DX_YN = 'Y'
			THEN '44786627'
		ELSE '44786629'
		END AS condition_type_concept_id
	,NULL AS stop_reason
	,provider.provider_id AS provider_id
	,visit_occurrence.[visit_occurrence_id] AS visit_occurrence_id
	-- returns ICD10 codes after switch date-----
	,CASE 
		WHEN CONDITION_OCCURRENCE_ClarityAMB_ICD.CONTACT_DATE >= '2015-10-01'
			THEN left(t_icd10_source.concept_code + ':' + t_icd10_source.concept_NAME, 50)
		ELSE left(t_icd9_source.concept_code + ':' + t_icd9_source.concept_NAME, 50)
		END AS condition_source_value
	,CASE 
		WHEN CONDITION_OCCURRENCE_ClarityAMB_ICD.CONTACT_DATE >= '2015-10-01'
			THEN t_icd10_source.CONCEPT_ID
		ELSE t_icd9_source.CONCEPT_ID
		END AS condition_source_concept_id
	--------------------------------------------
	,'Final diagnosis' AS condition_status_source_value
	,4230359 AS condition_status_concept_id
	,'CONDITION_OCCURRENCE--ClarityAMB--ICD' AS ETL_Module

FROM OMOP_Clarity.CONDITION_OCCURRENCE_ClarityAMB_ICD

	INNER JOIN OMOP.visit_occurrence
		ON CONDITION_OCCURRENCE_ClarityAMB_ICD.PAT_ENC_CSN_ID = visit_occurrence.visit_source_value

	LEFT JOIN OMOP.provider
		ON CONDITION_OCCURRENCE_ClarityAMB_ICD.visit_PROV_ID = provider.[provider_source_value]

	--------Concept Mapping--------------------

	LEFT JOIN T_ICD_SOURCE AS t_icd9_source
		ON CONDITION_OCCURRENCE_ClarityAMB_ICD.icd9_code = t_icd9_source.concept_code

	LEFT JOIN T_ICD_SOURCE AS t_icd10_source
		ON CONDITION_OCCURRENCE_ClarityAMB_ICD.icd10_code = t_icd10_source.concept_code

	LEFT JOIN T_CONCEPT AS t_icd9_concept
		ON t_icd9_concept.SOURCE_CONCEPT_ID = t_icd9_source.concept_ID

	LEFT JOIN T_CONCEPT AS t_icd10_concept
		ON t_icd10_concept.SOURCE_CONCEPT_ID = t_icd10_source.concept_ID

WHERE 	
	(CONDITION_OCCURRENCE_ClarityAMB_ICD.CONTACT_DATE >= '2015-10-01' and t_icd10_concept.CONCEPT_ID IS NOT NULL)   
	or 
	(CONDITION_OCCURRENCE_ClarityAMB_ICD.CONTACT_DATE < '2015-10-01' and t_icd9_concept.CONCEPT_ID IS NOT NULL   )
