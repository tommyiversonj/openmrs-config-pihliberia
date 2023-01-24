set sql_safe_updates = 0;

select encounter_type_id into @ncd_initial from encounter_type where uuid = 'ae06d311-1866-455b-8a64-126a9bd74171';
select encounter_type_id into @ncd_followup from encounter_type where uuid = '5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c';

drop temporary table if exists temp_ncd_encounters;
create temporary table temp_ncd_encounters
(
person_id int,
emr_id varchar(255),
encounter_id int,
encounter_datetime date,
reason_for_referral  text,
internal_patient_referral varchar(255),
external_patient_referral varchar(255),
other_internal_site varchar(255),
other_external_site varchar(255),
other_external_non_pih_site varchar(255),
date_of_referral date,
symptoms_duration int,
symptoms_duration_unit varchar(255),
unknown_symptoms_duration varchar(225),
patient_ever_been_hospitalized_for_these_symptoms varchar(225),
total_number_of_hospitalizations int,
Last_date_of_admission date,
has_the_patient_ever_received_medication_for_symptoms varchar(225),
has_the_patient_recently_taken_medication varchar(225),
visit_to_churchyard_or_traditional_healer varchar(225),
what_was_the_diagnosis_and_treatment varchar(255),
has_the_patient_delivered_within_the_past_five_years varchar(225),
number_of_times_with_big_belly int,
how_many_children_has_she_born int,
any_problems_during_big_belly varchar (255),
did_her_symptoms_start_around_the_time_of_delivery varchar (225),
patient_has_cough_more_than_two_weeks varchar(225),
type_of_cough varchar(225),
patient_has_fever_and_night_sweats_more_than_two_weeks varchar(225),
patient_has_weight_loss_in_less_than_four_months varchar(225),
type_of_weight_loss varchar(225),
does_the_patient_smoke varchar(225),
type_of_tobacco_product varchar(225),
how_many_cigs_or_pipes_per_day int,
does_the_patient_drink_alcohol varchar(225),
type_of_alcohol_product varchar(225),
how_many_modern_bottles_per_day int,
how_many_traditional_bottles_per_day int,
past_medication_or_drug_allergy varchar(25),
medication_side_effect text,
other_relevant_history text,
work_for_income varchar(50),
household_number_of_persons int,
transportation_to_clinic_today varchar(120),
time_to_travel_to_clinic int,
clinic_travel_time_unit varchar(30),
cost_of_transport int, 
times_do_you_eat_daily int,
normal_general_exam varchar(255),
abnormal_general_exam varchar(255),
other_general_exam text,
normal_heent_exam varchar(255),
abnormal_heent_exam varchar(255),
other_heent_exam text,
normal_lungs_exam varchar(255),
abnormal_lungs_exam varchar(255),
loc_crackles text,
other_lungs_exam text,
normal_heart_exam varchar(255),
abnormal_heart_exam varchar(255),
other_heart_exam text, 
normal_abdomen_exam varchar(255),
abnormal_abdomen_exam varchar(255),
other_abdomen_exam text,
normal_neuro_exam varchar(255),
abnormal_neuro_exam varchar(255),
other_neuro_exam text,
normal_extremities_exam varchar(255),
abnormal_extremities_exam varchar(255),
other_extremities_exam text,
social_welfare varchar(255),
disposition varchar(255),
disposition_comments text,
chw varchar(255),
chw_to_visit int,
chw_to_visit_freq varchar(255)
);

insert into temp_ncd_encounters (
person_id,
encounter_id,
encounter_datetime
) select patient_id, encounter_id, date(encounter_datetime) from encounter where voided = 0 and
encounter_type in (@ncd_initial, @ncd_followup) 
and (date(encounter_datetime) >= date(@startDate))
and (date(encounter_datetime) <= date(@endDate));

UPDATE temp_ncd_encounters SET emr_id = PATIENT_IDENTIFIER(person_id, METADATA_UUID('org.openmrs.module.emrapi', 'emr.primaryIdentifierType')); 

-- Reason for Referral
update temp_ncd_encounters tn set reason_for_referral = obs_value_text(tn.encounter_id,'CIEL', '160531');

