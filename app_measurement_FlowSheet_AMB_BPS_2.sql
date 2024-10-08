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
Name: app_measurement_FlowSheet_AMB_BPS_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
		
Description: This script is the 2nd it a two-part process.  It is used in conjunction with 
	(and following) pull_measurement_FlowSheet_AMB_ALL_2.sql. 

	Its purpose is to join the data in [OMOP_Clarity].[MEASUREMENT_ClarityAMB_FlowSheet] to the OMOP concept table
	to return standard concept ids, and append this data to [OMOP].[measurement].

Structure: (if your structure is different, you will have to modify the code to match)
	Database:EpicCare
	Schemas: EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;

INSERT INTO [EpicCare].[OMOP].[measurement]
( 
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

SELECT DISTINCT MEASUREMENT_ClarityAMB_FlowSheet.person_id
	,isnull(source_to_concept_map_flowsheet_meas.target_concept_id, 0) AS measurement_concept_id
	,CONVERT(DATE, MEASUREMENT_ClarityAMB_FlowSheet.recorded_time) AS measurement_date
	,MEASUREMENT_ClarityAMB_FlowSheet.recorded_time AS measurement_datetime
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

	, convert(FLOAT, LEFT(MEAS_VALUE, CHARINDEX('/', MEAS_VALUE) - 1)) as value_as_number --systolic

	,0 AS value_as_concept_id
	,8876 AS unit_concept_id --mm Hg
	,MEASUREMENT_ClarityAMB_FlowSheet.[MINVALUE] AS range_low
	,MEASUREMENT_ClarityAMB_FlowSheet.[MAX_VAL] AS range_high
	,provider.provider_id AS provider_id
	,visit_occurrence.[visit_occurrence_id] AS visit_occurrence_id
	,'FLWSHT: ' + MEASUREMENT_ClarityAMB_FlowSheet.[FLO_MEAS_NAME] AS measurement_source_value
	,0 AS measurement_source_concept_id
	,source_to_concept_map_flowsheet_meas_units.source_code_description AS unit_source_value
	,MEASUREMENT_ClarityAMB_FlowSheet.MEAS_VALUE AS value_source_value
	,'MEASUREMENT--ClarityAMB--FlowSheet_bps' AS ETL_Module

FROM OMOP_Clarity.MEASUREMENT_ClarityAMB_FlowSheet

	INNER JOIN OMOP.source_to_concept_map AS source_to_concept_map_flowsheet_meas
		ON MEASUREMENT_ClarityAMB_FlowSheet.FLO_MEAS_ID = source_to_concept_map_flowsheet_meas.source_code
			AND source_to_concept_map_flowsheet_meas.source_vocabulary_id = 'sh_flwsht_meas_bps'

	LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_flowsheet_meas_units
		ON --note COLLATE Latin1_General_CS_AI used for case-sensitivity of units
			MEASUREMENT_ClarityAMB_FlowSheet.FLO_MEAS_ID COLLATE Latin1_General_CS_AI = source_to_concept_map_flowsheet_meas_units.source_code COLLATE Latin1_General_CS_AI
			AND source_to_concept_map_flowsheet_meas_units.source_vocabulary_id = 'SH_flowsht_meas_unit'

    INNER JOIN
                OMOP.source_to_concept_map AS source_to_concept_map_amb_visit
                ON
                            source_to_concept_map_amb_visit.source_code   = MEASUREMENT_ClarityAMB_FlowSheet.ENC_TYPE_C
                            AND source_to_concept_map_amb_visit.source_vocabulary_id  IN('SH_amb_f2f')

	INNER JOIN OMOP.visit_occurrence
		ON MEASUREMENT_ClarityAMB_FlowSheet.PAT_ENC_CSN_ID = visit_occurrence.[visit_source_value]

	LEFT JOIN OMOP.provider
		ON MEASUREMENT_ClarityAMB_FlowSheet.[VISIT_PROV_ID] = provider.[provider_source_value]

