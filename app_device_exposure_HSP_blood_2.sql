USE EpicCare;

DELETE FROM OMOP.device_exposure
WHERE ETL_Module = 'DEVICE_EXPOSURE--ClarityHosp--Blood';

WITH T_source_to_concept_map_device_blood
AS (
	SELECT *
	
	FROM omop.source_to_concept_map
	
	WHERE source_vocabulary_id = 'SH_device_blood'
	)

INSERT INTO OMOP.device_exposure (
	person_id
	,device_concept_id
	,device_exposure_start_date
	,device_exposure_start_datetime
	,device_exposure_end_date
	,device_exposure_end_datetime
	,device_type_concept_id
	,unique_device_id
	,quantity
	,provider_id
	,visit_occurrence_id
	,device_source_value
	,device_source_concept_id
	,ETL_Module
	,visit_source_value
	)

SELECT DISTINCT--null as  device_exposure_id,
	DEVICE_EXPOSURE_ClarityHosp_Blood.person_id
	,T_source_to_concept_map_device_blood.target_concept_id AS device_concept_id
	,CONVERT(DATE, DEVICE_EXPOSURE_ClarityHosp_Blood.PROC_START_TIME) AS device_exposure_start_date
	,DEVICE_EXPOSURE_ClarityHosp_Blood.PROC_START_TIME AS device_exposure_start_datetime
	,CONVERT(DATE, coalesce(PROC_ENDING_TIME, PROC_START_TIME)) AS device_exposure_end_date
	,coalesce(PROC_ENDING_TIME, PROC_START_TIME) AS device_exposure_end_datetime
	,32817 AS device_type_concept_id --Inferred from procedure claim
	,DEVICE_EXPOSURE_ClarityHosp_Blood.BLOOD_ADMIN_UNIT AS unique_device_id
	,DEVICE_EXPOSURE_ClarityHosp_Blood.QUANTITY AS quantity
	,provider.provider_id AS provider_id
	,visit_occurrence.visit_occurrence_id AS visit_occurrence_id
	,convert(VARCHAR(20), DEVICE_EXPOSURE_ClarityHosp_Blood.PROC_ID) + ' : ' + DEVICE_EXPOSURE_ClarityHosp_Blood.PROC_code + ' : ' + DEVICE_EXPOSURE_ClarityHosp_Blood.PROC_NAME AS device_source_value
	,0 AS device_source_concept_id
	,'DEVICE_EXPOSURE--ClarityHosp--Blood' AS ETL_Module
	,visit_source_value

FROM OMOP_Clarity.DEVICE_EXPOSURE_ClarityHosp_Blood

INNER JOIN T_source_to_concept_map_device_blood
	ON DEVICE_EXPOSURE_ClarityHosp_Blood.PROC_ID = T_source_to_concept_map_device_blood.source_code

INNER JOIN omop.visit_occurrence
	ON DEVICE_EXPOSURE_ClarityHosp_Blood.PAT_ENC_CSN_ID = visit_occurrence.visit_source_value

INNER JOIN omop.provider
	ON DEVICE_EXPOSURE_ClarityHosp_Blood.AUTHRZING_PROV_ID = provider.provider_source_value

