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
Name: app_measurement_LOINC_AMB_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
		
Description: This script is the 2nd it a two-part process.  It is used in conjunction with 
	(and following) pull_measurement_LOINC_AMB_2.sql. 

	Its purpose is to join the data in [OMOP_Clarity].[MEASUREMENT_ClarityAMB_LOINC] to the OMOP concept table
	to return standard concept ids, and append this data to [OMOP].[measurement].

Structure: (if your structure is different, you will have to modify the code to match)
	Database:EpicCare
	Schemas: EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;

WITH T_SOURCE
AS (
	SELECT concept_id
		,concept_code
	
	FROM omop.concept AS C
	
	WHERE (
			C.invalid_reason IS NULL
			OR C.invalid_reason = ''
			)
		AND C.domain_id = 'MEASUREMENT'
		AND vocabulary_id = 'LOINC'
		AND concept_class_id = 'Lab Test'
	)
	,T_CONCEPT
AS (
	SELECT c2.concept_id AS CONCEPT_ID
		,C1.concept_id AS SOURCE_CONCEPT_ID
	
	FROM omop.concept c1
	
	INNER JOIN omop.concept_relationship cr
		ON c1.concept_id = cr.concept_id_1
			AND cr.relationship_id = 'Maps to'
	
	INNER JOIN omop.concept c2
		ON c2.concept_id = cr.concept_id_2
	
	WHERE c2.standard_concept = 'S'
		AND (
			c2.invalid_reason IS NULL
			OR c2.invalid_reason = ''
			)
		AND c2.domain_id = 'MEASUREMENT'
		AND c2.vocabulary_id = 'LOINC'
		AND c2.concept_class_id = 'Lab Test'
	)

INSERT INTO [EpicCare].[OMOP].[measurement]
(	--[measurement_id], ----IDENTITY
      [person_id]
      ,[measurement_concept_id]
      ,[measurement_date]
      ,[measurement_datetime]
      ,[measurement_type_concept_id]
      ,[operator_concept_id]
      ,[value_as_number]
      ,[value_as_concept_id]
      ,[unit_concept_id]
      ,[range_low]
      ,[range_high]
      ,[provider_id]
      ,[visit_occurrence_id]
      ,[measurement_source_value]
      ,[measurement_source_concept_id]
      ,[unit_source_value]
      ,[value_source_value]
	  , ETL_Module
)

SELECT DISTINCT MEASUREMENT_ClarityAMB_LOINC.person_id
	,T_CONCEPT.CONCEPT_ID AS measurement_concept_id
	,CONVERT(DATE, MEASUREMENT_ClarityAMB_LOINC.SPECIMN_TAKEN_TIME) AS measurement_date
	,MEASUREMENT_ClarityAMB_LOINC.SPECIMN_TAKEN_TIME AS measurement_datetime
	,44818702 AS measurement_type_concept_id --Lab result
	,CASE 
		WHEN ORD_VALUE LIKE '>=%'
			THEN 4171755
		WHEN ORD_VALUE LIKE '<=%'
			THEN 4171754
		WHEN ORD_VALUE LIKE '<%'
			THEN 4171756
		WHEN ORD_VALUE LIKE '>%'
			THEN 4172704
		ELSE 4172703
		END AS operator_concept_id
	,CASE 
		WHEN ISNUMERIC(REPLACE(REPLACE(REPLACE(REPLACE(ORD_VALUE, '=', ''), '<', ''), '>', ''), ',', '')) <> 1
			THEN NULL
		ELSE REPLACE(REPLACE(REPLACE(REPLACE(ORD_VALUE, '=', ''), '<', ''), '>', ''), ',', '')
		END AS value_as_number
	,isnull(source_to_concept_map_value.target_concept_id, 0) AS value_as_concept_id
	,isnull(source_to_concept_map_unit.target_concept_id, 0) AS unit_concept_id
	,CASE 
		WHEN ISNUMERIC(REPLACE(REPLACE(REPLACE(REPLACE(MEASUREMENT_ClarityAMB_LOINC.REFERENCE_LOW, '=', ''), '<', ''), '>', ''), ',', '')) <> 1
			THEN NULL
		ELSE convert(FLOAT, REPLACE(REPLACE(REPLACE(REPLACE(MEASUREMENT_ClarityAMB_LOINC.REFERENCE_LOW, '=', ''), '<', ''), '>', ''), ',', ''))
		END AS range_low
	,CASE 
		WHEN ISNUMERIC(REPLACE(REPLACE(REPLACE(REPLACE(MEASUREMENT_ClarityAMB_LOINC.REFERENCE_HIGH, '=', ''), '<', ''), '>', ''), ',', '')) <> 1
			THEN NULL
		ELSE convert(FLOAT, REPLACE(REPLACE(REPLACE(REPLACE(MEASUREMENT_ClarityAMB_LOINC.REFERENCE_HIGH, '=', ''), '<', ''), '>', ''), ',', ''))
		END AS range_high
	,provider.provider_id AS provider_id
	,visit_occurrence.[visit_occurrence_id] AS visit_occurrence_id
	,LEFT(MEASUREMENT_ClarityAMB_LOINC.LNC_CODE + ':' + MEASUREMENT_ClarityAMB_LOINC.LNC_COMPON, 50) AS measurement_source_value
	,T_SOURCE.concept_id AS measurement_source_concept_id
	,LEFT(MEASUREMENT_ClarityAMB_LOINC.REFERENCE_UNIT, 49) AS unit_source_value
	,LEFT(MEASUREMENT_ClarityAMB_LOINC.ORD_VALUE, 49) AS value_source_value
	,'MEASUREMENT--ClarityAMB--LOINC' AS ETL_Module

