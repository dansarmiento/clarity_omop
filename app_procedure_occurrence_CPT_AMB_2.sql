USE EpicCare;

WITH	T_SOURCE
AS (
	SELECT concept_id
		,concept_code
		,domain_id
		,vocabulary_id
	
	FROM omop.concept AS C
	
	WHERE C.vocabulary_id IN ('CPT4')

		AND C.domain_id = 'Procedure'
	)
	,T_CONCEPT
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

INSERT INTO OMOP.procedure_occurrence (
	person_id
	,procedure_concept_id
	,procedure_date
	,procedure_datetime
	,procedure_type_concept_id
	,modifier_concept_id
	,quantity
	,provider_id
	,visit_occurrence_id
	,procedure_source_value
	,procedure_source_concept_id
	,qualifier_source_value
	,ETL_Module
	)

SELECT DISTINCT 
	[PROCEDURE_OCCURRENCE_ClarityAMB_CPT].person_id
	,T_CONCEPT.concept_id AS procedure_concept_id
	,CONVERT(DATE, coalesce([PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[OP_child_INSTANTIATED_TIME]
				, [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[OP_INSTANTIATED_TIME]
				, [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[OP_PROC_START_TIME]
				, [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[OP_ORDER_TIME])) AS [procedure_date]
	,coalesce([PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[OP_child_INSTANTIATED_TIME]
				, [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[OP_INSTANTIATED_TIME]
				, [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[OP_PROC_START_TIME]
				, [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[OP_ORDER_TIME]) AS [procedure_datetime]

	,CASE WHEN ORDER_DX_ID IS NOT NULL THEN
			44786630 -- PRIMARY
		ELSE
			44786631 -- SECONDARY
		END AS [procedure_type_concept_id]

	,isnull(source_to_concept_map_modifier.target_concept_id, 0) AS [modifier_concept_id]
	,[PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[QUANTITY] AS [quantity]
	,provider.provider_id AS [provider_id]
	,visit_occurrence.[visit_occurrence_id] AS [visit_occurrence_id]
	,[PROCEDURE_OCCURRENCE_ClarityAMB_CPT].PROC_CODE + ':' 
		+ LEFT([PROCEDURE_OCCURRENCE_ClarityAMB_CPT].PROC_NAME, 49 
		- LEN([PROCEDURE_OCCURRENCE_ClarityAMB_CPT].PROC_CODE)) 
		AS [procedure_source_value]
	,T_SOURCE.concept_id AS [procedure_source_concept_id]
	,[PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[MODIFIER1_ID] + ':' + [MODIFIER_NAME] AS [qualifier_source_value]
	,'PROCEDURE_OCCURRENCE--ClarityAMB--CPT' AS ETL_Module



FROM [EpicCare].[OMOP_Clarity].[PROCEDURE_OCCURRENCE_ClarityAMB_CPT]

	INNER JOIN T_SOURCE
		ON [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].PROC_CODE = T_SOURCE.concept_code

	INNER JOIN T_CONCEPT
		ON T_SOURCE.CONCEPT_ID = T_CONCEPT.concept_id

	INNER JOIN OMOP.visit_occurrence
		ON [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].PAT_ENC_CSN_ID = visit_occurrence.[visit_source_value]

	LEFT JOIN OMOP.provider
		ON [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[AUTHRZING_PROV_ID] = provider.[provider_source_value]

	LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_modifier
		ON [PROCEDURE_OCCURRENCE_ClarityAMB_CPT].[MODIFIER1_ID] = source_to_concept_map_modifier.source_code
			AND source_to_concept_map_modifier.source_vocabulary_id = 'SH_modifier'

