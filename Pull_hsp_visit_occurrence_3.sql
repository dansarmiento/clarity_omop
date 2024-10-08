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

Name: Pull_hsp_visit_occurrence_3

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_visit_occurrence_hsp_3. 

	Its purpose is to query data from Epic Clarity and append this data to VISIT_OCCURRENCE_ClarityHosp_ALL
	which will be used later in app_visit_occurrence_hsp_3.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	VISIT_OCCURRENCE_ClarityHosp_ALL may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;


IF EXISTS (	SELECT NULL
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'VISIT_OCCURRENCE_ClarityHosp_ALL')
	DROP TABLE OMOP_Clarity.VISIT_OCCURRENCE_ClarityHosp_ALL;


SELECT SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID)) AS person_id
	,OMOP.AoU_Driver.AoU_ID
	,pat_enc_hsp.PAT_ID
	,pat_enc_hsp.PAT_ENC_CSN_ID


	,pat_enc_hsp.ADT_PAT_CLASS_C
	, ZC_PAT_CLASS.NAME as ADT_PAT_CLASS_NAME

	,pat_enc_hsp.HOSP_ADMSN_TIME
	,PAT_ENC_HSP.INP_ADM_DATE
	,PAT_ENC_HSP.EXP_ADMISSION_TIME
	,PAT_ENC_HSP.OP_ADM_DATE
	,PAT_ENC_HSP.EMER_ADM_DATE
	,PAT_ENC_HSP.INSTANT_OF_ENTRY_TM

	,pat_enc_hsp.HOSP_DISCH_TIME
	,pat_enc_hsp.ED_DISP_TIME

	,pat_enc_hsp.HOSPITAL_AREA_ID
	,pat_enc_hsp.HSP_ACCOUNT_ID
	,pat_enc_hsp.INPATIENT_DATA_ID

	,pat_enc_hsp.IP_EPISODE_ID
	,pat_enc_hsp.ED_EPISODE_ID

	,pat_enc_hsp.ED_DISPOSITION_C
	, ZC_ED_DISPOSITION.NAME as ED_DISPOSITION_NAME

	,pat_enc_hsp.ADMIT_SOURCE_C
	,ZC_ADM_SOURCE.NAME AS ADMIT_SOURCE_NAME

	,pat_enc_hsp.DISCH_DISP_C
	,ZC_DISCH_DISP.NAME as DISCH_DISP_NAME

	,pat_enc_hsp.BILL_ATTEND_PROV_ID

	,pat_enc_hsp.ADT_PATIENT_STAT_C
	,ZC_PAT_STATUS.NAME AS ADT_PATIENT_STAT_NAME


	--, pat_enc_hsp.*

INTO OMOP_Clarity.VISIT_OCCURRENCE_ClarityHosp_ALL
FROM EpicClarity.dbo.PAT_ENC_HSP

	INNER JOIN OMOP.AoU_Driver
		ON pat_enc_hsp.PAT_ID = OMOP.AoU_Driver.Epic_Pat_id

	LEFT JOIN EpicClarity.dbo.ZC_PAT_CLASS
		ON pat_enc_hsp.ADT_PAT_CLASS_C = ZC_PAT_CLASS.ADT_PAT_CLASS_C

	LEFT JOIN EpicClarity.dbo.ZC_PAT_STATUS
		ON pat_enc_hsp.ADT_PATIENT_STAT_C = ZC_PAT_STATUS.ADT_PATIENT_STAT_C

	LEFT JOIN EpicClarity.dbo.ZC_ADM_SOURCE
		ON pat_enc_hsp.ADMIT_SOURCE_C = ZC_ADM_SOURCE.ADMIT_SOURCE_C

	LEFT JOIN EpicClarity.dbo.ZC_DISCH_DISP
		ON pat_enc_hsp.DISCH_DISP_C = ZC_DISCH_DISP.DISCH_DISP_C

	LEFT JOIN 	EpicClarity.dbo.ZC_ED_DISPOSITION
		ON pat_enc_hsp.ED_DISPOSITION_C	= ZC_ED_DISPOSITION.ED_DISPOSITION_C

WHERE HOSP_DISCH_TIME IS NOT NULL
	and HOSP_ADMSN_TIME IS NOT NULL