-- Internal institution
update temp_ncd_encounters tn set
internal_patient_referral = (select group_concat(concept_name(value_coded, 'en') separator ' | ') from obs o where o.encounter_id = tn.encounter_id and 
voided = 0 and concept_id = concept_from_mapping('PIH', 'Type of referring service') and
value_coded in (
concept_from_mapping('CIEL', '160542'),
concept_from_mapping('CIEL', '160473'),
concept_from_mapping('CIEL', '160448'),
concept_from_mapping('CIEL', '165048'),
concept_from_mapping('PIH', 'MATERNITY WARD'),
concept_from_mapping('PIH', 'OTHER')));

-- External Institution
update temp_ncd_encounters tn set
external_patient_referral = (select group_concat(concept_name(value_coded, 'en') separator ' | ') from obs o where o.encounter_id = tn.encounter_id and 
voided = 0 and concept_id = concept_from_mapping('PIH', 'Type of referring service') and
value_coded in (
concept_from_mapping('PIH','Non-ZL supported site'),
concept_from_mapping('PIH','11956')));

-- Other institutions
update temp_ncd_encounters tn set other_internal_site =
obs_comments(tn.encounter_id, 'PIH', 'Type of referring service', 'PIH', 'OTHER');
update temp_ncd_encounters tn set other_external_site =
obs_comments(tn.encounter_id, 'PIH', 'Type of referring service', 'PIH','11956');
update temp_ncd_encounters tn set other_external_non_pih_site =
obs_comments(tn.encounter_id, 'PIH', 'Type of referring service', 'PIH', 'Non-ZL supported site');

-- Date of referral
update temp_ncd_encounters tn set date_of_referral = obs_value_datetime(tn.encounter_id, 'CIEL', '163181');

-- Duration of symptoms 
update temp_ncd_encounters tn set symptoms_duration = obs_value_numeric(tn.encounter_id, 'CIEL','1731');

-- Duration unit
-- update temp_ncd_encounters tn set symptoms_duration_unit = obs_value_coded_list(tn.encounter_id, 'CIEL','1732', 'en');
update temp_ncd_encounters tn left join obs o on o.voided = 0 and tn.encounter_id = o.encounter_id and concept_id = concept_from_mapping('CIEL','1732')
and obs_group_id in (select obs_id from obs where voided = 0 and concept_id = concept_from_mapping('CIEL','1727'))
set symptoms_duration_unit = concept_name(o.value_coded, 'en') ;

-- Unknow symptoms durations
-- update temp_ncd_encounters tn set unknown_symptoms_duration = obs_value_text(tn.encounter_id,'CIEL', '1067');
update temp_ncd_encounters tn left join obs o on o.voided = 0 and tn.encounter_id = o.encounter_id and value_coded = concept_from_mapping('CIEL','1067')
and obs_group_id in (select obs_id from obs where voided = 0 and concept_id = concept_from_mapping('CIEL','1727'))
set unknown_symptoms_duration = concept_name(o.value_coded, 'en');

-- Patient ever been hospitalized for these symptoms
update temp_ncd_encounters tn set patient_ever_been_hospitalized_for_these_symptoms = obs_value_coded_list(tn.encounter_id, 'CIEL','163403', 'en');

-- Total number of hospitalization
update temp_ncd_encounters tn set total_number_of_hospitalizations = obs_value_numeric(tn.encounter_id, 'CIEL','1773');

-- Last date of admission
update temp_ncd_encounters tn set Last_date_of_admission = obs_value_datetime(tn.encounter_id, 'PIH', '12602');

-- Has the patient ever received medication for symptoms
update temp_ncd_encounters tn set has_the_patient_ever_received_medication_for_symptoms = obs_value_coded_list(tn.encounter_id, 'PIH','12603', 'en');

-- Patient recently taken medication
update temp_ncd_encounters tn set has_the_patient_recently_taken_medication = obs_value_coded_list(tn.encounter_id, 'PIH','12604', 'en');

-- Patient ever been to the church yard or seen a traditional healer for these symptoms
-- What was the diagnosis and treatment
update temp_ncd_encounters tn set visit_to_churchyard_or_traditional_healer = obs_value_coded_list(tn.encounter_id, 'PIH','12605', 'en');

update temp_ncd_encounters tn set what_was_the_diagnosis_and_treatment = obs_value_text(tn.encounter_id,'PIH', '12606');
-- Has the patient delivered within the past 5 years
update temp_ncd_encounters tn set has_the_patient_delivered_within_the_past_five_years = obs_value_coded_list(tn.encounter_id, 'PIH','12722', 'en');

