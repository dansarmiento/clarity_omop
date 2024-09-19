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
IF EXISTS (
        SELECT NULL
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_NAME = 'VISIT_DETAIL_ClarityHosp_ALL'
        )
    DROP TABLE OMOP_Clarity.VISIT_DETAIL_ClarityHosp_ALL;
SELECT DISTINCT SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID)) AS person_id
    , OMOP.AoU_Driver.AoU_ID
    , pat_enc_hsp.PAT_ID
    , pat_enc_hsp.PAT_ENC_CSN_ID
    , RANK() OVER (
        PARTITION BY pat_enc_hsp.PAT_ENC_CSN_ID ORDER BY A.SEQ_NUM_IN_ENC
            , A.EFFECTIVE_TIME
        ) AS ra
    , ROW_NUMBER() OVER (
        ORDER BY pat_enc_hsp.PAT_ENC_CSN_ID
            , A.SEQ_NUM_IN_ENC
            , A.EFFECTIVE_TIME
        ) AS visit_detail_id

    , PAT_ENC_HSP.HOSP_ADMSN_TYPE_C
    , A.PAT_SERVICE_C
    
    , pat_enc_hsp.ADT_PAT_CLASS_C 
    ,ZC_PAT_CLASS.NAME as adt_pat_class_name
    ,  A.PAT_LVL_OF_CARE_C --used for VISIT_DETAIL_SOURCE_VALUE WHEN ICU 

    
--used for VISIT_DETAIL_SOURCE_CONCEPT
    , CASE 
        WHEN A.PAT_LVL_OF_CARE_C = 6
            THEN 9999 -- ICU
        ELSE pat_enc_hsp.ADT_PAT_CLASS_C
        END AS VISIT_DETAIL_SOURCE_CONCEPT --used for VISIT_DETAIL_SOURCE_CONCEPT_ID WHEN ICU 
        
  --used for VISIT_DETAIL_SOURCE_VALUE
    , CASE 
        WHEN PRC_NAME IS NOT NULL
            THEN CONVERT(VARCHAR(50), DP.DEPARTMENT_NAME + '_' + PRC_NAME)
        WHEN A.ROOM_ID IS NOT NULL
            AND S.NAME IS NOT NULL
            THEN DP.DEPARTMENT_NAME + '_' + A.ROOM_ID + '_' + A.BED_ID + '_' + S.NAME
        ELSE CONVERT(VARCHAR(50), DP.DEPARTMENT_NAME)
        END AS VISIT_DETAIL_SOURCE_VALUE
        
    --admit times
    , pat_enc_hsp.HOSP_ADMSN_TIME
    , PAT_ENC_HSP.INP_ADM_DATE
    , PAT_ENC_HSP.EXP_ADMISSION_TIME
    , PAT_ENC_HSP.OP_ADM_DATE
    , PAT_ENC_HSP.EMER_ADM_DATE
    , PAT_ENC_HSP.INSTANT_OF_ENTRY_TM
    , A.EFFECTIVE_TIME AS A_EFFECTIVE_TIME
    , PAT_ENC.CHECKIN_TIME
    , PAT_ENC.APPT_TIME
    , pat_enc_hsp.CONTACT_DATE
    --discharge times
    , pat_enc_hsp.HOSP_DISCH_TIME
    , pat_enc_hsp.ED_DISP_TIME
    , B.EFFECTIVE_TIME AS B_EFFECTIVE_TIME
    , PAT_ENC.CHECKOUT_TIME
    , pat_enc_hsp.HOSPITAL_AREA_ID
    , pat_enc_hsp.HSP_ACCOUNT_ID
    , pat_enc_hsp.INPATIENT_DATA_ID
    , pat_enc_hsp.IP_EPISODE_ID
    , pat_enc_hsp.ED_EPISODE_ID
    , pat_enc_hsp.ED_DISPOSITION_C
    , ZC_ED_DISPOSITION.NAME AS ED_DISPOSITION_NAME
    , pat_enc_hsp.ADMIT_SOURCE_C
    , ZC_ADM_SOURCE.NAME AS ADMIT_SOURCE_NAME
    , pat_enc_hsp.DISCH_DISP_C
    , ZC_DISCH_DISP.NAME AS DISCH_DISP_NAME
    , pat_enc_hsp.BILL_ATTEND_PROV_ID
    , pat_enc_hsp.ADT_PATIENT_STAT_C
    , ZC_PAT_STATUS.NAME AS ADT_PATIENT_STAT_NAME
    , HSP_ACCOUNT.ATTENDING_PROV_ID
    , HSP_ACCOUNT.REFERRING_PROV_ID
    , HSP_ACCOUNT.ADM_DATE_TIME
    , HSP_ACCOUNT.DISCH_DATE_TIME
    , DP.DEPARTMENT_NAME
    , PRC_NAME
    , A.ROOM_ID
    , A.BED_ID
    , S.NAME AS HOSP_SERV_NAME

    , pat_enc_hsp.PAT_ENC_CSN_ID AS VISIT_SOURCE_VALUE
