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

Name: Pull_amb_visit_occurrence_3

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
	
Description: This script is the 1st it a two-part process.  It is used in conjunction with 
	(and before) app_visit_occurrence_amb_f2f_3. 

	Its purpose is to query data from Epic Clarity and append this data to VISIT_OCCURRENCE_ClarityAMB_ALL
	which will be used later in app_visit_occurrence_amb_f2f_3.  The table may have numerous
	extraneous fields which can be used for verifying the base data returned from Clarity. 

	VISIT_OCCURRENCE_ClarityAMB_ALL may also be used in conjunction with other "APP_" scripts.

Structure: (if your structure is different, you will have to modify the code to match)
	Databases:EpicCare, EpicClarity
	Schemas: EpicClarity.dbo, EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;


IF EXISTS (	SELECT NULL
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'VISIT_OCCURRENCE_ClarityAMB_ALL')
	DROP TABLE OMOP_Clarity.VISIT_OCCURRENCE_ClarityAMB_ALL;

SELECT DISTINCT SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID)) AS person_id
	,AoU_ID
	,PAT_ENC.PAT_ID
	,PAT_ENC.PAT_ENC_CSN_ID

	,PAT_ENC.ENC_TYPE_C
	,ZC_DISP_ENC_TYPE.NAME AS ZC_DISP_ENC_TYPE_NAME

	,PAT_ENC.CHECKIN_TIME
	,PAT_ENC.APPT_TIME
	,PAT_ENC.[ENC_INSTANT]
	,PAT_ENC.CONTACT_DATE

	,PAT_ENC.[CHECKOUT_TIME]
	,PAT_ENC.ENC_CLOSE_TIME

	,PAT_ENC.ACCOUNT_ID
	,PAT_ENC.HSP_ACCOUNT_ID
	,PAT_ENC.INPATIENT_DATA_ID
	,PAT_ENC_2.IP_DOC_CONTACT_CSN
	,pat_or_adm_link.[PAT_ENC_CSN_ID] as pat_or_adm_link_csn

	,PAT_ENC.VISIT_PROV_ID
	,Visit_Provider.PROV_NAME AS Visit_Provider_NAME

	,PAT_ENC.PCP_PROV_ID
	,PCP_Provider.PROV_NAME AS PCP_Provider_NAME

	,PAT_ENC.PRIMARY_LOC_ID
	,CLARITY_LOC.LOC_NAME

	,PAT_ENC.CALCULATED_ENC_STAT_C
	,ZC_CALCULATED_ENC_STAT.NAME AS CALCULATED_ENC_STAT_NAME
	,PAT_ENC.APPT_STATUS_C
	,ZC_APPT_STATUS.NAME AS APPT_STATUS_NAME


INTO OMOP_Clarity.VISIT_OCCURRENCE_ClarityAMB_ALL
FROM EpicClarity.dbo.PAT_ENC_HSP --hosp

		right join EpicClarity.dbo.PAT_ENC_2 --hod_2
						on PAT_ENC_HSP.PAT_ENC_CSN_ID = PAT_ENC_2.IP_DOC_CONTACT_CSN

		inner join EpicClarity.dbo.PAT_ENC --hod
						on PAT_ENC_2.PAT_ENC_CSN_ID = PAT_ENC.PAT_ENC_CSN_ID
		LEFT JOIN EpicClarity.dbo.pat_or_adm_link
		ON PAT_ENC.PAT_ENC_CSN_ID = pat_or_adm_link.[PAT_ENC_CSN_ID]

	INNER JOIN OMOP.AoU_Driver
		ON EpicClarity.dbo.PAT_ENC.PAT_ID = OMOP.AoU_Driver.Epic_Pat_id

	LEFT JOIN EpicClarity.dbo.CLARITY_LOC
		ON PAT_ENC.PRIMARY_LOC_ID = CLARITY_LOC.LOC_ID

	LEFT JOIN EpicClarity.dbo.CLARITY_SER AS Visit_Provider
		ON PAT_ENC.VISIT_PROV_ID = Visit_Provider.PROV_ID

	LEFT JOIN EpicClarity.dbo.CLARITY_SER AS PCP_Provider
		ON PAT_ENC.PCP_PROV_ID = PCP_Provider.PROV_ID

	LEFT JOIN EpicClarity.dbo.ZC_DISP_ENC_TYPE
		ON PAT_ENC.ENC_TYPE_C = ZC_DISP_ENC_TYPE.DISP_ENC_TYPE_C

	LEFT JOIN EpicClarity.dbo.ZC_CALCULATED_ENC_STAT
		ON PAT_ENC.CALCULATED_ENC_STAT_C = ZC_CALCULATED_ENC_STAT.CALCULATED_ENC_STAT_C

	LEFT JOIN EpicClarity.dbo.ZC_APPT_STATUS
		ON EpicClarity.dbo.PAT_ENC.APPT_STATUS_C = ZC_APPT_STATUS.APPT_STATUS_C

WHERE enc_type_c <> 3

	AND (
		PAT_ENC.[CALCULATED_ENC_STAT_C] = 2
		OR PAT_ENC.[CALCULATED_ENC_STAT_C] IS NULL
		)
	AND (
		PAT_ENC.[APPT_STATUS_C] = 2
		OR PAT_ENC.APPT_STATUS_C IS NULL
		)