-- Number of times with big belly
update temp_ncd_encounters tn set number_of_times_with_big_belly = obs_value_numeric(tn.encounter_id, 'CIEL','5624');

-- How many children has she born
update temp_ncd_encounters tn set how_many_children_has_she_born = obs_value_numeric(tn.encounter_id, 'CIEL','1053');

-- Any problems during big belly with
update temp_ncd_encounters tn set any_problems_during_big_belly = obs_value_coded_list(tn.encounter_id, 'CIEL','160079', 'en');

 -- Did her symptoms start around the time of delivery
 update temp_ncd_encounters tn set did_her_symptoms_start_around_the_time_of_delivery = obs_value_coded_list(tn.encounter_id, 'PIH','12733', 'en');

-- past medication
-- create temporary table temp_past_medications
-- as (select concept_id, ons_datetime, value_conded, ) where encounter_id in (select encounter_id from temp_ncd_encounters)

-- Cough > 2 weeks
update temp_ncd_encounters tn set patient_has_cough_more_than_two_weeks = obs_value_coded_list(tn.encounter_id, 'PIH', '1065', 'en');
/*
-- Cough type
update temp_ncd_encounters tn set type_of_cough = obs_value_coded_list(tn.encounter_id, 'PIH','11563', 'en');

-- Fever and night sweats > 2 weeks
update temp_ncd_encounters tn set patient_has_fever_and_night_sweats_more_than_two_weeks = obs_value_coded_list(tn.encounter_id, 'PIH', '1065', 'en');

-- Weight loss > 3kg in less than 4 months
update temp_ncd_encounters tn set patient_has_weight_loss_in_less_than_four_months = obs_single_value_coded(tn.encounter_id, 'PIH', '1065', 'PIH', '1066', 'PIH', '1067');
*/
-- Type of weight loss
update temp_ncd_encounters tn set type_of_weight_loss = obs_value_coded_list(tn.encounter_id, 'PIH','11563', 'en');

-- Does the patient smoke
update temp_ncd_encounters tn set does_the_patient_smoke = obs_value_coded_list(tn.encounter_id, 'CIEL','163731', 'en');

-- Type of tobacco product
update temp_ncd_encounters tn set type_of_tobacco_product = obs_value_coded_list(tn.encounter_id, 'CIEL','159377', 'en');

-- How many cigs or pipes per day
update temp_ncd_encounters tn set how_many_cigs_or_pipes_per_day = obs_value_numeric(tn.encounter_id, 'CIEL','1546');

-- Does the patient drink alcohol
update temp_ncd_encounters tn set does_the_patient_drink_alcohol = obs_value_coded_list(tn.encounter_id, 'CIEL','159449', 'en');

-- Type of alcohol
update temp_ncd_encounters tn set type_of_alcohol_product = obs_value_coded_list(tn.encounter_id, 'CIEL','159453', 'en');

-- How many modern bottles per day?
update temp_ncd_encounters tn set how_many_modern_bottles_per_day = obs_value_numeric(tn.encounter_id, 'PIH','6136');

-- How many traditional liters per day?
update temp_ncd_encounters tn set how_many_traditional_bottles_per_day = obs_value_numeric(tn.encounter_id, 'PIH','6135');

-- past medical history
update temp_ncd_encounters tn set past_medication_or_drug_allergy = obs_value_coded_list(tn.encounter_id, 'CIEL','165273', 'en');
update temp_ncd_encounters tn set medication_side_effect = obs_value_text(tn.encounter_id, 'CIEL','164377');
update temp_ncd_encounters tn set other_relevant_history = obs_value_text(tn.encounter_id, 'CIEL','160632');

-- social history
update temp_ncd_encounters tn set work_for_income = obs_value_coded_list(tn.encounter_id, 'PIH','12615', 'en');
update temp_ncd_encounters tn set  household_number_of_persons = obs_value_numeric(tn.encounter_id, 'CIEL','1474');
update temp_ncd_encounters tn set transportation_to_clinic_today = obs_value_coded_list(tn.encounter_id, 'PIH','975', 'en');
update temp_ncd_encounters tn set time_to_travel_to_clinic  = obs_value_numeric(tn.encounter_id, 'CIEL','159471');
update temp_ncd_encounters tn left join obs o on o.voided = 0 and tn.encounter_id = o.encounter_id and concept_id = concept_from_mapping('CIEL','1732')
and obs_group_id in (select obs_id from obs where voided = 0 and concept_id = concept_from_mapping('PIH','12736'))
set  clinic_travel_time_unit  = concept_name(value_coded, 'en');
update temp_ncd_encounters tn set cost_of_transport = obs_value_numeric(tn.encounter_id, 'PIH','TRANSPORTATION COST');
update temp_ncd_encounters tn set times_do_you_eat_daily = obs_value_numeric(tn.encounter_id, 'CIEL','165591');

