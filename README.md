Insertion deletion order parameters:

We can't create a Visit for a Person until that person's record is created.  Likewise, we can't delete a Person until all of the person's Visit records have been deleted. This is, of course, only one of the many dependencies in the OMOP model.

Since we are doing a complete drop and add for our All of Us extracts, all the tables must be emptied (truncated) and then re-filled.

To summarize, deletion has to go from smallest granularity to the largest and the foundations have to exist for a visit occurrence to be recorded.

Deletion Order:

(Specimen, Observation, Device_Exposure, Procedure_Occurrence, Drug_Exposure, Measurement , Condition_occurrence)*  -->  Visit_Occurrence  -->  Death  -->  Person -->  Provider  --> Care_Site  -->  Location

Not surprisingly, the Insertion Order is just the reverse.

Insertion Order:

Location -->   Care_Site   --> Provider -->  Person   --> Death -->  Visit_Occurrence --> (Condition_Occurrence, Measurement, Drug_Exposure, Procedure_Occurrence, Device_Exposure,  Observation, Specimen)*

*Any order
