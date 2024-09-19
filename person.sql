

INSERT INTO OMOP.person
       (person_id
            , gender_concept_id
            , year_of_birth
            , month_of_birth
            , day_of_birth
            , birth_datetime
            , race_concept_id
            , ethnicity_concept_id
            , location_id
            , provider_id
            , care_site_id
            , person_source_value
            , gender_source_value
            , gender_source_concept_id
            , race_source_value
            , race_source_concept_id
            , ethnicity_source_value
            , ethnicity_source_concept_id
       )
SELECT distinct
                SUBSTRING(aou.AoU_ID, 2, LEN(aou.AoU_ID))                        AS person_id
              , isnull(source_to_concept_map_gender.target_concept_id,0)         AS gender_concept_id
              , YEAR(pat.BIRTH_DATE)                                             AS year_of_birth
              , MONTH(pat.BIRTH_DATE)                                            AS month_of_birth
              , DAY(pat.BIRTH_DATE)                                              AS day_of_birth
              , pat.BIRTH_DATE													 AS birth_datetime
              , isnull(source_to_concept_map_race.target_concept_id,0)           AS race_concept_id
              , isnull(source_to_concept_map_ethnicity.target_concept_id,0)      AS ethnicity_concept_id
              , location.location_id                                             AS location_id
              , provider.provider_id                                             AS provider_id
              , pat.[CUR_PRIM_LOC_ID]                                            AS care_site_id
              , aou.AoU_ID                                                       AS person_source_value
              , CONVERT(VARCHAR(1), pat.SEX_C) + ':' + z_sex.NAME                AS gender_source_value
              , 0                                                                AS gender_source_concept_id
              , CONVERT(VARCHAR(1), z_race.PATIENT_RACE_C) + ':' + z_race.NAME   AS race_source_value
              , 0                                                                AS race_source_concept_id
              , CONVERT(VARCHAR(1), z_ethic.ETHNIC_GROUP_C) + ':' + z_ethic.NAME AS ethnicity_source_value
              , 0                                                                AS ethnicity_source_concept_id
FROM
                OMOP.AoU_Driver AS aou
                INNER JOIN
                                EpicClarity.dbo.PATIENT AS pat
                                ON
                                                pat.PAT_ID = aou.Epic_Pat_id

		 		left outer JOIN omop.provider ON pat.[CUR_PCP_PROV_ID] = provider.[provider_source_value]

                INNER JOIN
                                EpicClarity.dbo.PATIENT_RACE AS p_race
                                ON
                                                p_race.PAT_ID = pat.PAT_ID
                INNER JOIN
                                EpicClarity.dbo.ZC_PATIENT_RACE AS z_race
                                ON
                                                z_race.PATIENT_RACE_C = p_race.PATIENT_RACE_C
                INNER JOIN
                                EpicClarity.dbo.ZC_ETHNIC_GROUP AS z_ethic
                                ON
                                                z_ethic.ETHNIC_GROUP_C = pat.ETHNIC_GROUP_C
                INNER JOIN
                                EpicClarity.dbo.ZC_SEX AS z_sex
                                ON
                                                z_sex.RCPT_MEM_SEX_C = pat.SEX_C
                LEFT OUTER JOIN
                                EpicClarity.dbo.ZC_STATE
                                ON
                                                pat.STATE_C = ZC_STATE.STATE_C
                LEFT OUTER JOIN
                                EpicClarity.dbo.ZC_COUNTY
                                ON
                                                pat.COUNTY_C = ZC_COUNTY.COUNTY_C
				LEFT OUTER JOIN
                                OMOP.location 
                                ON
                                             LEFT(ISNULL(pat.ADD_LINE_1, '')
												+ ISNULL(pat.ADD_LINE_2, '')
												+ ISNULL(pat.CITY, '')
												+ ISNULL(LEFT(ZC_STATE.ABBR, 2), '')
												+ ISNULL(pat.ZIP, '')
												+ ISNULL(ZC_COUNTY.COUNTY_C, ''),50) = OMOP.location.[location_source_value]

                LEFT OUTER JOIN
                                OMOP.source_to_concept_map AS source_to_concept_map_gender
                                ON
                                                z_sex.RCPT_MEM_SEX_C  = source_to_concept_map_gender.source_code
                                                AND source_to_concept_map_gender.source_vocabulary_id = 'SH_gender'
                LEFT OUTER JOIN
                                OMOP.source_to_concept_map AS source_to_concept_map_race
                                ON
                                                source_to_concept_map_race.source_code = z_race.PATIENT_RACE_C
                                                AND source_to_concept_map_race.source_vocabulary_id = 'SH_race'
                LEFT OUTER JOIN
                                OMOP.source_to_concept_map AS source_to_concept_map_ethnicity
                                ON
                                                source_to_concept_map_ethnicity.source_code  = z_ethic.ETHNIC_GROUP_C
                                                AND source_to_concept_map_ethnicity.source_vocabulary_id = 'SH_ethnicity'

											
