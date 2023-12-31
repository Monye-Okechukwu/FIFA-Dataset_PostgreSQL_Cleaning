-- To check for duplicate rows in the dataset
SELECT *
FROM public.fifa21_raw_data
GROUP BY id
HAVING COUNT(*) > 1;

-- To check the special characters in a string
SELECT name, longname, regexp_replace(name, '([^[:ascii:]])', '[\1]', 'g') as marked, playerurl, photourl
FROM public.fifa21_raw_data
WHERE id IN(165109, 247949, 248073, 251880, 248441, 258364, 248421);

-- To correct the special characters in the above rows
UPDATE public.fifa21_raw_data
SET name = concat(left(longname,1), '. ', right(longname,4))
WHERE id in(165109, 247949, 248073, 251880, 248441, 258364, 248421);

-- Extract the player's correct name from the playerurl column
UPDATE public.fifa21_raw_data
SET longname = INITCAP(REPLACE(SPLIT_PART(playerurl, '/', 6), '-', ' '));

-- photourl and playerurl should be deleted
ALTER TABLE public.fifa21_raw_data
DROP COLUMN photourl,
DROP COLUMN playerurl;

-- Removing the whitespaces in the club column
UPDATE public.fifa21_raw_data
SET club = regexp_replace(club, '\s+', '')
;

-- create three columns
ALTER TABLE public.fifa21_raw_data
ADD COLUMN agreement VARCHAR(8),
ADD COLUMN contract_start VARCHAR(4),
ADD COLUMN contract_end VARCHAR(4);

-- Populate the agreement column 
UPDATE public.fifa21_raw_data SET agreement = 'Free' WHERE LENGTH(contract) = 4;
UPDATE public.fifa21_raw_data SET agreement = 'Contract' WHERE LENGTH(contract) = 11;
UPDATE public.fifa21_raw_data SET agreement = 'Loan' WHERE LENGTH(contract) > 11;

-- Populate the contract_end and contract_start with the years
UPDATE public.fifa21_raw_data SET contract_start = LEFT(contract,4) WHERE agreement = 'Contract';
UPDATE public.fifa21_raw_data SET contract_end = RIGHT(contract,4) WHERE agreement = 'Contract';

-- Add a loan_start column  
ALTER TABLE public.fifa21_raw_data
ADD COLUMN loan_start VARCHAR(20);

-- Extract the year for loan from the joined column
WITH a AS(SELECT id, agreement FROM public.fifa21_raw_data)
UPDATE public.fifa21_raw_data AS p
SET loan_start = CASE WHEN p.agreement = 'Loan' THEN TO_CHAR(joined :: DATE, 'YYYY')
											ELSE ''
											END
FROM a
WHERE a.agreement = p.agreement;

-- Change the datatype of loan_end_date
ALTER TABLE public.fifa21_raw_data ALTER COLUMN loan_date_end TYPE VARCHAR(20);

-- Extract the year for loan from the loan_end_date column
WITH a AS(SELECT agreement FROM public.fifa21_raw_data)
UPDATE public.fifa21_raw_data AS p
SET loan_date_end  = CASE WHEN p.agreement = 'Loan' THEN TO_CHAR(loan_date_end :: DATE, 'YYYY')
											ELSE ''
											END
FROM a
WHERE a.agreement = p.agreement;

-- Drop contract and joined columns
ALTER TABLE public.fifa21_raw_data
DROP COLUMN contract,
DROP COLUMN joined
;
-- Rename loan_date_end column to loan_end
ALTER TABLE public.fifa21_raw_data
RENAME loan_date_end TO loan_end;

-- Drop positions column
ALTER TABLE public.fifa21_raw_data
DROP COLUMN positions;

-- Remove the quotation from the height column 
UPDATE public.fifa21_raw_data
SET height = rtrim(height, '"');

-- Add a new column for heights in CM
ALTER TABLE public.fifa21_raw_data
ADD COLUMN height_cm SMALLINT;

-- populate height_cm with heights in cm
WITH a AS(SELECT id, height FROM public.fifa21_raw_data)
UPDATE public.fifa21_raw_data AS p
SET height_cm  = CASE WHEN RIGHT(p.height,2) = 'cm' THEN LEFT(p.height, 3) :: SMALLINT
					  ELSE ROUND(LEFT(p.height,1) :: SMALLINT * 30.48 + SUBSTRING(p.height FROM 3 FOR LENGTH(p.height)-1) :: SMALLINT * 2.54)
											END
FROM a
WHERE a.id = p.id;

-- Add a new column for weights in KG
ALTER TABLE public.fifa21_raw_data
ADD COLUMN weight_kg SMALLINT;

--Convert the values in lbs to kg
WITH a AS(SELECT id, weight FROM public.fifa21_raw_data)
UPDATE public.fifa21_raw_data AS p
SET weight_kg  = CASE WHEN RIGHT(p.weight,3) = 'lbs' THEN ROUND(LEFT(p.weight, 3) :: SMALLINT * 0.454)
					  ELSE LEFT(p.weight, LENGTH(p.weight)-2) :: SMALLINT 
											END
