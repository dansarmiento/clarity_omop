use epiccare;
--TRUNCATE TABLE OMOP.specimen

INSERT INTO OMOP.specimen (
	person_id
	, specimen_concept_id
	, specimen_type_concept_id
	, specimen_date
	, specimen_datetime
	, quantity
	, unit_concept_id
	, anatomic_site_concept_id
	, disease_status_concept_id
	, specimen_source_id
	, specimen_source_value
	, unit_source_value
	, anatomic_site_source_value
	, disease_status_source_value
	, ETL_Module
	)
SELECT DISTINCT person_id
	, specimen_concept_id
	, 32817 AS specimen_type_concept_id
	, specimen_date
	, specimen_datetime
	, quantity
	, unit_concept_id
	, anatomic_site_concept_id
	, disease_status_concept_id
	, specimen_source_id
	, specimen_source_value
	, unit_source_value
	, anatomic_site_source_value
	, disease_status_source_value
	, ETL_Module
FROM OMOP_Clarity.SPECIMEN_Clarity_ALL