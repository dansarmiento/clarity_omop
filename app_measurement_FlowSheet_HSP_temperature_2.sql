

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
Name: app_measurement_FlowSheet_HSP_temperature_2

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
		
Description: This script is the 2nd it a two-part process.  It is used in conjunction with 
	(and following) pull_measurement_FlowSheet_HSP_2. 

	Its purpose is to join the data in [OMOP_Clarity].[MEASUREMENT_ClarityHosp_FlowSheet] to the OMOP concept table
	to return standard concept ids, and append this data to [OMOP].[measurement].

Structure: (if your structure is different, you will have to modify the code to match)
	Database:EpicCare
	Schemas: EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;


WITH T_Temperature
AS (
	--temperature
	SELECT DISTINCT person_id
		,PAT_ENC_CSN_ID
		,recorded_time
		,MEAS_VALUE AS MEAS_VALUE
		,[MINVALUE]
		,[MAX_VAL]
		,FLO_MEAS_NAME
		,[FLO_MEAS_ID]
		,FSD_ID
		,BILL_ATTEND_PROV_ID
	
	FROM OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet
	
	--6 TEMPERATURE
	INNER JOIN OMOP.source_to_concept_map AS source_to_concept_map_flowsheet_meas
		ON FLO_MEAS_ID = source_to_concept_map_flowsheet_meas.source_code
			AND source_to_concept_map_flowsheet_meas.source_vocabulary_id = 'sh_flwsht_meas_temp'
	)
	,T_Temp_Source
AS (
	SELECT DISTINCT
		--AoU_ID
		person_id
		,PAT_ENC_CSN_ID
		,recorded_time
		,MEAS_VALUE AS MEAS_VALUE
	
	FROM OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet
	
	--7-TEMP SOURCE
	WHERE [FLO_MEAS_ID] IN ('7')
	)
	,T_Temperature_Merge
AS (
	SELECT T_Temperature.person_id
		,T_Temperature.PAT_ENC_CSN_ID
		,source_to_concept_map_flowsheet_temp_src.[target_concept_id] AS target_concept_id --temperature
		,T_Temperature.recorded_time
		,T_Temperature.MEAS_VALUE AS MEAS_VALUE
		,T_Temperature.[MINVALUE]
		,T_Temperature.[MAX_VAL]
		,T_Temperature.FLO_MEAS_NAME
		,source_to_concept_map_flowsheet_temp_src.[source_code_description]
		,T_Temperature.[FLO_MEAS_ID]
		,T_Temperature.FSD_ID
		,T_Temperature.BILL_ATTEND_PROV_ID
	
	FROM T_Temperature
	
	INNER JOIN T_Temp_Source
		ON T_Temperature.PAT_ENC_CSN_ID = T_Temp_Source.PAT_ENC_CSN_ID
			AND T_Temperature.recorded_time = T_Temp_Source.recorded_time
	
	INNER JOIN OMOP.source_to_concept_map AS source_to_concept_map_flowsheet_temp_src
		ON T_Temp_Source.MEAS_VALUE = source_to_concept_map_flowsheet_temp_src.source_code
			AND source_to_concept_map_flowsheet_temp_src.source_vocabulary_id = 'SH_temperature_sourc'
	)

INSERT INTO [EpicCare].[OMOP].[measurement] (
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
	,ETL_Module
	)

SELECT DISTINCT T_Temperature_Merge.person_id
	,T_Temperature_Merge.target_concept_id AS measurement_concept_id
	,CONVERT(DATE, T_Temperature_Merge.recorded_time) AS measurement_date
	,T_Temperature_Merge.recorded_time AS measurement_datetime
	,44818701 AS measurement_type_concept_id --From physical examination
	,4172703 AS operator_concept_id
	,MEAS_VALUE AS value_as_number
	,0 AS value_as_concept_id
	,isnull(source_to_concept_map_flowsheet_meas_units.target_concept_id, 0) AS unit_concept_id
	,[MINVALUE] AS range_low
	,[MAX_VAL] AS range_high
	,provider.provider_id AS provider_id
	,visit_occurrence.[visit_occurrence_id] AS visit_occurrence_id
	,'FLWSHT: ' + T_Temperature_Merge.[FLO_MEAS_NAME] + ': ' + T_Temperature_Merge.[source_code_description] AS measurement_source_value
	,0 AS measurement_source_concept_id
	,isnull(source_to_concept_map_flowsheet_meas_units.source_code_description, 0) AS unit_source_value
	,MEAS_VALUE AS value_source_value
	,'MEASUREMENT--ClarityHosp--FlowSheet_Temp' AS ETL_Module

FROM T_Temperature_Merge

LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_flowsheet_meas
	ON T_Temperature_Merge.FLO_MEAS_ID = source_to_concept_map_flowsheet_meas.source_code
		AND source_to_concept_map_flowsheet_meas.source_vocabulary_id = 'sh_flwsht_meas_temp'

LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_flowsheet_meas_units
	ON --note COLLATE Latin1_General_CS_AI used for case-sensitivity of units
		T_Temperature_Merge.FLO_MEAS_ID COLLATE Latin1_General_CS_AI = source_to_concept_map_flowsheet_meas_units.source_code COLLATE Latin1_General_CS_AI
		AND source_to_concept_map_flowsheet_meas_units.source_vocabulary_id = 'SH_flowsht_meas_unit'

INNER JOIN omop.visit_occurrence
	ON T_Temperature_Merge.PAT_ENC_CSN_ID = visit_occurrence.[visit_source_value]

LEFT JOIN omop.provider
	ON T_Temperature_Merge.BILL_ATTEND_PROV_ID = provider.[provider_source_value]