FROM a
WHERE a.id = p.id;

ALTER TABLE public.fifa21_raw_data
	ADD value_€ NUMERIC,
	ADD wage_€ NUMERIC,
	ADD release_clause_€ NUMERIC;

--Convert the 'M' and 'K' in value, wage and release_clause
UPDATE public.fifa21_raw_data "560K"
SET value_€ = CASE WHEN value LIKE '€%' AND value LIKE '%M' 
		      			 THEN REPLACE(REPLACE(value, '€', ''),'M','') :: NUMERIC * 1000000
		 			WHEN value LIKE '€%' AND value LIKE '%K' 
		      			 THEN REPLACE(REPLACE(value, '€', ''),'K','') :: NUMERIC * 1000
				         ELSE REPLACE(value, '€', '') :: NUMERIC
			        END,
wage_€ =  CASE WHEN wage LIKE '€%' AND wage LIKE '%K' 
		  			 THEN REPLACE(REPLACE(wage, '€', ''),'K','') :: NUMERIC * 1000
				 	 ELSE REPLACE(wage, '€', '') :: NUMERIC
		        END,
release_clause_€ = CASE WHEN release_clause LIKE '€%' AND release_clause LIKE '%M' 
		      	   		 	THEN REPLACE(REPLACE(release_clause, '€', ''),'M','') :: NUMERIC * 1000000
		      			 WHEN release_clause LIKE '€%' AND release_clause LIKE '%K' 
		      	   		    THEN REPLACE(REPLACE(release_clause, '€', ''),'K','') :: NUMERIC * 1000
				 			ELSE REPLACE(release_clause, '€', '') :: NUMERIC
				 END
;

-- To see if the change was effected properly
SELECT value, value_€, wage, wage_€, release_clause, release_clause_€ 
FROM public.fifa21_raw_data;

ALTER TABLE public.fifa21_raw_data
DROP COLUMN value,
DROP COLUMN wage,
DROP COLUMN release_clause;

--Change datatype for the following columns
ALTER TABLE public.fifa21_raw_data 
ALTER COLUMN ova TYPE numeric(5,2),
ALTER COLUMN pot TYPE numeric(5,2),
ALTER COLUMN bov TYPE numeric(5,2)
;

--Convert the columns to percent 
UPDATE public.fifa21_raw_data
SET ova = ova/100,
	pot = pot/100,
	bov = bov/100
;

-- Create three columns
ALTER TABLE public.fifa21_raw_data
ADD COLUMN weakfoot_rating SMALLINT,
ADD COLUMN skillmoves_rating SMALLINT,
ADD COLUMN international_reputation SMALLINT;

-- Extractng just the values and removing the '★' from the values then inserting into the newly created columns
UPDATE public.fifa21_raw_data
SET weakfoot_rating = REPLACE(w_f, '★', '') :: SMALLINT,
    skillmoves_rating = REPLACE(sm, '★', '') :: SMALLINT,
    international_reputation = REPLACE(ir, '★', '') :: SMALLINT
;

-- Change the datatype in the hits column and multiply the values ending with 'K' by 1000
UPDATE public.fifa21_raw_data
SET hits = CASE WHEN UPPER(hits) LIKE '%K' THEN (REPLACE(hits, 'K','') :: NUMERIC(3,1)) * 1000
		WHEN hits IS NULL THEN 0
		ELSE hits :: SMALLINT
		END;

--Rename the following columns
ALTER TABLE public.fifa21_raw_data RENAME ova TO overall_rating;
ALTER TABLE public.fifa21_raw_data RENAME pot TO potential_rating;
ALTER TABLE public.fifa21_raw_data RENAME bov TO best_overall_rating;
ALTER TABLE public.fifa21_raw_data RENAME a_w TO attacking_workrate;
ALTER TABLE public.fifa21_raw_data RENAME d_w TO defensive_workrate;
ALTER TABLE public.fifa21_raw_data RENAME pac TO pace;
ALTER TABLE public.fifa21_raw_data RENAME sho TO shooting;
ALTER TABLE public.fifa21_raw_data RENAME pas TO passing;
ALTER TABLE public.fifa21_raw_data RENAME def TO defensive;
ALTER TABLE public.fifa21_raw_data RENAME phy TO physical;

--Remove w_f, sm, ir height, weights and trial
ALTER TABLE public.fifa21_raw_data
DROP COLUMN w_f,
DROP COLUMN sm,
DROP COLUMN ir,
DROP COLUMN height,
DROP COLUMN weight,
-- The trial column is added by postgres cause it is imported
DROP COLUMN trial786;
					   
SELECT *
FROM
public.fifa21_raw_data
ORDER BY overall_rating DESC;		  