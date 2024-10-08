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
Name: app_measurement_FlowSheet_HSP_misc_2

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

--measurement_FlowSheet_vitals
USE EpicCare;



INSERT INTO [EpicCare].[OMOP].[measurement]
( --[measurement_id], ----IDENTITY
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
SELECT DISTINCT OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.person_id
	,isnull(source_to_concept_map_flowsheet_meas.target_concept_id, 0) AS measurement_concept_id
	,CONVERT(DATE, OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.recorded_time) AS measurement_date
	,OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.recorded_time AS measurement_datetime
	,44818701 AS measurement_type_concept_id --From physical examination
	,CASE 
		WHEN MEAS_VALUE LIKE '>=%'
			THEN 4171755
		WHEN MEAS_VALUE LIKE '<=%'
			THEN 4171754
		WHEN MEAS_VALUE LIKE '<%'
			THEN 4171756
		WHEN MEAS_VALUE LIKE '>%'
			THEN 4172704
		ELSE 4172703
		END AS operator_concept_id
	,REPLACE(REPLACE(REPLACE(MEAS_VALUE, '=', ''), '<', ''), '>', '') AS value_as_number
	,0 AS value_as_concept_id
	,isnull(source_to_concept_map_flowsheet_meas_units.target_concept_id, 0) AS unit_concept_id
	,OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.[MINVALUE] AS range_low
	,OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.[MAX_VAL] AS range_high
	,provider.provider_id AS provider_id
	,visit_occurrence.[visit_occurrence_id] AS visit_occurrence_id
	,CONVERT(VARCHAR(20), OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.flo_meas_id) 
		+ ':' + LEFT(OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.[FLO_MEAS_NAME], 49 
		- LEN(OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.flo_meas_id)) 
		AS measurement_source_value
	,0 AS measurement_source_concept_id
	,source_to_concept_map_flowsheet_meas_units.source_code_description AS unit_source_value
	,MEAS_VALUE AS value_source_value
	,'MEASUREMENT--ClarityHosp--FlowSheet_Misc' AS ETL_Module

FROM OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet

INNER JOIN OMOP.source_to_concept_map AS source_to_concept_map_flowsheet_meas
	ON OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.FLO_MEAS_ID = source_to_concept_map_flowsheet_meas.source_code
		AND source_to_concept_map_flowsheet_meas.source_vocabulary_id = 'sh_flwsht_meas_misc'

LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_flowsheet_meas_units
	ON --note COLLATE Latin1_General_CS_AI used for case-sensitivity of units
		OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.FLO_MEAS_ID COLLATE Latin1_General_CS_AI = source_to_concept_map_flowsheet_meas_units.source_code COLLATE Latin1_General_CS_AI
		AND source_to_concept_map_flowsheet_meas_units.source_vocabulary_id = 'SH_flowsht_meas_unit'

INNER JOIN omop.visit_occurrence
	ON OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.PAT_ENC_CSN_ID = visit_occurrence.[visit_source_value]

LEFT JOIN omop.provider
	ON OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet.BILL_ATTEND_PROV_ID = provider.[provider_source_value]