-- physical exams
update temp_ncd_encounters tn set normal_general_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in 
(concept_from_mapping('PIH','WELL APPEARING'), concept_from_mapping('CIEL', '160282')) and concept_id = concept_from_mapping('PIH', 'GENERAL EXAM FINDINGS'));

update temp_ncd_encounters tn set abnormal_general_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in (concept_from_mapping('PIH','CACHECTIC'), 
concept_from_mapping('PIH', 'CONFUSION'), concept_from_mapping('PIH', 'Obesity')) and concept_id = concept_from_mapping('PIH', 'GENERAL EXAM FINDINGS'));
 
update temp_ncd_encounters tn set other_general_exam = ( select value_text from obs o where tn.encounter_id = o.encounter_id and voided = 0 and concept_id = 
concept_from_mapping('PIH', 'GENERAL FREE TEXT') and obs_group_id in (select obs_id from obs o2 where o2.voided = 0 and o.encounter_id = o2.encounter_id and o2.concept_id =
concept_from_mapping('PIH', 'GENERAL EXAM FINDINGS')));

update temp_ncd_encounters tn set normal_heent_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in 
(concept_from_mapping('PIH','3757'), concept_from_mapping('PIH', '117'), concept_from_mapping('PIH', '12617')) and concept_id = concept_from_mapping('PIH', 'HEENT EXAM FINDINGS'));

update temp_ncd_encounters tn set abnormal_heent_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in (concept_from_mapping('PIH','PALE CONJUNCTIVA'), 
concept_from_mapping('CIEL', '127918'), concept_from_mapping('PIH', 'JAUNDICE'), concept_from_mapping('CIEL', '162941'), concept_from_mapping('PIH', 'GOITER')) and concept_id = concept_from_mapping('PIH', 'HEENT EXAM FINDINGS'));
 
update temp_ncd_encounters tn set other_heent_exam = ( select value_text from obs o where tn.encounter_id = o.encounter_id and voided = 0 and concept_id = 
concept_from_mapping('PIH', 'GENERAL FREE TEXT') and obs_group_id in (select obs_id from obs o2 where o2.voided = 0 and o.encounter_id = o2.encounter_id and o2.concept_id =
concept_from_mapping('PIH', 'HEENT EXAM FINDINGS')));

update temp_ncd_encounters tn set normal_lungs_exam = (select concept_name(value_coded, 'en') from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded = 
concept_from_mapping('PIH', '1115') and concept_id = concept_from_mapping('PIH', 'CHEST EXAM FINDINGS'));

update temp_ncd_encounters tn set abnormal_lungs_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in (concept_from_mapping('CIEL','122863'), 
concept_from_mapping('CIEL', '127640'), concept_from_mapping('CIEL', '125061'))
 and concept_id = concept_from_mapping('PIH', 'CHEST EXAM FINDINGS'));
 
update temp_ncd_encounters tn set other_lungs_exam = ( select value_text from obs o where tn.encounter_id = o.encounter_id and voided = 0 and concept_id = 
concept_from_mapping('PIH', 'GENERAL FREE TEXT') and obs_group_id in (select obs_id from obs o2 where o2.voided = 0 and o.encounter_id = o2.encounter_id and o2.concept_id =
concept_from_mapping('PIH', 'CHEST EXAM FINDINGS')));

