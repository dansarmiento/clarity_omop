USE EpicCare;

--TRUNCATE TABLE OMOP.device_exposure;
DELETE FROM OMOP.device_exposure
WHERE ETL_Module = 'DEVICE_EXPOSURE--ClarityANES--LDA';

WITH T_source_to_concept_map_device_LDA
AS (
	SELECT *
	
	FROM omop.source_to_concept_map
	
	WHERE source_vocabulary_id = 'SH_device_LDA'
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

SELECT DISTINCT 
	DEVICE_EXPOSURE_ClarityANES_LDA.person_id
	,T_source_to_concept_map_device_LDA.target_concept_id AS device_concept_id
	,CONVERT(DATE, DEVICE_EXPOSURE_ClarityANES_LDA.PLACEMENT_INSTANT) AS device_exposure_start_date
	,DEVICE_EXPOSURE_ClarityANES_LDA.PLACEMENT_INSTANT AS device_exposure_start_datetime
	,CONVERT(DATE,DEVICE_EXPOSURE_ClarityANES_LDA.REMOVAL_INSTANT) AS device_exposure_end_date
	,DEVICE_EXPOSURE_ClarityANES_LDA.REMOVAL_INSTANT AS device_exposure_end_datetime
	,32817 AS device_type_concept_id --EHR Detail
	,NULL AS unique_device_id
	,NULL AS quantity
	,DEVICE_EXPOSURE_ClarityANES_LDA.BILL_ATTEND_PROV_ID AS provider_id
	,visit_occurrence.visit_occurrence_id AS visit_occurrence_id
	,convert(VARCHAR(20), DEVICE_EXPOSURE_ClarityANES_LDA.FLO_MEAS_ID) + ': ' + DEVICE_EXPOSURE_ClarityANES_LDA.FLO_MEAS_NAME AS device_source_value
	,0 AS device_source_concept_id
	,'DEVICE_EXPOSURE--ClarityANES--LDA' AS ETL_Module
	,visit_source_value

FROM OMOP_Clarity.DEVICE_EXPOSURE_ClarityANES_LDA

INNER JOIN T_source_to_concept_map_device_LDA
	ON DEVICE_EXPOSURE_ClarityANES_LDA.FLO_MEAS_ID = T_source_to_concept_map_device_LDA.source_code

INNER JOIN omop.visit_occurrence
	ON DEVICE_EXPOSURE_ClarityANES_LDA.PAT_ENC_CSN_ID = visit_occurrence.visit_source_value

INNER JOIN omop.provider
	ON DEVICE_EXPOSURE_ClarityANES_LDA.BILL_ATTEND_PROV_ID = provider.provider_source_value

where PLACEMENT_INSTANT is not null
order by person_id