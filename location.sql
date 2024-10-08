
-----------------------------------------------
-- PERSON LOCATIONS
-----------------------------------------------

INSERT INTO [OMOP].location (
	address_1
	,address_2
	,city
	,STATE
	,zip
	,county
	,location_source_value
	)

SELECT PATIENT.ADD_LINE_1 AS address_1
	,PATIENT.ADD_LINE_2 AS address_2
	,PATIENT.CITY AS city
	,LEFT(ZC_STATE.ABBR, 2) AS STATE
	,LEFT(PATIENT.ZIP, 5) AS zip
	,ZC_COUNTY.NAME AS county
	,LEFT(ISNULL(PATIENT.ADD_LINE_1, '') 
		+ ISNULL(PATIENT.ADD_LINE_2, '') 
		+ ISNULL(PATIENT.CITY, '') 
		+ ISNULL(ZC_STATE.STATE_C, '') 
		+ ISNULL(PATIENT.ZIP, '') 
		+ ISNULL(ZC_COUNTY.COUNTY_C, ''), 50) 
	AS location_source_value

FROM OMOP.AoU_Driver AS aou

INNER JOIN EpicClarity.dbo.PATIENT 
	ON PATIENT.PAT_ID = aou.Epic_Pat_id

LEFT OUTER JOIN EpicClarity.dbo.ZC_STATE
	ON PATIENT.STATE_C = ZC_STATE.STATE_C

LEFT OUTER JOIN EpicClarity.dbo.ZC_COUNTY
	ON PATIENT.COUNTY_C = ZC_COUNTY.COUNTY_C

-----------------------------------------------
-- CARE SITE LOCATIONS
-----------------------------------------------

INSERT INTO [OMOP].location (
	address_1
	,address_2
	,city
	,STATE
	,zip
	,county
	,location_source_value
	)

SELECT DISTINCT CLARITY_POS.[ADDRESS_LINE_1] AS address_1
	,CLARITY_POS.[ADDRESS_LINE_2] AS address_2
	,CLARITY_POS.CITY AS city
	,LEFT(ZC_STATE.ABBR, 2) AS STATE
	,LEFT(CLARITY_POS.ZIP, 5) AS zip
	,ZC_COUNTY.NAME AS county
	,LEFT(ISNULL(CLARITY_POS.[ADDRESS_LINE_1], '') 
		+ ISNULL(CLARITY_POS.[ADDRESS_LINE_2], '') 
		+ ISNULL(CLARITY_POS.CITY, '') 
		+ ISNULL(ZC_STATE.STATE_C, '') 
		+ ISNULL(CLARITY_POS.ZIP, '') 
		+ ISNULL(ZC_COUNTY.COUNTY_C, ''), 50) 
	AS location_source_value

FROM epiccare.OMOP.AoU_Driver AS aou

INNER JOIN EpicClarity.dbo.PAT_ENC
	ON pat_enc.PAT_ID = aou.Epic_Pat_id

INNER JOIN EpicClarity.dbo.CLARITY_DEP
	ON PAT_ENC.DEPARTMENT_ID = CLARITY_DEP.DEPARTMENT_ID

INNER JOIN EpicClarity.dbo.CLARITY_POS 
	ON CLARITY_DEP.REV_LOC_ID = CLARITY_POS.POS_ID

INNER JOIN EpicClarity.dbo.ZC_STATE
	ON CLARITY_POS.STATE_C = ZC_STATE.STATE_C

LEFT OUTER JOIN EpicClarity.dbo.ZC_COUNTY
	ON CLARITY_POS.COUNTY_C = ZC_COUNTY.COUNTY_C

