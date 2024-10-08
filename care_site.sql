
WITH T_POS
AS (
	SELECT DISTINCT pos.*
	
	-- PCP physician PointOfService
	FROM OMOP.AoU_Driver AS aou
	
	INNER JOIN EpicClarity.dbo.PATient
		ON PATIENT.PAT_ID = aou.Epic_Pat_id
	
	INNER JOIN EpicClarity.dbo.CLARITY_POS AS pos
		ON PATIENT.[CUR_PRIM_LOC_ID] = pos.POS_ID
	
	
	UNION
	
	--Encounter physician PointOfService
	SELECT DISTINCT pos.*
	
	FROM OMOP.AoU_Driver AS aou
	
	INNER JOIN EpicClarity.dbo.PAT_ENC
		ON pat_enc.PAT_ID = aou.Epic_Pat_id
	
	INNER JOIN EpicClarity.dbo.CLARITY_DEP
		ON PAT_ENC.DEPARTMENT_ID = CLARITY_DEP.DEPARTMENT_ID
	
	INNER JOIN EpicClarity.dbo.CLARITY_POS AS pos
		ON CLARITY_DEP.REV_LOC_ID = pos.POS_ID
	)

INSERT INTO [OMOP].[care_site] (
	[care_site_id]
	,[care_site_name]
	,[place_of_service_concept_id]
	,[location_id]
	,[care_site_source_value]
	,[place_of_service_source_value]
	)

SELECT DISTINCT T_POS.[POS_ID] AS care_site_id
	,T_POS.POS_NAME AS care_site_name
	,0 AS place_of_service_concept_id
	,loc.location_id AS location_id
	,left(convert(VARCHAR(20), T_POS.[POS_ID]) + ':' + T_POS.POS_NAME, 50) AS care_site_source_value
	,NULL AS place_of_service_source_value

FROM T_POS

	INNER JOIN EpicClarity.dbo.ZC_STATE
		ON T_POS.STATE_C = ZC_STATE.STATE_C

	LEFT OUTER JOIN EpicClarity.dbo.ZC_COUNTY
		ON T_POS.COUNTY_C = ZC_COUNTY.COUNTY_C

	LEFT JOIN epiccare.OMOP.location AS loc
		ON loc.location_source_value = LEFT(ISNULL(T_POS.[ADDRESS_LINE_1], '') 
										+ ISNULL(T_POS.[ADDRESS_LINE_2], '') 
										+ ISNULL(T_POS.CITY, '') 
										+ ISNULL(LEFT(ZC_STATE.ABBR, 2), '') 
										+ ISNULL(T_POS.ZIP, '') 
										+ ISNULL(ZC_COUNTY.COUNTY_C, ''), 50)