FROM OMOP_Clarity.MEASUREMENT_ClarityAMB_LOINC

INNER JOIN OMOP.visit_occurrence
	ON MEASUREMENT_ClarityAMB_LOINC.PAT_ENC_CSN_ID = visit_occurrence.[visit_source_value]
		AND ISNUMERIC(visit_occurrence.[visit_source_value]) = 1

INNER JOIN T_SOURCE
	ON MEASUREMENT_ClarityAMB_LOINC.LNC_CODE = T_SOURCE.concept_code

INNER JOIN T_CONCEPT
	ON T_CONCEPT.SOURCE_CONCEPT_ID = T_SOURCE.concept_ID

LEFT JOIN EpicClarity.dbo.ZC_RESULT_FLAG
	ON MEASUREMENT_ClarityAMB_LOINC.RESULT_FLAG_C = EpicClarity.dbo.ZC_RESULT_FLAG.RESULT_FLAG_C

LEFT JOIN EpicClarity.dbo.ZC_RESULT_STATUS
	ON MEASUREMENT_ClarityAMB_LOINC.RESULT_STATUS_C = EpicClarity.dbo.ZC_RESULT_STATUS.RESULT_STATUS_C

LEFT JOIN OMOP.provider
	ON MEASUREMENT_ClarityAMB_LOINC.[AUTHRZING_PROV_ID] = provider.[provider_source_value]

LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_unit
	ON MEASUREMENT_ClarityAMB_LOINC.REFERENCE_UNIT = source_to_concept_map_unit.source_code
		AND source_to_concept_map_unit.source_vocabulary_id = 'SH_unit'

--replaces above if case-sensitivity is needed
--LEFT JOIN
--                             OMOP.source_to_concept_map AS source_to_concept_map_unit
--                             ON
--                                             ORDER_RESULTS.REFERENCE_UNIT COLLATE Latin1_General_CS_AI  = source_to_concept_map_unit.source_code COLLATE Latin1_General_CS_AI
--                                             AND source_to_concept_map_unit.source_vocabulary_id = 'SH_unit'	
LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_value
	ON MEASUREMENT_ClarityAMB_LOINC.ORD_VALUE = source_to_concept_map_value.source_code
		AND source_to_concept_map_value.source_vocabulary_id = 'value_concept'

WHERE (MEASUREMENT_ClarityAMB_LOINC.ORDER_STATUS_C <> 4)

