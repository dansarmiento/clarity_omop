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
Name: app_visit_occurrence_hsp_3

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
		
Description: This script is the 2nd it a two-part process.  It is used in conjunction with 
	(and following) Pull_hsp_visit_occurrence_3. 

	Its purpose is to join the data in VISIT_OCCURRENCE_ClarityHosp_ALL to the OMOP concept table
	to return standard concept ids, and append this data to visit_occurrence.

Structure: (if your structure is different, you will have to modify the code to match)
	Database:EpicCare
	Schemas: EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

use EpicCare;


INSERT INTO OMOP.visit_occurrence
       (    person_id
            , visit_concept_id
            , visit_start_date
            , visit_start_datetime
            , visit_end_date
            , visit_end_datetime
            , visit_type_concept_id
            , provider_id
            , care_site_id
            , visit_source_value
            , visit_source_concept_id
            , admitting_source_concept_id
            , admitting_source_value
            , discharge_to_concept_id
            , discharge_to_source_value
            , preceding_visit_occurrence_id
			, ETL_Module
       )
SELECT DISTINCT 
                SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID))                     AS person_id
              , ISNULL(source_to_concept_map_visit.target_concept_id, 0)                              AS visit_concept_id
              , CONVERT(DATE, VISIT_OCCURRENCE_ClarityHosp_ALL.HOSP_ADMSN_TIME)                                            AS visit_start_date
              , VISIT_OCCURRENCE_ClarityHosp_ALL.HOSP_ADMSN_TIME                                                           AS visit_start_datetime
              , CONVERT(DATE, VISIT_OCCURRENCE_ClarityHosp_ALL.HOSP_DISCH_TIME)                                            AS visit_end_date
              , VISIT_OCCURRENCE_ClarityHosp_ALL.HOSP_DISCH_TIME                                                           AS visit_end_datetime
              , 44818518                                                                              AS visit_type_concept_id
              , provider.provider_id                                                                  AS provider_id
              , VISIT_OCCURRENCE_ClarityHosp_ALL.HOSPITAL_AREA_ID                                                          AS care_site_id
              , VISIT_OCCURRENCE_ClarityHosp_ALL.PAT_ENC_CSN_ID                                                            AS visit_source_value
              , ISNULL(source_to_concept_map_visit.target_concept_id, 0)                              AS visit_source_concept_id
              , ISNULL(source_to_concept_map_admit.target_concept_id, 0)                              AS admitting_source_concept_id
              , CONVERT(VARCHAR(1), VISIT_OCCURRENCE_ClarityHosp_ALL.ADMIT_SOURCE_C) + ':' + LEFT(ZC_ADM_SOURCE.NAME,48)   AS admitting_source_value
              , ISNULL(source_to_concept_map_discharge.target_concept_id, 0)                          AS discharge_to_concept_id
              , CONVERT(VARCHAR(1), VISIT_OCCURRENCE_ClarityHosp_ALL.DISCH_DISP_C) + ':' + LEFT(ZC_DISCH_DISP.NAME,48)     AS discharge_to_source_value
              , NULL                                                                                  AS preceding_visit_occurrence_id
			  , 'VISIT_OCCURRENCE--ClarityHosp--ALL'			  AS ETL_Module


FROM
                OMOP_Clarity.VISIT_OCCURRENCE_ClarityHosp_ALL
                INNER JOIN
                                OMOP.AoU_Driver
                                ON
                                                VISIT_OCCURRENCE_ClarityHosp_ALL.PAT_ID = OMOP.AoU_Driver.Epic_Pat_id
                left outer JOIN
                                omop.provider
                                ON
                                                VISIT_OCCURRENCE_ClarityHosp_ALL.BILL_ATTEND_PROV_ID = provider.[provider_source_value]
				inner JOIN	
								[OMOP].[care_site] 
								on 
												VISIT_OCCURRENCE_ClarityHosp_ALL.HOSPITAL_AREA_ID = [care_site].[care_site_id]
							
                INNER JOIN
                                EpicClarity.dbo.ZC_PAT_CLASS
                                ON
                                                VISIT_OCCURRENCE_ClarityHosp_ALL.ADT_PAT_CLASS_C = ZC_PAT_CLASS.ADT_PAT_CLASS_C
                INNER JOIN
                                EpicClarity.dbo.ZC_ADM_SOURCE
                                ON
                                                VISIT_OCCURRENCE_ClarityHosp_ALL.ADMIT_SOURCE_C = ZC_ADM_SOURCE.ADMIT_SOURCE_C
                INNER JOIN
                                EpicClarity.dbo.ZC_DISCH_DISP
                                ON
                                                VISIT_OCCURRENCE_ClarityHosp_ALL.DISCH_DISP_C = ZC_DISCH_DISP.DISCH_DISP_C
                LEFT OUTER JOIN
                                OMOP.source_to_concept_map AS source_to_concept_map_visit
                                ON
                                                source_to_concept_map_visit.source_code              = VISIT_OCCURRENCE_ClarityHosp_ALL.ADT_PAT_CLASS_C
                                                AND source_to_concept_map_visit.source_vocabulary_id = 'SH_visit'
                LEFT OUTER JOIN
                                OMOP.source_to_concept_map AS source_to_concept_map_admit
                                ON
                                                source_to_concept_map_admit.source_code              = VISIT_OCCURRENCE_ClarityHosp_ALL.ADMIT_SOURCE_C
                                                AND source_to_concept_map_admit.source_vocabulary_id = 'SH_admit'
                LEFT OUTER JOIN
                                OMOP.source_to_concept_map AS source_to_concept_map_discharge
                                ON
                                                source_to_concept_map_discharge.source_code              = VISIT_OCCURRENCE_ClarityHosp_ALL.DISCH_DISP_C
                                                AND source_to_concept_map_discharge.source_vocabulary_id = 'SH_discharge'
				LEFT JOIN  --visit date cannot be >30 days after death_date
                      OMOP.death
                      ON
                                 OMOP.death.person_id = SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID))
WHERE
                HOSP_DISCH_TIME is not null 
				and HOSP_ADMSN_TIME is not null
				and -- future visits removed
				HOSP_ADMSN_TIME < COALESCE(dateadd(day,30,death_date), GETDATE())