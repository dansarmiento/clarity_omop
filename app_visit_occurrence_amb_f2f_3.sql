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
Name: app_visit_occurrence_amb_f2f_3

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
		
Description: This script is the 2nd it a two-part process.  It is used in conjunction with 
	(and following )Pull_amb_visit_occurrence_3. 

	Its purpose is to join the data in VISIT_OCCURRENCE_ClarityAMB_ALL to the OMOP concept table
	to return standard concept ids, and append this data to visit_occurrence.

Structure: (if your structure is different, you will have to modify the code to match)
	Database:EpicCare
	Schemas: EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

use EpicCare;

------------------------------
-- HOD SURG ANES Records NOT removed
-------------------------------

INSERT INTO omop.visit_occurrence
       (person_id
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
      SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID))   AS person_id
    , ISNULL(source_to_concept_map_amb_visit.target_concept_id, 0)        AS visit_concept_id

	,CONVERT(DATE, 
			COALESCE(
				VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
				VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
				VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE))
																	AS visit_start_date

	,COALESCE(	
				VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
				VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
				VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE)
																	AS visit_start_datetime

	,CASE 
		WHEN COALESCE([CHECKOUT_TIME], 
					COALESCE(
							VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
							VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
							VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE))
				> COALESCE(
						VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
						VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
						VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE)
			THEN CONVERT(DATE, 
						COALESCE([CHECKOUT_TIME], 
								COALESCE(
										VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
										VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
										VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE)))
			ELSE CONVERT(DATE, 
						COALESCE(
								VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
								VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
								VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE))
		END															AS visit_end_date

	,CASE 
		WHEN COALESCE([CHECKOUT_TIME], 
					COALESCE(
							VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
							VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
							VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE)) 
				> COALESCE(
							VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
							VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
							VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE)
			THEN COALESCE([CHECKOUT_TIME], 
						COALESCE(
								VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
								VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
								VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE))
		ELSE COALESCE(
					VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
					VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
					VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE)
		END															AS visit_end_datetime      
		   
		, 44818518													AS visit_type_concept_id
         , OMOP.provider.provider_id
         , coalesce(VISIT_OCCURRENCE_ClarityAMB_ALL.PRIMARY_LOC_ID,1)		AS care_site_id
         , VISIT_OCCURRENCE_ClarityAMB_ALL.PAT_ENC_CSN_ID					AS visit_source_value
         , 0														AS visit_source_concept_id
         , 0														AS admitting_source_concept_id
         , NULL														AS admitting_source_value
         , 0														AS discharge_to_concept_id
         , NULL														AS discharge_to_source_value
         , NULL														AS preceding_visit_occurrence_id
         , 'VISIT_OCCURRENCE--ClarityAMB--ALL'						AS ETL_Module
FROM
           OMOP_Clarity.VISIT_OCCURRENCE_ClarityAMB_ALL
           INNER JOIN
                      OMOP.AoU_Driver
                      ON
                                 VISIT_OCCURRENCE_ClarityAMB_ALL.PAT_ID = OMOP.AoU_Driver.Epic_Pat_id
           INNER JOIN
                      [OMOP].[care_site]
                      ON
                                 VISIT_OCCURRENCE_ClarityAMB_ALL.PRIMARY_LOC_ID = OMOP.[care_site].care_site_id
           LEFT JOIN
                      OMOP.provider
                      ON
                                 VISIT_OCCURRENCE_ClarityAMB_ALL.VISIT_PROV_ID = OMOP.provider.provider_source_value           
			LEFT JOIN  --visit date cannot be >30 days after death_date
                      OMOP.death
                      ON
                                 OMOP.death.person_id = SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID))
           INNER JOIN
                      OMOP.source_to_concept_map AS source_to_concept_map_amb_visit
                      ON
                                 source_to_concept_map_amb_visit.source_code              = VISIT_OCCURRENCE_ClarityAMB_ALL.ENC_TYPE_C
                                 AND source_to_concept_map_amb_visit.source_vocabulary_id  IN('SH_amb_f2f')
WHERE	(
			-- remove cancelled visits
           ([CALCULATED_ENC_STAT_C] =2 or [CALCULATED_ENC_STAT_C] is null) 
			and
			([APPT_STATUS_C] = 2 or APPT_STATUS_C is null) 
			and -- future visits removed
			CONVERT(DATE, COALESCE(VISIT_OCCURRENCE_ClarityAMB_ALL.CHECKIN_TIME,
								VISIT_OCCURRENCE_ClarityAMB_ALL.APPT_TIME, 
								VISIT_OCCURRENCE_ClarityAMB_ALL.CONTACT_DATE)) 
							< COALESCE(dateadd(day,30,death_date), GETDATE())

           )