update temp_ncd_encounters tn set normal_heart_exam = (select group_concat(concept_name(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and 
value_coded in (concept_from_mapping('PIH', 'REGULAR RHYTHM'), concept_from_mapping('PIH', 'NO CARDIAC MURMURS'), concept_from_mapping('PIH', 'PMI NOT DISPLACED'), 
concept_from_mapping('PIH', 'S1 AND S2 NORMAL') ) and concept_id = concept_from_mapping('PIH', 'CARDIAC EXAM FINDINGS'));

update temp_ncd_encounters tn set abnormal_heart_exam  = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in (concept_from_mapping('PIH','BRADYCARDIA'), 
concept_from_mapping('PIH', 'TACHYCARDIA'), concept_from_mapping('PIH', 'ATRIAL FIBRILLATION'), concept_from_mapping('PIH', 'DISPLACED POINT OF MAXIMAL IMPULSE'),
concept_from_mapping('PIH', 'S3 GALLOP'), concept_from_mapping('PIH', 'S4 GALLOP'))
 and concept_id = concept_from_mapping('PIH', 'CARDIAC EXAM FINDINGS'));
 
update temp_ncd_encounters tn set other_heart_exam = (select value_text from obs o where tn.encounter_id = o.encounter_id and voided = 0 and concept_id = 
concept_from_mapping('PIH', 'GENERAL FREE TEXT') and obs_group_id in (select obs_id from obs o2 where o2.voided = 0 and o.encounter_id = o2.encounter_id and o2.concept_id =
concept_from_mapping('PIH', 'CARDIAC EXAM FINDINGS')));

update temp_ncd_encounters tn set normal_abdomen_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in (concept_from_mapping('PIH','SOFT ABDOMEN'), 
concept_from_mapping('PIH', 'NO ABDOMINAL TENDERNESS'), concept_from_mapping('PIH', 'NO PRESENCE OF ASCITES'), concept_from_mapping('PIH', 'NO PRESENCE OF HEPATOMEGALY'),
concept_from_mapping('PIH', 'NO PRESENCE OF SPLENOMEGALY'))
 and concept_id = concept_from_mapping('PIH', 'ABDOMINAL EXAM FINDINGS'));
 
update temp_ncd_encounters tn set abnormal_abdomen_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in (concept_from_mapping('PIH','HEPATOMEGALY'), 
concept_from_mapping('PIH', 'ASCITES'), concept_from_mapping('PIH', 'SPLENOMEGALY'), concept_from_mapping('PIH', 'ABDOMINAL TENDERNESS'))
 and concept_id = concept_from_mapping('PIH', 'ABDOMINAL EXAM FINDINGS'));

update temp_ncd_encounters tn set other_abdomen_exam = (select value_text from obs o where tn.encounter_id = o.encounter_id and voided = 0 and concept_id = 
concept_from_mapping('PIH', 'GENERAL FREE TEXT') and obs_group_id in (select obs_id from obs o2 where o2.voided = 0 and o.encounter_id = o2.encounter_id and o2.concept_id =
concept_from_mapping('PIH', 'ABDOMINAL EXAM FINDINGS')));

update temp_ncd_encounters tn set normal_neuro_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded = concept_from_mapping('PIH','NORMAL')
and concept_id = concept_from_mapping('PIH', 'NEUROLOGIC EXAM FINDINGS'));
 
update temp_ncd_encounters tn set abnormal_neuro_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in (concept_from_mapping('PIH','FOCAL NEUROLOGICAL DEFICIT'), 
concept_from_mapping('CIEL', '165588'), concept_from_mapping('CIEL', '165589'))
 and concept_id = concept_from_mapping('PIH', 'NEUROLOGIC EXAM FINDINGS'));

update temp_ncd_encounters tn set other_neuro_exam = (select value_text from obs o where tn.encounter_id = o.encounter_id and voided = 0 and concept_id = 
concept_from_mapping('PIH', 'GENERAL FREE TEXT') and obs_group_id in (select obs_id from obs o2 where o2.voided = 0 and o.encounter_id = o2.encounter_id and o2.concept_id =
concept_from_mapping('PIH', 'NEUROLOGIC EXAM FINDINGS')));

update temp_ncd_encounters tn set normal_extremities_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in (concept_from_mapping('PIH','Normal, without peripheral edema'),
concept_from_mapping('PIH','12623'))
and concept_id = concept_from_mapping('PIH', 'EXTREMITY EXAM FINDINGS'));
 
update temp_ncd_encounters tn set abnormal_extremities_exam = (select group_concat(concept_name
(value_coded, 'en') separator " | ") from obs o where tn.encounter_id = o.encounter_id and voided = 0 and value_coded in (concept_from_mapping('CIEL','130428'), 
concept_from_mapping('CIEL', '130166'), concept_from_mapping('CIEL', '136522'),
concept_from_mapping('CIEL','124823'), 
concept_from_mapping('CIEL', '123919'), concept_from_mapping('CIEL', '588'), concept_from_mapping('PIH','CYANOSIS')
) and concept_id = concept_from_mapping('PIH', 'EXTREMITY EXAM FINDINGS'));

