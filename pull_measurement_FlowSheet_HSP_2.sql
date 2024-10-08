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

Name: pull_measurement_FlowSheet_HSP_2

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with (and before)
		app_measurement_FlowSheet_HSP_BPM_2
		app_measurement_FlowSheet_HSP_BPD_2
		app_measurement_FlowSheet_HSP_BPS_2
		app_measurement_FlowSheet_HSP_vitals_2
		app_measurement_FlowSheet_HSP_temperature_2. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[MEASUREMENT_ClarityHosp_FlowSheet]
	which will be used later in the above "APP_" scripts.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[MEASUREMENT_ClarityHosp_FlowSheet] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;


IF EXISTS (
		SELECT NULL
		
		FROM INFORMATION_SCHEMA.TABLES
		
		WHERE TABLE_NAME = 'MEASUREMENT_ClarityHosp_FlowSheet'
		)
	DROP TABLE OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet;


SELECT SUBSTRING(AoU_Driver.AoU_ID, 2, LEN(AoU_Driver.AoU_ID)) AS person_id
	,AoU_Driver.AoU_ID
	,IP_FLWSHT_MEAS.recorded_time
	,IP_FLWSHT_MEAS.MEAS_VALUE
	,[IP_FLO_GP_DATA].[MINVALUE]
	,[IP_FLO_GP_DATA].[MAX_VAL]
	,[IP_FLO_GP_DATA].flo_meas_id
	,[IP_FLO_GP_DATA].FLO_MEAS_NAME
	,[IP_FLO_GP_DATA].VAL_TYPE_C
	,ZC_VAL_TYPE.NAME AS ZC_VAL_TYPE_NAME
	,[IP_FLO_GP_DATA].UNITS
	,[IP_FLO_GP_DATA].DISP_NAME
	,PAT_ENC_HSP.PAT_ID
	,PAT_ENC_HSP.PAT_ENC_CSN_ID
	,IP_DATA_STORE.EPT_CSN
	,IP_DATA_STORE.INPATIENT_DATA_ID
	,IP_FLWSHT_REC.FSD_ID
	,PAT_ENC_HSP.BILL_ATTEND_PROV_ID
	,'MEASUREMENT--ClarityHosp--FlowSheet_all' AS ETL_Module

INTO OMOP_Clarity.MEASUREMENT_ClarityHosp_FlowSheet

FROM EpicClarity.dbo.PAT_ENC_HSP

	INNER JOIN OMOP.AoU_Driver
		ON PAT_ENC_HSP.PAT_ID = OMOP.AoU_Driver.Epic_Pat_id

	LEFT JOIN EpicClarity.dbo.IP_DATA_STORE
		ON PAT_ENC_HSP.PAT_ENC_CSN_ID = IP_DATA_STORE.EPT_CSN

	LEFT JOIN EpicClarity.dbo.IP_FLWSHT_REC
		ON IP_DATA_STORE.INPATIENT_DATA_ID = IP_FLWSHT_REC.INPATIENT_DATA_ID

	LEFT JOIN EpicClarity.dbo.IP_FLWSHT_MEAS
		ON IP_FLWSHT_REC.FSD_ID = IP_FLWSHT_MEAS.FSD_ID

	INNER JOIN EpicClarity.dbo.[IP_FLO_GP_DATA]
		ON IP_FLWSHT_MEAS.[FLO_MEAS_ID] = [IP_FLO_GP_DATA].[FLO_MEAS_ID]

	INNER JOIN EpicClarity.dbo.ZC_VAL_TYPE
		ON [IP_FLO_GP_DATA].VAL_TYPE_C = ZC_VAL_TYPE.VAL_TYPE_C

	INNER JOIN omop.visit_occurrence
		ON PAT_ENC_HSP.PAT_ENC_CSN_ID = visit_occurrence.[visit_source_value]

	LEFT JOIN omop.provider
		ON PAT_ENC_HSP.BILL_ATTEND_PROV_ID = provider.[provider_source_value]
	
	


