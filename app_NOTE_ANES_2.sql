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
Name: app_NOTE_ANES_2.sql

Author: Roger Carlson
		Spectrum Health
		roger.carlson@spectrumhealth.org

Last Revised: 14-June-2020
		
Description: This script is the 2nd it a two-part process.  It is used in conjunction with 
	(and following) pull_NOTE_ANES_2.sql. 

	Its purpose is to join the data in [OMOP_Clarity].[NOTE_ClarityANES_ALL] to the OMOP concept table
	to return standard concept ids, and append this data to [OMOP].[note].

Structure: (if your structure is different, you will have to modify the code to match)
	Database:EpicCare
	Schemas: EpicCare.OMOP, EpicCare.OMOP_Clarity

Note: I don't use aliases unless necessary for joining. I find them more confusing than helpful.

********************************************************************************/

USE EpicCare;

WITH T_max_note_date
AS (
	SELECT NOTE_ID
		,LINE AS line
		,MAX([CONTACT_DATE_REAL]) AS max_CONTACT_DATE_REAL
	
	FROM  OMOP_Clarity.NOTE_ClarityANES_ALL
	
	GROUP BY NOTE_ID
		,LINE
	)


INSERT INTO [EpicCare].[OMOP].[note] (
	-- note_id--Identity
	person_id
	,note_date
	,note_datetime
	,note_type_concept_id
	,note_class_concept_id
	,note_title
	,note_text
	,encoding_concept_id
	,language_concept_id
	,provider_id
	,visit_occurrence_id
	,note_source_value
	,ETL_Module
	)

SELECT  DISTINCT --[HNO_INFO].[NOTE_ID]
	NOTE_ClarityANES_ALL.person_id
	,CONVERT(DATE, NOTE_ClarityANES_ALL.[ENTRY_INSTANT_DTTM]) AS note_date
	,NOTE_ClarityANES_ALL.[ENTRY_INSTANT_DTTM] AS note_datetime
	,isnull(source_to_concept_map_note_type.target_concept_id, 0) AS note_type_concept_id
	,0 AS note_class_concept_id
	,NOTE_ClarityANES_ALL.ZC_NOTE_TYPE_IP_NAME AS note_title

	-- ******************************************
	  ,'NO_TEXT' AS note_text	-- No actual text is being written at this time over PHI concerns
	--,NOTE_ClarityHosp_ALL.Note_TEXT AS note_text
	-- ******************************************

	,0 AS encoding_concept_id
	,4180186 AS language_concept_id
	,provider.provider_id AS provider_id
	,visit_occurrence.[visit_occurrence_id] AS visit_occurrence_id
	,NOTE_ClarityANES_ALL.TYPE_IP_C + ':' + NOTE_ClarityANES_ALL.AMB_NOTE_YN + ':' + ZC_NOTE_TYPE_IP_NAME AS note_source_value
	,'NOTE--ClarityANES--ALL' AS ETL_Module

FROM OMOP_Clarity.NOTE_ClarityANES_ALL


INNER JOIN T_max_note_date
	ON NOTE_ClarityANES_ALL.[NOTE_ID] = T_max_note_date.[NOTE_ID]
	AND NOTE_ClarityANES_ALL.LINE= T_max_note_date.LINE

LEFT JOIN OMOP.source_to_concept_map AS source_to_concept_map_note_type
	ON NOTE_ClarityANES_ALL.IP_NOTE_TYPE_C + NOTE_ClarityANES_ALL.AMB_NOTE_YN = source_to_concept_map_note_type.source_code
		AND source_to_concept_map_note_type.source_vocabulary_id = 'SH_note_type'

INNER JOIN omop.visit_occurrence
	ON NOTE_ClarityANES_ALL.PAT_ENC_CSN_ID = visit_occurrence.[visit_source_value]

LEFT JOIN omop.provider
	ON NOTE_ClarityANES_ALL.visit_PROV_ID = provider.[provider_source_value]

WHERE [ENTRY_INSTANT_DTTM] IS NOT NULL
	AND NOTE_ClarityANES_ALL.line = 1

