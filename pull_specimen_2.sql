use epiccare;
--TRUNCATE TABLE OMOP.specimen

IF EXISTS (SELECT NULL
		FROM INFORMATION_SCHEMA.TABLES
		WHERE TABLE_NAME = 'SPECIMEN_Clarity_ALL')
	DROP TABLE OMOP_Clarity.SPECIMEN_Clarity_ALL;

SELECT DISTINCT 
    SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID))                            AS person_id
    , isnull(source_to_concept_map_specimen.target_concept_id,0)                                 AS specimen_concept_id
    , 0                                                                                          AS specimen_type_concept_id
    , CONVERT(DATE, coalesce(SPEC_DB_MAIN.SPEC_DTM_COLLECTED, SPEC_DB_MAIN.SPEC_DTM_RECEIVED)) AS specimen_date
    , coalesce(SPEC_DB_MAIN.SPEC_DTM_COLLECTED, SPEC_DB_MAIN.SPEC_DTM_RECEIVED)                AS specimen_datetime
    , HSC_SPEC_INFO.SPECIMEN_SIZE                                                                AS quantity -- missing from HSC_SPEC_INFO
    , 0                                                                                          AS unit_concept_id -- missing from HSC_SPEC_INFO
    , isnull(source_to_concept_map_anatomic_site.target_concept_id,0)                            AS anatomic_site_concept_id
    , 0                                                                                          AS disease_status_concept_id -- unknown
    , HSC_SPEC_INFO.SPECIMEN_TYPE_C                                                              AS specimen_source_id   
    , ZC_SPECIMEN_TYPE.NAME                                                                      AS specimen_source_value
    , NULL                                                                                       AS unit_source_value -- missing from HSC_SPEC_INFO
    , ZC_SPEC_SOURCE.NAME                                                                      AS anatomic_site_source_value -->SPEC_DB_MAIN.SPEC_SOURCE_C
    , NULL                                                                                       AS disease_status_source_value  -- unknown
	,'SPECIMEN--ClarityHosp--ALL'																 AS ETL_Module
INTO OMOP_Clarity.SPECIMEN_Clarity_ALL
FROM EpicCare.OMOP.person
	INNER JOIN EpicCare.OMOP.AoU_Driver
		ON person.person_id = SUBSTRING(OMOP.AoU_Driver.AoU_ID, 2, LEN(OMOP.AoU_Driver.AoU_ID))
	INNER JOIN EpicClarity.dbo.SPEC_DB_MAIN
		ON SPEC_DB_MAIN.SPEC_EPT_PAT_ID = EpicCare.OMOP.AoU_Driver.Epic_Pat_id
	INNER JOIN EpicClarity.dbo.ZC_SPEC_SOURCE
		ON SPEC_DB_MAIN.SPEC_SOURCE_C = ZC_SPEC_SOURCE.SPEC_SOURCE_C
	--HSC_SPEC_INFO not yet in CLARITY--------
	INNER JOIN EpicClarity.dbo.HSC_SPEC_INFO
		ON SPEC_DB_MAIN.SPECIMEN_COL_ID = HSC_SPEC_INFO.RECORD_ID
	LEFT JOIN EpicClarity.dbo.ZC_SPECIMEN_TYPE
		ON HSC_SPEC_INFO.SPECIMEN_TYPE_C = ZC_SPECIMEN_TYPE.SPECIMEN_TYPE_C
	LEFT JOIN EpicClarity.dbo.ZC_SPECIMEN_UNIT
		ON HSC_SPEC_INFO.SPECIMEN_UNIT_C = ZC_SPECIMEN_UNIT.SPECIMEN_UNIT_C
	------- Source to Concept Mappings BEGIN---------
	LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_specimen
		ON HSC_SPEC_INFO.SPECIMEN_TYPE_C = source_to_concept_map_specimen.source_code
			AND source_to_concept_map_specimen.source_vocabulary_id = 'SH_specimen'
	LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_anatomic_site
		ON SPEC_DB_MAIN.SPEC_SOURCE_C = source_to_concept_map_anatomic_site.source_code
			AND source_to_concept_map_anatomic_site.source_vocabulary_id = 'SH_anatomic_site'
------- Source to Concept Mappings END ---------
WHERE coalesce(SPEC_DB_MAIN.SPEC_DTM_COLLECTED, SPEC_DB_MAIN.SPEC_DTM_RECEIVED) IS NOT NULL