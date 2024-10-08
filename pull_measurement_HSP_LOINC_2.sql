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

Name: pull_measurement_HSP_LOINC_2

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_measurement_HSP_LOINC_2. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[MEASUREMENT_ClarityAMB_LOINC]
	which will be used later in app_measurement_HSP_LOINC_2.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[MEASUREMENT_ClarityAMB_LOINC] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;

IF EXISTS (
		SELECT NULL
		
		FROM INFORMATION_SCHEMA.TABLES
		
		WHERE TABLE_NAME = 'MEASUREMENT_ClarityHosp_LOINC'
		)
	DROP TABLE OMOP_Clarity.MEASUREMENT_ClarityHosp_LOINC;


WITH T_LOINC_CODES
AS (
	SELECT RECORD_ID
		,LNC_CODE
		,LNC_COMPON
	
	FROM EpicClarity.dbo.LNC_DB_MAIN
	)

SELECT DISTINCT
	--NULL   AS measurement_id, ----IDENTITY
	SUBSTRING(AoU_Driver.AoU_ID, 2, LEN(AoU_Driver.AoU_ID)) AS person_id
	,AoU_Driver.AoU_ID
	,ORDER_PROC_2.SPECIMN_TAKEN_TIME
	,order_proc.ORDER_TIME
	,ORD_VALUE
	,ORDER_RESULTS.REFERENCE_LOW
	,ORDER_RESULTS.REFERENCE_HIGH
	,T_LOINC_CODES.LNC_CODE
	,T_LOINC_CODES.LNC_COMPON
	,T_LOINC_CODES.RECORD_ID
	,ORDER_RESULTS.REFERENCE_UNIT
	,ORDER_PROC.[AUTHRZING_PROV_ID]
	,PAT_ENC_HSP.PAT_ID
	,PAT_ENC_HSP.PAT_ENC_CSN_ID
	,ORDER_PROC.ORDER_PROC_ID
	,ORDER_RESULTS.COMPON_LNC_ID
	,ORDER_RESULTS.RESULT_FLAG_C
	,ZC_RESULT_FLAG.NAME AS ZC_RESULT_FLAG_NAME
	,ORDER_RESULTS.RESULT_STATUS_C
	,ZC_RESULT_STATUS.NAME AS ZC_RESULT_STATUS_NAME
	,ORDER_PROC.ORDER_STATUS_C
	,ZC_ORDER_STATUS.NAME AS ZC_ORDER_STATUS_NAME
	,'MEASUREMENT--ClarityHosp--LOINC' AS ETL_Module

INTO OMOP_Clarity.MEASUREMENT_ClarityHosp_LOINC

FROM EpicClarity.dbo.PAT_ENC_HSP

INNER JOIN OMOP.AoU_Driver
	ON PAT_ENC_HSP.PAT_ID = AoU_Driver.Epic_Pat_id

INNER JOIN EpicClarity.dbo.ORDER_PROC
	ON ORDER_PROC.PAT_ENC_CSN_ID = PAT_ENC_HSP.PAT_ENC_CSN_ID

INNER JOIN omop.visit_occurrence
	ON ORDER_PROC.PAT_ENC_CSN_ID = visit_occurrence.[visit_source_value]

INNER JOIN EpicClarity.dbo.ORDER_PROC_2
	ON ORDER_PROC.ORDER_PROC_ID = ORDER_PROC_2.ORDER_PROC_ID

INNER JOIN EpicClarity.dbo.ORDER_RESULTS
	ON ORDER_PROC.ORDER_PROC_ID = ORDER_RESULTS.ORDER_PROC_ID

INNER JOIN T_LOINC_CODES
	ON ORDER_RESULTS.COMPON_LNC_ID = T_LOINC_CODES.RECORD_ID

LEFT JOIN EpicClarity.dbo.ZC_RESULT_FLAG
	ON ORDER_RESULTS.RESULT_FLAG_C = ZC_RESULT_FLAG.RESULT_FLAG_C

LEFT JOIN EpicClarity.dbo.ZC_RESULT_STATUS
	ON ORDER_RESULTS.RESULT_STATUS_C = ZC_RESULT_STATUS.RESULT_STATUS_C

LEFT JOIN EpicClarity.dbo.ZC_ORDER_STATUS
	ON ORDER_PROC.ORDER_STATUS_C = ZC_ORDER_STATUS.ORDER_STATUS_C

WHERE (ORDER_PROC.ORDER_STATUS_C <> 4)