update temp_ncd_encounters tn set other_extremities_exam = (select value_text from obs o where tn.encounter_id = o.encounter_id and voided = 0 and concept_id = 
concept_from_mapping('PIH', 'GENERAL FREE TEXT') and obs_group_id in (select obs_id from obs o2 where o2.voided = 0 and o.encounter_id = o2.encounter_id and o2.concept_id =
concept_from_mapping('PIH', 'EXTREMITY EXAM FINDINGS')));

-- disposition
update temp_ncd_encounters tn set social_welfare = obs_value_coded_list(tn.encounter_id, 'PIH','SOCIO-ECONOMIC ASSISTANCE RECOMMENDED', 'en');
update temp_ncd_encounters tn set disposition = obs_value_coded_list(tn.encounter_id, 'PIH','DISPOSITION', 'en');
update temp_ncd_encounters tn set disposition_comments = obs_value_text(tn.encounter_id,'PIH', 'DISPOSITION COMMENTS');

update temp_ncd_encounters tn set chw  = obs_value_text(tn.encounter_id, 'CIEL','164141');
update temp_ncd_encounters tn set chw_to_visit = obs_value_numeric(tn.encounter_id, 'PIH','3451');
update temp_ncd_encounters tn left join obs o on o.voided = 0 and tn.encounter_id = o.encounter_id and concept_id = concept_from_mapping('PIH','TIME UNITS')
and obs_group_id in (select obs_id from obs where voided = 0 and concept_id = concept_from_mapping('PIH','12625'))
set chw_to_visit_freq = concept_name(value_coded, 'en') ;

select 
person_id,
emr_id,
encounter_id,
encounter_datetime,
encounter_type_name(encounter_id) as 'encounter_type',
reason_for_referral,
internal_patient_referral,
external_patient_referral,
other_internal_site,
other_external_site,
other_external_non_pih_site,
date_of_referral,
symptoms_duration,
symptoms_duration_unit,
unknown_symptoms_duration,
patient_ever_been_hospitalized_for_these_symptoms,
total_number_of_hospitalizations,
Last_date_of_admission,
has_the_patient_ever_received_medication_for_symptoms,
has_the_patient_recently_taken_medication,
visit_to_churchyard_or_traditional_healer,
what_was_the_diagnosis_and_treatment,
has_the_patient_delivered_within_the_past_five_years,
number_of_times_with_big_belly,
how_many_children_has_she_born,
any_problems_during_big_belly,
did_her_symptoms_start_around_the_time_of_delivery,
patient_has_cough_more_than_two_weeks,
type_of_cough,
patient_has_fever_and_night_sweats_more_than_two_weeks,
patient_has_weight_loss_in_less_than_four_months,
type_of_weight_loss,
does_the_patient_smoke,
type_of_tobacco_product,
how_many_cigs_or_pipes_per_day,
does_the_patient_drink_alcohol,
type_of_alcohol_product,
how_many_modern_bottles_per_day,
how_many_traditional_bottles_per_day,
past_medication_or_drug_allergy,
medication_side_effect,
other_relevant_history,
work_for_income,
household_number_of_persons,
transportation_to_clinic_today,
time_to_travel_to_clinic,
clinic_travel_time_unit,
cost_of_transport, 
times_do_you_eat_daily,
normal_general_exam,
abnormal_general_exam,
other_general_exam,
normal_heent_exam,
abnormal_heent_exam,
other_heent_exam,
normal_lungs_exam,
abnormal_lungs_exam,
loc_crackles,
other_lungs_exam,
normal_heart_exam,
abnormal_heart_exam,
other_heart_exam, 
normal_abdomen_exam,
abnormal_abdomen_exam,
other_abdomen_exam,
normal_neuro_exam,
abnormal_neuro_exam,
other_neuro_exam,
normal_extremities_exam,
abnormal_extremities_exam,
other_extremities_exam,
social_welfare,
disposition,
disposition_comments,
chw,
chw_to_visit,
chw_to_visit_freq
from temp_ncd_encounters;


