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
Name: app_procedure_occurrence_CPT_SURG_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
		
Description: This script is the 2nd it a two-part process.  It is used in conjunction with 
	(and following) Pull_procedure_occurrence_CPT_SURG_2.sql. 

	Its purpose is to join the data in [OMOP_Clarity].[PROCEDURE_OCCURRENCE_ClaritySURG_CPT] to the OMOP concept table
	to return standard concept ids, and append this data to [OMOP].[procedure_occurrence].

Structure: (if your structure is different, you will have to modify the code to match)
	Database:EpicCare
	Schemas: EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;


WITH 	T_SOURCE
AS (
	SELECT concept_id
		,concept_code
		,domain_id
		,vocabulary_id
	
	FROM omop.concept AS C
	
	WHERE C.vocabulary_id IN ('CPT4')
		AND C.domain_id = 'Procedure'
	)

,
T_CONCEPT
AS (
	SELECT c2.concept_id AS concept_id
		,C1.concept_id AS SOURCE_CONCEPT_ID
	
	FROM [EpicCare].omop.concept c1
	
	INNER JOIN [EpicCare].omop.concept_relationship cr
		ON c1.concept_id = cr.concept_id_1
			AND cr.relationship_id = 'Maps to'
	
	INNER JOIN [EpicCare].omop.concept c2
		ON c2.concept_id = cr.concept_id_2
	
	WHERE c2.standard_concept = 'S'
		AND c2.domain_id = 'procedure'
	)

INSERT INTO
        OMOP.procedure_occurrence
	(
		person_id
		, procedure_concept_id
		, procedure_date
		, procedure_datetime
		, procedure_type_concept_id
		, modifier_concept_id
		, quantity
		, provider_id
		, visit_occurrence_id
		, procedure_source_value
		, procedure_source_concept_id
		, qualifier_source_value
		, ETL_Module
)
SELECT DISTINCT PAT_ENC_HSP.person_id
	,T_CONCEPT.concept_id AS procedure_concept_id
	,CONVERT(DATE, PAT_ENC_HSP.[calc_start_time]) AS [procedure_date]
	,PAT_ENC_HSP.[calc_start_time] AS [procedure_datetime]
	,CASE WHEN line = 1 THEN 44786630
		ELSE 44786631
	END AS [procedure_type_concept_id]
	, 0 AS [modifier_concept_id]
	,1 AS [quantity]
	,provider.provider_id AS [provider_id]
	,visit_occurrence.[visit_occurrence_id] AS [visit_occurrence_id]
	,PAT_ENC_HSP.PROC_CODE + ':' + LEFT(PAT_ENC_HSP.PROC_NAME, 49 - LEN(PAT_ENC_HSP.PROC_CODE)) AS [procedure_source_value]
	,T_SOURCE.concept_id AS [procedure_source_concept_id]
	,null as qualifier_source_value
	,'PROCEDURE_OCCURRENCE--ClaritySURG--CPT' AS ETL_Module

FROM [OMOP_Clarity].PROCEDURE_OCCURRENCE_ClaritySURG_CPT AS PAT_ENC_HSP

INNER JOIN T_SOURCE
	ON PAT_ENC_HSP.PROC_CODE = T_SOURCE.concept_code

INNER JOIN T_CONCEPT
	ON T_SOURCE.CONCEPT_ID = T_CONCEPT.concept_id

-------------------------------------------
INNER JOIN omop.visit_occurrence
	ON PAT_ENC_HSP.PAT_ENC_CSN_ID = visit_occurrence.[visit_source_value]

LEFT JOIN omop.provider
	ON PAT_ENC_HSP.[calc_perform_phys] = provider.[provider_source_value]