INTO OMOP_Clarity.VISIT_DETAIL_ClarityHosp_ALL
FROM EpicClarity.dbo.PAT_ENC_HSP
INNER JOIN EpicClarity.dbo.PAT_ENC
    ON pat_enc_hsp.PAT_ENC_CSN_ID = PAT_ENC.PAT_ENC_CSN_ID
INNER JOIN OMOP.AoU_Driver
    ON pat_enc_hsp.PAT_ID = OMOP.AoU_Driver.Epic_Pat_id
LEFT JOIN EpicClarity.dbo.CLARITY_ADT A(NOLOCK)
    ON pat_enc_hsp.PAT_ENC_CSN_ID = A.PAT_ENC_CSN_ID
        AND A.EVENT_TYPE_C NOT IN (4, 5, 6)
        AND A.SEQ_NUM_IN_ENC IS NOT NULL
INNER JOIN EpicClarity.dbo.CLARITY_ADT B(NOLOCK)
    ON A.PAT_ID = B.PAT_ID
        AND A.PAT_ENC_CSN_ID = B.PAT_ENC_CSN_ID
        AND B.EVENT_TYPE_C IN (2, 4)
        AND B.EVENT_ID IN (A.NEXT_OUT_EVENT_ID)
LEFT JOIN EpicClarity.dbo.ZC_PAT_CLASS
    ON pat_enc_hsp.ADT_PAT_CLASS_C = ZC_PAT_CLASS.ADT_PAT_CLASS_C
LEFT JOIN EpicClarity.dbo.ZC_PAT_STATUS
    ON pat_enc_hsp.ADT_PATIENT_STAT_C = ZC_PAT_STATUS.ADT_PATIENT_STAT_C
LEFT JOIN EpicClarity.dbo.ZC_ADM_SOURCE
    ON pat_enc_hsp.ADMIT_SOURCE_C = ZC_ADM_SOURCE.ADMIT_SOURCE_C
LEFT JOIN EpicClarity.dbo.ZC_DISCH_DISP
    ON pat_enc_hsp.DISCH_DISP_C = ZC_DISCH_DISP.DISCH_DISP_C
LEFT JOIN EpicClarity.dbo.ZC_ED_DISPOSITION
    ON pat_enc_hsp.ED_DISPOSITION_C = ZC_ED_DISPOSITION.ED_DISPOSITION_C
LEFT JOIN EpicClarity.dbo.HSP_ACCOUNT
    ON PAT_ENC_HSP.HSP_ACCOUNT_ID = HSP_ACCOUNT.HSP_ACCOUNT_ID
LEFT JOIN EpicClarity.dbo.CLARITY_DEP DP
    ON PAT_ENC_HSP.DEPARTMENT_ID = DP.DEPARTMENT_ID
LEFT JOIN EpicClarity.dbo.CLARITY_PRC PR
    ON PR.PRC_ID = PAT_ENC.APPT_PRC_ID
LEFT JOIN EpicClarity.dbo.ZC_PAT_SERVICE S
    ON A.PAT_SERVICE_C = S.HOSP_SERV_C
WHERE HOSP_DISCH_TIME IS NOT NULL
    --
    --AND   A.PAT_LVL_OF_CARE_C = 6
