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

Name: Pull_procedure_occurrence_CPT_HSP_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_procedure_occurrence_CPT_HSP_2.sql. 

	Its purpose is to query data from Epic Clarity and append this data to [OMOP_Clarity].[PROCEDURE_OCCURRENCE_ClarityHSP_CPT]
	which will be used later in app_procedure_occurrence_CPT_HSP_2.sql.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	[OMOP_Clarity].[PROCEDURE_OCCURRENCE_ClarityHSP_CPT] may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;

IF EXISTS (	SELECT NULL	FROM INFORMATION_SCHEMA.TABLES	WHERE TABLE_NAME = 'PROCEDURE_OCCURRENCE_ClarityHSP_CPT')
	DROP TABLE OMOP_Clarity.PROCEDURE_OCCURRENCE_ClarityHSP_CPT;

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

SELECT DISTINCT --null as  [procedure_occurrence_id],
	SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID)) AS person_id
	,AoU_ID
	,PAT_ENC_HSP.PAT_ENC_CSN_ID
	,PAT_ENC_HSP.HSP_ACCOUNT_ID
	,PAT_ENC_HSP.pat_id
	,[ORDER_PROC].instantiated_time AS OP_INSTANTIATED_TIME
	,[ORDER_PROC].ORDER_TIME AS OP_ORDER_TIME
	,[ORDER_PROC].[PROC_START_TIME] AS OP_PROC_START_TIME
	,[ORDER_PROC].PROC_BGN_TIME AS OP_PROC_BGN_TIME
	,[ORDER_PROC].PROC_END_TIME AS OP_PROC_END_TIME
	,[ORDER_PROC].[MODIFIER1_ID]
	,[MODIFIER_NAME]
	,[ORDER_PROC].[QUANTITY]
	,[ORDER_PROC].[AUTHRZING_PROV_ID]
	,ORDER_PROC.FUTURE_OR_STAND
	
	, ORDER_PROC.PROC_ID
	,ORDER_DX_PROC.LINE as order_dx_line
	,ORDER_DX_PROC.DX_ID as order_dx_id

	,T_CPT_CODES.PROC_CODE
	,T_CPT_CODES.PROC_NAME

		,order_proc.ORDER_STATUS_C
	,ZC_ORDER_STATUS.name as ZC_ORDER_STATUS_name
	, ORDER_PROC.ORDER_PROC_ID

	, ORDER_PROC.ORDER_TYPE_C
	, ZC_ORDER_TYPE.NAME AS ZC_ORDER_TYPE_NAME

	,ORDER_PROC.ORDER_CLASS_C
	,ZC_ORDER_CLASS.NAME AS ZC_ORDER_CLASS_NAME

	,ORDER_PROC.LAB_STATUS_C
	,ZC_LAB_STATUS.NAME AS ZC_LAB_STATUS_NAME
	,'PROCEDURE_OCCURRENCE--ClarityHosp--CPT' AS ETL_Module


INTO OMOP_Clarity.PROCEDURE_OCCURRENCE_ClarityHSP_CPT

FROM [EpicCare].OMOP.AoU_Driver

INNER JOIN EpicClarity.dbo.PAT_ENC_HSP
	ON AoU_Driver.Epic_Pat_id = PAT_ENC_HSP.PAT_ID

INNER JOIN [EpicClarity].[dbo].[ORDER_PROC]
	ON PAT_ENC_HSP.[PAT_ENC_CSN_ID] = [ORDER_PROC].[PAT_ENC_CSN_ID]


LEFT JOIN EpicClarity.dbo.ORDER_DX_PROC on ORDER_PROC.ORDER_PROC_ID = ORDER_DX_PROC.ORDER_PROC_ID

inner JOIN T_CPT_CODES
	ON ORDER_PROC.PROC_ID = T_CPT_CODES.PROC_ID
	LEFT JOIN [EpicClarity].[dbo].ZC_ORDER_STATUS on [ORDER_PROC].ORDER_STATUS_C = ZC_ORDER_STATUS.ORDER_STATUS_C
	LEFT JOIN [EpicClarity].[dbo].ZC_LAB_STATUS on [ORDER_PROC].LAB_STATUS_C = ZC_LAB_STATUS.LAB_STATUS_C
	LEFT JOIN [EpicClarity].[dbo].	ZC_ORDER_CLASS on [ORDER_PROC].ORDER_CLASS_C = ZC_ORDER_CLASS.ORDER_CLASS_C
	LEFT JOIN [EpicClarity].[dbo].	ZC_ORDER_TYPE	 on [ORDER_PROC].ORDER_TYPE_C = ZC_ORDER_TYPE.ORDER_TYPE_C
LEFT JOIN [EpicClarity].[dbo].[CLARITY_MOD]
	ON [ORDER_PROC].[MODIFIER1_ID] = [CLARITY_MOD].[MODIFIER_ID]


WHERE (	order_proc.ORDER_STATUS_C = 5)