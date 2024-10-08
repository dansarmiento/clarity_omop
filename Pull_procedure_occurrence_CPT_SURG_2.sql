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

Name: Pull_procedure_occurrence_CPT_SURG_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_procedure_occurrence_CPT_SURG_2.sql. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[PROCEDURE_OCCURRENCE_ClaritySURG_CPT]
	which will be used later in app_procedure_occurrence_CPT_SURG_2.sql.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[PROCEDURE_OCCURRENCE_ClaritySURG_CPT] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;


IF EXISTS (
		SELECT NULL
		FROM INFORMATION_SCHEMA.TABLES
		WHERE TABLE_NAME = 'PROCEDURE_OCCURRENCE_ClaritySURG_CPT'
		)
	DROP TABLE OMOP_Clarity.PROCEDURE_OCCURRENCE_ClaritySURG_CPT;


WITH T_CPT_CODES
AS (
	SELECT DISTINCT eap.proc_id
		,case
			when eap2.PROC_CODE is null then
			eap.PROC_CODE
			else
			eap2.PROC_CODE 
		end AS PROC_CODE
		,case
			when eap2.PROC_NAME is null then
			eap.PROC_NAME
			else
			eap2.PROC_NAME 
		end AS PROC_NAME

	FROM EpicClarity.dbo.CLARITY_EAP AS eap
	
	LEFT JOIN EpicClarity.dbo.LINKED_PERFORMABLE
		ON eap.PROC_ID = LINKED_PERFORMABLE.PROC_ID
	
	LEFT JOIN EpicClarity.dbo.CLARITY_EAP AS eap2
		ON LINKED_PERFORMABLE.LINKED_PERFORM_ID = eap2.PROC_ID
	
	UNION
	
	SELECT DISTINCT eap.proc_id as PROC_ID
		,case
			when eap2.PROC_CODE is null then
			eap.PROC_CODE
			else
			eap2.PROC_CODE 
		end AS PROC_CODE
		,case
			when eap2.PROC_NAME is null then
			eap.PROC_NAME
			else
			eap2.PROC_NAME 
		end AS PROC_NAME
	
	FROM EpicClarity.dbo.CLARITY_EAP AS eap
	
	LEFT JOIN EpicClarity.dbo.LINKED_CHARGEABLES
		ON eap.PROC_ID = LINKED_CHARGEABLES.PROC_ID
	
	LEFT JOIN EpicClarity.dbo.CLARITY_EAP AS eap2
		ON LINKED_CHARGEABLES.LINKED_CHRG_ID = eap2.PROC_ID
	
	)

SELECT DISTINCT 
	SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID)) AS person_id
	,AoU_ID
	,PAT_ENC_HSP.PAT_ENC_CSN_ID
	,PAT_ENC_HSP.PAT_ID
	,PAT_ENC_HSP.HSP_ACCOUNT_ID
	,OR_LOG.INPATIENT_DATA_ID
	,OR_LOG.SURGERY_DATE
	,OR_LOG.SCHED_START_TIME
	,OR_LOG.TOTAL_TIME_NEEDED
	,OR_LOG_VIRTUAL.ACT_START_OTS_DTTM
	,OR_LOG_VIRTUAL.ACT_END_OTS_DTTM
	,coalesce(OR_LOG_VIRTUAL.ACT_START_OTS_DTTM, OR_LOG.SCHED_START_TIME) AS calc_start_time
	,coalesce(OR_LOG_VIRTUAL.ACT_END_OTS_DTTM, dateadd(minute, convert(INT, OR_LOG.TOTAL_TIME_NEEDED), OR_LOG.SCHED_START_TIME)) AS calc_end_dttm
	,OR_LOG.PRIMARY_PHYS_ID
	,OR_LOG_ALL_SURG.SURG_ID
	,coalesce(OR_LOG_ALL_SURG.SURG_ID, OR_LOG.PRIMARY_PHYS_ID) AS calc_perform_phys
	,OR_LOG_ALL_PROC.OR_PROC_ID
	,OR_LOG_ALL_PROC.ALL_PROC_CODE_ID
	,OR_LOG_ALL_PROC.LINE
	,OR_LOG_VIRTUAL.PRIMARY_PROC_ID
	,T_CPT_CODES.PROC_CODE
	,T_CPT_CODES.PROC_NAME
	,OR_LOG.STATUS_C
	,ZC_OR_STATUS.NAME AS ZC_ORDER_STATUS_name
	,'PROCEDURE_OCCURRENCE--ClaritySURG--CPT' AS ETL_Module

INTO OMOP_Clarity.PROCEDURE_OCCURRENCE_ClaritySURG_CPT

FROM [EpicCare].OMOP.AoU_Driver

	INNER JOIN EpicClarity.dbo.PAT_ENC_HSP
		ON AoU_Driver.Epic_Pat_id = PAT_ENC_HSP.PAT_ID

	INNER JOIN [EpicClarity].[dbo].PAT_OR_ADM_LINK
		ON PAT_ENC_HSP.[PAT_ENC_CSN_ID] = PAT_OR_ADM_LINK.OR_LINK_CSN

	INNER JOIN [EpicClarity].[dbo].OR_LOG
		ON PAT_OR_ADM_LINK.LOG_ID = OR_LOG.LOG_ID

	INNER JOIN [EpicClarity].[dbo].OR_LOG_VIRTUAL
		ON OR_LOG.LOG_ID = OR_LOG_VIRTUAL.LOG_ID

	INNER JOIN [EpicClarity].[dbo].OR_LOG_ALL_PROC
		ON OR_LOG.LOG_ID = OR_LOG_ALL_PROC.LOG_ID

	LEFT JOIN [EpicClarity].[dbo].OR_LOG_ALL_SURG
		ON OR_LOG.LOG_ID = OR_LOG_ALL_SURG.LOG_ID
			AND OR_LOG_ALL_PROC.LINE = OR_LOG_ALL_SURG.LINE

	LEFT JOIN T_CPT_CODES
		ON OR_LOG_ALL_PROC.ALL_PROC_CODE_ID = T_CPT_CODES.PROC_ID

	LEFT JOIN [EpicClarity].[dbo].ZC_OR_STATUS
		ON OR_LOG.STATUS_C = ZC_OR_STATUS.STATUS_C

WHERE (OR_LOG.STATUS_C = 2)
	AND ALL_PROC_CODE_ID IS NOT NULL

ORDER BY PAT_ENC_HSP.PAT_ENC_CSN_ID
	,OR_LOG_ALL_PROC.LINE

