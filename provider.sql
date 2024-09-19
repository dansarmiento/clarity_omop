INSERT INTO OMOP.provider (
	[provider_id]
	,[provider_name]
	,[NPI]
	,[DEA]
	,[specialty_concept_id]
	,[care_site_id]
	,[year_of_birth]
	,[gender_concept_id]
	,[provider_source_value]
	,[specialty_source_value]
	,[specialty_source_concept_id]
	,[gender_source_value]
	,[gender_source_concept_id]
	)

SELECT CLARITY_SER.PROV_ID AS [provider_id]
	,CLARITY_SER.[PROV_NAME] AS [provider_name]
	,CLARITY_SER_2.[NPI] AS [NPI]
	,DEA_NUMBER AS [DEA]
	,isnull(source_to_concept_map_specialty.target_concept_id, 0) AS [specialty_concept_id]
	,care_site.care_site_id AS [care_site_id]
	,YEAR(BIRTH_DATE) AS [year_of_birth]
	,isnull(source_to_concept_map_gender.target_concept_id, 0) AS [gender_concept_id]
	,CLARITY_SER.PROV_ID AS [provider_source_value]
	,LEFT(ZC_SPECIALTY.NAME, 50) AS [specialty_source_value]
	,0 AS [specialty_source_concept_id]
	,CONVERT(VARCHAR(1), CLARITY_SER.SEX_C) + ':' + ZC_SEX.NAME AS [gender_source_value]
	,0 AS [gender_source_concept_id]


FROM EpicClarity.dbo.CLARITY_SER

	INNER JOIN EpicClarity.dbo.CLARITY_EMP
		ON CLARITY_SER.PROV_ID = CLARITY_EMP.PROV_ID

	INNER JOIN EpicClarity.dbo.CLARITY_DEP
		ON CLARITY_EMP.LGIN_DEPARTMENT_ID = CLARITY_DEP.DEPARTMENT_ID

	INNER JOIN EpicClarity.dbo.ZC_SEX
		ON ZC_SEX.RCPT_MEM_SEX_C = CLARITY_SER.SEX_C

	INNER JOIN EpicClarity.dbo.CLARITY_SER_2
		ON CLARITY_SER.PROV_ID = CLARITY_SER_2.PROV_ID

	LEFT JOIN OMOP.care_site
		ON CLARITY_DEP.REV_LOC_ID = care_site.care_site_id

	INNER JOIN OMOP.source_to_concept_map AS source_to_concept_map_gender
		ON ZC_SEX.RCPT_MEM_SEX_C = source_to_concept_map_gender.source_code
			AND source_to_concept_map_gender.source_vocabulary_id = 'SH_gender'

	LEFT OUTER JOIN [EpicClarity].[dbo].[D_PROV_PRIMARY_HIERARCHY]
		ON CLARITY_SER.PROV_ID = [D_PROV_PRIMARY_HIERARCHY].PROV_ID

	LEFT OUTER JOIN OMOP.source_to_concept_map AS source_to_concept_map_specialty

	LEFT OUTER JOIN [EpicClarity].[dbo].ZC_SPECIALTY
		ON ZC_SPECIALTY.SPECIALTY_C = source_to_concept_map_specialty.source_code
			AND source_to_concept_map_specialty.source_vocabulary_id = 'SH_specialty'
			ON [D_PROV_PRIMARY_HIERARCHY].SPECIALTY_C = ZC_SPECIALTY.SPECIALTY_C 
								 
where
           CLARITY_SER.ACTIVE_STATUS_C = 1 --Active
		   		   AND ISNUMERIC(CLARITY_SER.PROV_ID)=1
