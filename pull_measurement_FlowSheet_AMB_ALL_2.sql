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

Name: pull_measurement_FlowSheet_AMB_ALL_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) 
		app_measurement_FlowSheet_AMB_BPD_2.sql
		app_measurement_FlowSheet_AMB_BPS_2.sql
		app_measurement_FlowSheet_AMB_BPM_2.sql
		app_measurement_FlowSheet_AMB_temperature_2.sql
		app_measurement_FlowSheet_AMB_vitals_2.sql. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[MEASUREMENT_ClarityAMB_FlowSheet]
	which will be used later in the above "APP_" scripts.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[MEASUREMENT_ClarityAMB_FlowSheet] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;


IF EXISTS (
		SELECT NULL
		
		FROM INFORMATION_SCHEMA.TABLES
		
		WHERE TABLE_NAME = 'MEASUREMENT_ClarityAMB_FlowSheet'
		)
	DROP TABLE OMOP_Clarity.MEASUREMENT_ClarityAMB_FlowSheet;



SELECT  DISTINCT SUBSTRING(AoU_Driver.AoU_ID, 2, LEN(AoU_Driver.AoU_ID)) AS person_id
	,AoU_Driver.AoU_ID
	,PAT_ENC_AMB.PAT_ID
	,PAT_ENC_AMB.PAT_ENC_CSN_ID
	,PAT_ENC_AMB.HSP_ACCOUNT_ID
	,PAT_ENC_AMB.IP_DOC_CONTACT_CSN
	,PAT_ENC_AMB.ENC_TYPE_C
	,PAT_ENC_AMB.ZC_DISP_ENC_TYPE_NAME
	,PAT_ENC_AMB.pat_or_adm_link_csn as pat_or_adm_link_PAT_ENC_CSN_ID

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

	,IP_DATA_STORE.EPT_CSN
	,IP_DATA_STORE.INPATIENT_DATA_ID

	,IP_FLWSHT_REC.FSD_ID
	,PAT_ENC_AMB.visit_PROV_ID
	,'MEASUREMENT--ClarityAMB--FlowSheet' AS ETL_Module

INTO OMOP_Clarity.MEASUREMENT_ClarityAMB_FlowSheet

FROM EpicCare.OMOP.AoU_Driver

INNER JOIN OMOP_Clarity.VISIT_OCCURRENCE_ClarityAMB_ALL AS PAT_ENC_AMB
	ON AoU_Driver.Epic_Pat_id = PAT_ENC_AMB.PAT_ID

LEFT JOIN EpicClarity.dbo.IP_DATA_STORE
	ON PAT_ENC_AMB.PAT_ENC_CSN_ID = IP_DATA_STORE.EPT_CSN

LEFT JOIN EpicClarity.dbo.IP_FLWSHT_REC
	ON IP_DATA_STORE.INPATIENT_DATA_ID = IP_FLWSHT_REC.INPATIENT_DATA_ID

LEFT JOIN EpicClarity.dbo.IP_FLWSHT_MEAS
	ON IP_FLWSHT_REC.FSD_ID = IP_FLWSHT_MEAS.FSD_ID

INNER JOIN EpicClarity.dbo.[IP_FLO_GP_DATA]
	ON IP_FLWSHT_MEAS.[FLO_MEAS_ID] = [IP_FLO_GP_DATA].[FLO_MEAS_ID]

INNER JOIN EpicClarity.dbo.ZC_VAL_TYPE
	ON [IP_FLO_GP_DATA].VAL_TYPE_C = ZC_VAL_TYPE.VAL_TYPE_C

WHERE PAT_ENC_AMB.ENC_TYPE_C <> 3
