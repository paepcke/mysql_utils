# Set the statement delimiter to something other than ';'
# so the procedure can use ';':
delimiter //

#USE Edx//

#--------------------------
# createIndexIfNotExists
#-----------

# Create index if it does not exist yet.
# Parameter the_prefix_len can be set to NULL if not needed
# NOTE: ensure the database in which the table resides
# is the current db. I.e. do USE <db> before calling.

DROP PROCEDURE IF EXISTS createIndexIfNotExists //
CREATE PROCEDURE createIndexIfNotExists (IN the_index_name varchar(255),
                           IN the_table_name varchar(255),
                     IN the_col_name   varchar(255),
                     IN the_prefix_len INT)
this_proc: BEGIN
      # Check whether table exists:
      IF ((SELECT COUNT(*) AS table_exists
           FROM information_schema.tables
           WHERE TABLE_SCHEMA = DATABASE()
             AND table_name = the_table_name)
          = 0)
      THEN
           SELECT concat("**** Table ", DATABASE(), ".", the_table_name, " does not exist.");
       LEAVE this_proc;
      END IF;

      IF ((SELECT COUNT(*) AS index_exists
           FROM information_schema.statistics
           WHERE TABLE_SCHEMA = DATABASE()
             AND table_name = the_table_name
         AND index_name = the_index_name)
          = 0)
      THEN
          # Different CREATE INDEX statement depending on whether
          # a prefix length is required:
          IF the_prefix_len IS NULL
          THEN
                SET @s = CONCAT('CREATE INDEX ' ,
                                the_index_name ,
                        ' ON ' ,
                        the_table_name,
                        '(', the_col_name, ')');
          ELSE
                SET @s = CONCAT('CREATE INDEX ' ,
                                the_index_name ,
                       ' ON ' ,
                        the_table_name,
                        '(', the_col_name, '(',the_prefix_len,'))');
         END IF;
         PREPARE stmt FROM @s;
         EXECUTE stmt;
      END IF;
END//

#--------------------------
# dropIndexIfExists
#-----------

# The LIMIT 1 below guards against an index
# on the given column existing once in index position 1
# and also in position 2.

DROP PROCEDURE IF EXISTS dropIndexIfExists //
CREATE PROCEDURE dropIndexIfExists (IN the_table_name varchar(255),
                            IN the_col_name varchar(255))
BEGIN
    DECLARE indx_name varchar(255);
    IF ((SELECT COUNT(*) AS index_exists
         FROM information_schema.statistics
         WHERE TABLE_SCHEMA = DATABASE()
           AND table_name = the_table_name
         AND column_name = the_col_name)
        > 0)
    THEN
        SELECT index_name INTO @indx_name
    FROM information_schema.statistics
    WHERE TABLE_SCHEMA = DATABASE()
        AND table_name = the_table_name
        AND column_name = the_col_name
       LIMIT 1;
        SET @s = CONCAT('DROP INDEX `' ,
                        @indx_name ,
                  '` ON ' ,
                the_table_name
                );
       PREPARE stmt FROM @s;
       EXECUTE stmt;
    END IF;
END//

#--------------------------
# STRMDIFF
#-----------

# Given two term codes (strm), compute
# how many quarters are in between the two
# terms. Returns the absolute value, i.e.
# OK to have strm2 > strm1; they are exchanged.
#
# Function will break if either strm actual
# is illegal. For instance, if it ends with
# a digit other than 2,4,6, or 8.

DROP FUNCTION IF EXISTS STRMDIFF//
CREATE FUNCTION STRMDIFF(strm1 int, strm2 int)
RETURNS int
DETERMINISTIC
BEGIN

    -- If strm2 > strm1, exchange them
    -- to get positive values:
    IF (strm2 > strm1)
    THEN
        SET @strm1 = strm2;
        SET @strm2 = strm1;
	SET @result_positive = 0;
    ELSE
        SET @strm1 = strm1;
        SET @strm2 = strm2;
	SET @result_positive = 1;
    END IF;

    -- From 1182 and 1172, make 118 and 117.
    -- Subtract to get the years:
    SET @year_diff     = truncate(@strm1/10,0) - truncate(@strm2/10,0);

    -- Four quarters in a year:
    SET @tot_quarters  = 4 * @year_diff;

    -- Get the last digit: 2,4,6, or 8:
    SET @quarter_strm1 = mod(@strm1, 10);
    SET @quarter_strm2 = mod(@strm2, 10);

    -- Subtract or add quarters for the 'fractional'
    -- years:
    CASE @quarter_strm1
     WHEN 2 THEN SET @tot_quarters = @tot_quarters + 0;
     WHEN 4 THEN SET @tot_quarters = @tot_quarters + 1;
     WHEN 6 THEN SET @tot_quarters = @tot_quarters + 2;
     WHEN 8 THEN SET @tot_quarters = @tot_quarters + 3;
     ELSE SIGNAL SQLSTATE 'HY000'
          SET MESSAGE_TEXT = 'Term codes must end in 2,4,6, or 8';

    END CASE;

    CASE @quarter_strm2
     WHEN 2 THEN SET @tot_quarters = @tot_quarters - 0;
     WHEN 4 THEN SET @tot_quarters = @tot_quarters - 1;
     WHEN 6 THEN SET @tot_quarters = @tot_quarters - 2;
     WHEN 8 THEN SET @tot_quarters = @tot_quarters - 3;
     ELSE SIGNAL SQLSTATE 'HY000'
          SET MESSAGE_TEXT = 'Term codes must end in 2,4,6, or 8';
    END CASE;

    IF (@result_positive = 1)
    THEN
        RETURN @tot_quarters;
    ELSE
        RETURN -1 * @tot_quarters;
    END IF;
END//


#--------------------------
# strm2Quarter
#-----------

# Given a strm number, return a string such
# as '2016/2017, Autumn'. Strategy: Isolate
# last digit of the 4-digit strm. It encodes
# the quarter. The first 3 digits encode
# the academic year.

DROP FUNCTION IF EXISTS strm2Quarter//
CREATE FUNCTION strm2Quarter(strm int)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    
    SET @quarter_code = MOD(strm, 10);
    IF (@quarter_code = 2)
    THEN
        SET @quarter = 'Autumn';
    ELSEIF (@quarter_code = 4)
    THEN
        SET @quarter = 'Winter';
    ELSEIF (@quarter_code = 6)
    THEN
        SET @quarter = 'Spring';
    ELSE
        SET @quarter = 'Summer';
    END IF;

    SET @year_part = FLOOR(strm/10);

    IF (@year_part >= 100)
    THEN
        SET @acad_year = 2000 + MOD(@year_part, 100);
    ELSE
        SET @acad_year = 1900 + MOD(@year_part, 100);
    END IF;

    SET @acad_year = CONCAT(@acad_year - 1, '/', @acad_year);

    RETURN CONCAT(@acad_year, ', ', @quarter); 
END//

#------------------------------
# date2Strm
#-------------

# NOTE: this function is (must be) identical
#       to the older function STRM_TO_DATE().
#       This date2Strm() function name is consistent
#       with the strm2Quarter() function name.
#       The STRM_TO_DATE() is retained for backward
#       compatibility.

# Given a date string 'yyyy-mm-dd', return
# the corresponding strm. Relies on presence
# of table quarter_dates, which is created
# via the script quarter_dates_maker.py.

DROP FUNCTION IF EXISTS date2Strm;
CREATE FUNCTION date2Strm(the_date date) RETURNS int
DETERMINISTIC
BEGIN
    DECLARE the_strm int;
    SELECT strm INTO the_strm
      FROM carta.quarter_dates
     WHERE the_date BETWEEN start_date AND end_date;

     RETURN(the_strm);
END//


#------------------------------
# STRM_OF_DATE
#-------------

# Given a date string 'yyyy-mm-dd', return
# the corresponding strm. Relies on presence
# of table quarter_dates, which is created
# via the script quarter_dates_maker.py.

DROP FUNCTION IF EXISTS STRM_OF_DATE//
CREATE FUNCTION STRM_OF_DATE(the_date date) RETURNS int
DETERMINISTIC
BEGIN
    DECLARE the_strm int;
    SELECT strm INTO the_strm
      FROM carta.quarter_dates
     WHERE the_date BETWEEN start_date AND end_date;

     RETURN(the_strm);
END//

#--------------------------
# desca
#-----------

# Given a table name, list its column names in 
# alphabetical order: a 'desc' with alpha order.

DROP PROCEDURE IF EXISTS desca//

CREATE PROCEDURE desca(IN the_table_name varchar(255))
BEGIN
   DECLARE table_basename varchar(255);
   DECLARE table_db varchar(255);

   SET table_basename = TABLE_BASENAME(the_table_name);
   SET table_db       = DATABASE_NAME(the_table_name);

   SELECT distinct
       c.column_name,
       IF (c.character_maximum_length is not null,
                 concat(c.data_type, '(', c.character_maximum_length, ')'),
                 c.data_type) AS data_type
     FROM INFORMATION_SCHEMA.COLUMNS c
    WHERE c.table_name    = table_basename
      AND c.table_schema  = table_db
    ORDER BY c.column_name;
END//

#------------------------------
# MAJOR
#-------------

/*
Given an emplid, return the student's current major.
The quantity is taken from academic_plan's latest
update of the ACAD_PLAN column. 

Example returns: STATS-MS, UNDECL-B, MED-EXCH

For bulk queries on majors, the following is much
faster:

     SELECT emplid, acad_plan as major, max(declare_dt)
       FROM academic_plan
        GROUP BY emplid;
*/

DROP FUNCTION IF EXISTS MAJOR;
CREATE FUNCTION MAJOR(the_emplid varchar(255)) RETURNS varchar(10)
DETERMINISTIC
BEGIN
    DECLARE major varchar(10);

    SELECT acad_plan INTO major
      FROM academic_plan 
     WHERE emplid =  the_emplid
    ORDER BY declare_dt DESC 
    LIMIT 1;

    RETURN(major);
END//

#--------------------------
# STUDYFIELD_FROM_ACAD_PLAN
#-----------

/*
Given an acad_plan as found in academic_career_term_activation,
return the plan's academic discipline with the degree
removed. Example: AA-PhD  ==> AA
*/

DROP FUNCTION IF EXISTS STUDYFIELD_FROM_ACAD_PLAN;
CREATE FUNCTION  STUDYFIELD_FROM_ACAD_PLAN(plan varchar(30))
RETURNS varchar(30)
DETERMINISTIC
BEGIN
    RETURN SUBSTRING_index(plan, '-',1);
END//

#------------------------------
# COURSE_JSON
#-------------

DROP FUNCTION IF EXISTS course_json;
CREATE FUNCTION course_json(json_data MEDIUMTEXT, wanted_fld VARCHAR(255))
   RETURNS varchar(255)
DETERMINISTIC
/*
    Given a value of the course_info json_data column, return
    one of the fields. Only the following fields are extracted,
    though this function, and its helper procedure parse_course_json()
    can be modified to handle any other of the many fields in those
    json objects.

         discipline  e.g.: ENGR
         department  e.g.: AEROASTRO
         edu_level   e.g.: G   (for Graduate)
         strm        e.g.: 1172
         quarter     e.g.: 2016/2017, Autumn
         days        e.g.: MondayWednesday
         start_time  e.g.: 13:30:00
         end_time    e.g.: 14:00:00

    USAGE select course_json(<json_data>, <fldNameStr>)
     e.g. select course_json(@json_data, 'quarter')

    USAGE in a query:
         SELECT subject, catalog_nbr
           FROM table_load_workspace.course_info
          WHERE course_json(json_data, 'days') = 'Friday';
    */

BEGIN
   DECLARE discipline VARCHAR(20);
   DECLARE department VARCHAR(255);
   DECLARE edu_level  VARCHAR(4);
   DECLARE strm int;
   DECLARE quarter VARCHAR(20);
   DECLARE days VARCHAR(25);
   DECLARE start_time TIME;
   DECLARE end_time TIME;
           
   CALL parse_course_json(json_data,discipline,department,edu_level,strm,quarter,days,start_time,end_time);
   IF wanted_fld = 'discipline'
   THEN
        RETURN discipline;
   ELSEIF wanted_fld = 'department'
   THEN
        RETURN department;
   ELSEIF wanted_fld = 'edu_level'
   THEN
        RETURN edu_level;
   ELSEIF wanted_fld = 'strm'
   THEN
        RETURN strm;
   ELSEIF wanted_fld = 'quarter'
   THEN
        RETURN quarter;
   ELSEIF wanted_fld = 'days'
   THEN
        RETURN days;
   ELSEIF wanted_fld = 'start_time'
   THEN
        RETURN start_time;
   ELSEIF wanted_fld = 'end_time'
   THEN
        RETURN end_time;
   ELSE
        RETURN NULL;
   END IF;
END//

#------------------------------
# RANDOM_ROWS
#-------------
 
DROP PROCEDURE IF EXISTS RANDOM_ROWS;
CREATE PROCEDURE RANDOM_ROWS  (IN src_tbl_name varchar(255),
                               IN out_tbl_name varchar(255),
                               IN num_rows int,
                               IN replacement varchar(20)
                               )

/*
    Given a source table src_tbl_name, sample a num_rows random rows.
    The result will be deposited into a result table out_tbl_name.
    Sampling can be executed with or without replacement. The source
    table remains unchanged either way.

    The result table will be created to match the source table.
    Replacement policy is specified as follows: if parameter
    replacement is 'replace' or 'with replacement', then sampled
    rows are replaced into the source. All other values, such as
    'without replacement', or 'no replacement' signal that sampled
    values will not be replaced.

    Strategy:
      - Copy the source table to a temporary table that includes
        an auto-increment primary key.
      - The MySQL built-in random number generator is used to select
        a random row in the temporary table. That row is copied to the
        output table.
      - If with replacement, the process continues until num_rows
        have been copied.
      - If without replacement, the sampled row is removed from the
        temporary table before repeating the sampling process.
      - The temporary table is deleted.

    Note that it is not possible in MySQL to use input parameters or
    local variables in SQL queries within procedures. That is, the
    following will fail:

              SELECT @my_col FROM @my_table;
              
    whereas the following are legal within procedures:

              CREATE TABLE myTable (foo varchar(255));
              UPDATE myTable
                SET foo = @my_value;

    i.e. myTable is a literal, not a function. If variables are involved
    it is necessary to prepare a statement by concatenating string
    snippets.

*/

BEGIN
    DECLARE src_prim_key_fld VARCHAR(255);
    DECLARE src_prim_key_type VARCHAR(255);

    SET @count = 0;
    SET @rand_key_val = '';

    -- Drop table to hold final output rows:

    SET @out_tbl_drop_cmd = concat('DROP TABLE IF EXISTS ', out_tbl_name, ';');
    PREPARE stmt FROM @out_tbl_drop_cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Create table to hold final output rows:
    SET @out_tbl_create_cmd = concat('CREATE TABLE ', out_tbl_name, ' LIKE ', src_tbl_name, ';');

    PREPARE stmt FROM @out_tbl_create_cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Copy the source table, adding a no-holes integer primary key:

    DROP TABLE IF EXISTS __picker_table__;
    SET @picker_tbl_create_cmd = concat('CREATE TABLE __picker_table__ LIKE ', src_tbl_name, ';');

    PREPARE stmt FROM @picker_tbl_create_cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Get a comma-separated string of the source
    -- table's columns:

    SET @col_tbl_cmd = CONCAT("select column_names(null, '",
                               src_tbl_name,
                               "') INTO @src_tbl_col_names;");

    PREPARE stmt FROM @col_tbl_cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- If the source table has a primary key, remove that key
    -- from the __picker_table__, because we will add our own
    -- primary key; leave the column itself intact:

    SELECT get_primary_key_fld(src_tbl_name) INTO src_prim_key_fld;
    IF src_prim_key_fld IS NOT NULL
    THEN
        -- Yes, source table does have a primary key (which came over
        -- to __picker_table__ via the CREATE...LIKE...:

        SELECT get_primary_key_type(src_tbl_name) INTO src_prim_key_type;
        SET @picker_disable_auto_increment_cmd = concat('ALTER TABLE  __picker_table__ MODIFY ',
                                                            src_prim_key_fld,
                                                            ' ', src_prim_key_type, ' NOT NULL;');

        PREPARE stmt FROM @picker_disable_auto_increment_cmd;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        ALTER TABLE __picker_table__ DROP PRIMARY KEY;

    END IF;

    -- Copy the source table to the picker table. Note the usual speedup
    -- from using the MyISAM engine, disabling keys, and locking source
    -- and destination tables won't work, because table locking is not
    -- supported in procedures. So we work with innodb:

    SET unique_checks=0; SET foreign_key_checks=0;
    SET @copy_tables_cmd = concat('INSERT INTO __picker_table__ ',
                                  'SELECT ', @src_tbl_col_names, ' FROM ', src_tbl_name, ';');
    PREPARE stmt FROM @copy_tables_cmd;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Now can safely add a primary auto_increment key to __picker_table__
    -- ('safely' because now the picker table no longer has a primary key that
    -- may have been on the source table):

    ALTER TABLE __picker_table__ ADD COLUMN __new_id__ int AUTO_INCREMENT PRIMARY KEY;

    SET unique_checks=1; SET foreign_key_checks=1;

    -- Fill the output table with the samples:
    WHILE @count < num_rows DO

       -- Put one random int from 0 to src_table size into
       -- rand_key_val

       CALL RANDOM_COL_VALUE('__picker_table__',
                             '__new_id__',         -- Field whose value to sample
                             '__new_id__',         -- The primary integer index column
                             @rand_key_val);

       SET @add_one_rand_row = concat('INSERT INTO ', out_tbl_name,
                                      ' SELECT ', @src_tbl_col_names, ' FROM __picker_table__
                                         WHERE __new_id__ = "', @rand_key_val, '";');
       PREPARE insert_one FROM @add_one_rand_row;
       EXECUTE insert_one;
       SET @count = @count + 1;

       -- Remove picked sample if not 'with-replacement':
       IF replacement != 'replace' AND replacement != 'with replacement'
       THEN
           DELETE FROM __picker_table__
            WHERE __new_id__ = @rand_key_val;
       END IF;

    END WHILE;

    DROP TABLE __picker_table__;

    DEALLOCATE PREPARE insert_one;
END;// # RANDOM_ROWS


#------------------------------
# COLUMN_NAMES
#-------------

DROP FUNCTION IF EXISTS COLUMN_NAMES;
CREATE function COLUMN_NAMES(db_name varchar(255),
                             tbl_name varchar(255))
  RETURNS text
  DETERMINISTIC

/*
    Given a table name, return a string of
    the table's comma-separated column names.

    If db_name is NULL the current database
    is assumed.

    Throws error if table not found.
*/

BEGIN
   IF db_name IS NULL
   THEN 
       SELECT database() INTO @db;
   ELSE 
       SET @db = db_name;
   END IF;

   SET @result = '';

   SELECT group_concat(column_name separator ',') 
     FROM information_schema.columns  
     WHERE table_schema = @db 
       AND table_name   = tbl_name
     GROUP by NULL INTO @result;

   IF length(@result) = 0
   THEN
       SET @txt = CONCAT('Table ', tbl_name, ' not found in database ', @db, '.');
       SIGNAL SQLSTATE '45000'
       SET MESSAGE_TEXT = @txt;
   END IF;

    RETURN @result;
end;//



#------------------------------
# RANDOM_COL_VALUE
#-------------

DROP PROCEDURE IF EXISTS RANDOM_COL_VALUE;
CREATE PROCEDURE RANDOM_COL_VALUE(IN tbl_name varchar(255),
                            	  IN field_spec varchar(255),
                            	  IN key_col varchar(255),
                            	  OUT result varchar(255))

/*
    Given a table and a field name, return that field's value
    in a random row.
    Assumes existence of integer key in the given table.
    The key is assumed to be ordered, but is allowed
    to have 'holes' in the number sequence.

    Assumes random distribution of the values. Returns randomly
    chosen value from the field spec (i.e. not entire
    rows)

    USAGE: CALL RANDOM_COL_VALUE('myTable', 'emplid', 'id', @one_random_emplid);
       This will return a random choice of value in the emplid column. 
       The result will be delivered in user variable @result.
*/

BEGIN
    SET @the_result = '';
    SELECT database() INTO @db;
    IF key_col IS NOT NULL
    THEN SET @key_col = key_col;
    ELSE
         SELECT column_name
           FROM information_schema.columns
          WHERE table_schema = @db
            AND table_name = tbl_name
            AND column_key = 'PRI'
          INTO @key_col;
    END IF;

    SET @query = concat(             
                 'SELECT ', field_spec, ' into @the_result
                   FROM ', tbl_name, ' JOIN (
                                          SELECT CEIL(RAND() * (
                                                                  SELECT MAX(', @key_col,')
                                                                    FROM ', tbl_name,
                                                               ')
                                                     ) AS chosen_id
                                        ) AS r2
                   WHERE ', tbl_name, '.', @key_col, ' >= chosen_id
                   ORDER BY ', tbl_name, '.', @key_col, ' ASC LIMIT 1;'
                   );

    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    set result = @the_result;
END;// # RANDOM_COL_VALUE


# ---------------------------  Utility Functions/Procedures ---------

#------------------------------
# PARSE_COURSE_JSON
#----------------

/*
     Workhorse for function course_json(). Takes a json object
     from course_info.json_data, and extracts all of:

           discipline  e.g.: ENGR
           department  e.g.: AEROASTRO
           edu_level   e.g.: G   (for Graduate)
           strm        e.g.: 1172
           quarter     e.g.: 2016/2017, Autumn
           days        e.g.: MondayWednesday
           start_time  e.g.: 13:30:00
           end_time    e.g.: 14:00:00

     The json data contains all course info in the EC_courses.xml
     course-explore XML file turned into json. Expand this
     procedure with any of fields from those structures.

       USAGE call parse_course_json(json_data,
                                    @discipline,
                                    @department,
                                    @edu_level,
                                    @strm,
                                    @quarter,
                                    @days,
                                    @start_time,
                                    @end_time);
                                    
     The user variables will be filled with the respective values.
*/
DROP PROCEDURE IF EXISTS parse_course_json;
CREATE PROCEDURE parse_course_json(
       IN json_data MEDIUMTEXT, 
       -- out course_name VARCHAR(255),
       OUT discipline VARCHAR(20),
       OUT department VARCHAR(255),
       OUT edu_level VARCHAR(4),
       OUT strm int,
       OUT quarter VARCHAR(20),
       OUT days VARCHAR(25),
       OUT start_time TIME,
       OUT end_time TIME
       )
BEGIN

    DECLARE raw_days mediumtext;
    DECLARE raw_start_time mediumtext;
    DECLARE raw_end_time mediumtext;

    # For the JSON_EXTRACT() function, see the MySQL documentation.
    
    SET @TIME_FORMAT = '%l:%i:%s %p';

    -- set course_name = SUBSTRING_INDEX(SUBSTRING(JSON_EXTRACT(json_data,"$.title"),2),
    --                   '"', 1);
    SET discipline  = SUBSTRING_INDEX(SUBSTRING(JSON_EXTRACT(json_data,"$.administrativeInformation.academicGroup"), 2),
                       '"', 1);
    SET department  = SUBSTRING_INDEX(SUBSTRING(JSON_EXTRACT(json_data,"$.administrativeInformation.academicOrganization"), 2),
                       '"', 1);
    SET edu_level   = SUBSTRING_INDEX(SUBSTRING(JSON_EXTRACT(json_data,"$.administrativeInformation.academicCareer"), 3),
                       '"', 1);
    SET strm        = SUBSTRING_INDEX(SUBSTRING(JSON_EXTRACT(json_data,"$.sections[*].termId"), 3),
                       '"', 1);
    SET quarter     = strm2quarter(strm);

    # The 'days' field is sometimes ill-formed: a long string of nulls or such.
    # Replace those with null:

    SET raw_days    = SUBSTRING_INDEX(SUBSTRING(JSON_EXTRACT(json_data,"$.sections[*].schedules[*].days"), 3),
                       '"', 1);
    SET days        = IF(LENGTH(raw_days) > 25, NULL, raw_days);
        
    # See 'days' above:
    SET raw_start_time  = SUBSTRING_INDEX(SUBSTRING(JSON_EXTRACT(json_data,"$.sections[*].schedules[*].startTime"), 3), '"', 1);
    
    SET start_time      = IF(LENGTH(raw_start_time) > 20 OR raw_start_time LIKE 'ull%',
                                 NULL,
                                 TIME(STR_TO_DATE(raw_start_time, @TIME_FORMAT)));


    SET raw_end_time    = SUBSTRING_INDEX(SUBSTRING(JSON_EXTRACT(json_data,"$.sections[*].schedules[*].endTime"), 3), 
                         '"', 1);
    SET end_time        = IF(LENGTH(raw_end_time) > 20 OR raw_end_time LIKE 'ull%',
                                 NULL,
                                 TIME(STR_TO_DATE(raw_end_time, @TIME_FORMAT)));                         

END;//

#------------------------------                                                                                                 
# GET_PRIMARY_KEY_FLD
#-------------

DROP FUNCTION IF EXISTS get_primary_key_fld;
CREATE FUNCTION get_primary_key_fld(table_name VARCHAR(255)) RETURNS varchar(255)
DETERMINISTIC
/*
    Given a table name either in the form 'myDb.myTable', or just 'myTable',
    return NULL if the table has no primary index, else return the indexed
    column's name.
*/


BEGIN
    DECLARE has_db_spec int;
    DECLARE db_name varchar(255);
    DECLARE key_field varchar(255);

    SET key_field = NULL;

    -- Separate database name from table name (if a
    -- database name is included):

    SELECT table_name regexp '[.]' INTO has_db_spec;
    IF has_db_spec = 1
    THEN
        -- Table name has a database part (before the period):
        SET db_name    = SUBSTRING_INDEX(table_name, '.', 1);
        SET table_name = SUBSTRING_INDEX(table_name, '.', -1);
    ELSE
        -- Table name has no period, database is current db:
        SET db_name = DATABASE();
    END IF;

    -- More direct methods for querying the information
    -- schema worked in the MySQL shell, but not within
    -- procedures:

    SELECT k.column_name
    FROM information_schema.table_constraints t
    JOIN information_schema.key_column_usage k
    USING(constraint_name,table_schema,table_name)
    WHERE t.constraint_type='PRIMARY KEY'
      AND t.table_schema=db_name
      AND t.table_name=table_name
    LIMIT 1 INTO key_field;

    RETURN(key_field);
END//

#------------------------------
# GET_PRIMARY_KEY_TYPE
#-------------

DROP FUNCTION IF EXISTS GET_PRIMARY_KEY_TYPE;
CREATE FUNCTION GET_PRIMARY_KEY_TYPE(table_name VARCHAR(255)) RETURNS varchar(255)
DETERMINISTIC
/*
    Given a table name either in the form 'myDb.myTable', or just 'myTable',
    return NULL if the table has no primary index, else return the indexed
    column's data type.
*/


BEGIN
    DECLARE has_db_spec int;
    DECLARE db_name varchar(255);
    DECLARE type_field varchar(255);
    DECLARE prim_fld_name varchar(255)    ;

    SET type_field = NULL;
    SET prim_fld_name = get_primary_key_fld(table_name);
    
    SELECT table_name regexp '[.]' INTO has_db_spec;
    IF has_db_spec = 1
    THEN
        -- Table name has a database part (before the period):
        SET db_name    = SUBSTRING_INDEX(table_name, '.', 1);
        SET table_name = SUBSTRING_INDEX(table_name, '.', -1);
    ELSE
        -- Table name has no period, database is current db:
        SET db_name = DATABASE();
    END IF;

    SELECT data_type
      FROM information_schema.columns
     WHERE table_schema = db_name
       AND table_name = table_name
       AND column_name = prim_fld_name
     ORDER BY column_name
     LIMIT 1 INTO type_field;

    RETURN(type_field);
END// # GET_PRIMARY_KEY_TYPE

#------------------------------ 
# FULLY_QUALIFIED_TABLE_NAME
#-------------

DROP FUNCTION IF EXISTS FULLY_QUALIFIED_TABLE_NAME;

CREATE FUNCTION FULLY_QUALIFIED_TABLE_NAME(table_name varchar(255))
       RETURNS varchar(255)
DETERMINISTIC

BEGIN
/*
    Given a table name that is either of the form myDB.myTable,
    or in the form myTable, return the table name in the form
    myDb.myTable. If just the table name is passed in, myDb will
    be set to the current database.
*/

    DECLARE has_db_spec int;
    DECLARE db_name varchar(255);
    DECLARE NO_DB_SELECTED CONDITION FOR SQLSTATE '45000';

    SELECT table_name regexp '[.]' INTO has_db_spec;
    IF has_db_spec = 1
    THEN
        -- Table name has a database part (before the period):
        SET db_name    = SUBSTRING_INDEX(table_name, '.', 1);
        SET table_name = SUBSTRING_INDEX(table_name, '.', -1);
    ELSE
        -- Table name has no period, database is current db:
        SET db_name = DATABASE();
        IF db_name IS NULL
        THEN
            SIGNAL NO_DB_SELECTED SET MESSAGE_TEXT = 'No database selected';
        END IF;
    END IF;
    RETURN CONCAT(db_name, '.', table_name);
END// # FULLY_QUALIFIED_TABLE_NAME;

#------------------------------                                                                                                 
# DATABASE_NAME
#-------------

DROP FUNCTION IF EXISTS DATABASE_NAME;

CREATE FUNCTION DATABASE_NAME(table_name varchar(255))
       RETURNS varchar(255)
DETERMINISTIC

BEGIN
/*
    Given either a fully qualified, or bare table name, return
    the table's database location. If a bare table name is passed,
    the current database is returned.

    Examples:    foo.bar => foo
                 bar     => result of DATABASE()

    This function is the equivalent of the Unix dirname
*/

    IF POSITION('.' IN table_name) = 0
    THEN
        -- No period found, so this is just a table name;
        -- return current db:
        RETURN(DATABASE());
    ELSE
        -- Grab the string before the period:
        RETURN SUBSTRING_INDEX(table_name, '.', 1);
    END IF;
END// # DATABASE_NAME

#------------------------------
# TABLE_BASENAME
#-------------

DROP FUNCTION IF EXISTS TABLE_BASENAME;

CREATE FUNCTION TABLE_BASENAME(table_name varchar(255))
       RETURNS varchar(255)
DETERMINISTIC

BEGIN
/*
    Given either a fully qualified, or bare table name, return
    the bare table name without the database. If a bare table
    name is passed, it is returned unchanged.

    Examples:    foo.bar => bar
                 bar     => bar

This function is the equivalent of the Unix basename
*/
    IF POSITION('.' IN table_name) = 0
    THEN
        -- No period found, so this is just a table name;
        RETURN(table_name);
    ELSE
        -- Grab the string after the period:
        RETURN(SUBSTRING(table_name FROM POSITION('.' IN table_name)+1));
    END IF;
END// # TABLE_BASENAME

#------------------------------ 
# TEMP_NAME
#-------------

DROP FUNCTION IF EXISTS TEMP_NAME;
CREATE FUNCTION TEMP_NAME(prefix varchar(224)) RETURNS varchar(255)
DETERMINISTIC
BEGIN
/*
    Return a unique name suitable for a table name. Uniqueness
    is as per MySQL's UUID() function. The prefix parameter is
    prepended.
    */
   RETURN  CONCAT(prefix, "_", REPLACE(uuid(), '-', ''));
END// # TEMP_NAME


#--------------------------
# gen_xref_table
#-----------

# Called after the all_evaluation table has been updated.
# Drops and then rebuilds the all_eval_xref
# table. That table maps every course abbreviation (e.g. CS106a)
# to an evalunitid in the all_evaluation table.
#
#   crse_code, termcore, evalunitid
#
# where termcore is called strm elsewhere.
#

DROP PROCEDURE IF EXISTS gen_xref_table;

CREATE PROCEDURE `gen_xref_table`()

BEGIN
    DECLARE done tinyint;
    DECLARE strm int;
    DECLARE xnames varchar(255);
    DECLARE evalid varchar(60);
    DECLARE first_semi_pos int;
    DECLARE second_semi_pos int;
    DECLARE crse_code varchar(15);

    DECLARE curs CURSOR FOR
       SELECT termcore, xlistnames_ec, evalunitid
         FROM all_evaluation;
   
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    SET first_semi_pos = 1;
    SET second_semi_pos = 1;

    
    DROP TABLE IF EXISTS all_eval_xref;
    CREATE TABLE all_eval_xref (
           crse_code varchar(25),
           termcore int,
           evalunitid varchar(60)
           );

    OPEN curs;
    SET done = 0;
    REPEAT
        FETCH curs INTO strm,xnames,evalid;

        eachXrefCrse: LOOP
          SET second_semi_pos = locate(';', xnames, first_semi_pos);
          IF (second_semi_pos = 0)
          THEN
              SET crse_code = SUBSTRING(xnames FROM first_semi_pos);
              IF (LENGTH(crse_code) = 0)
              THEN
                  SET first_semi_pos = 1;
                  SET second_semi_pos = 1;
                  LEAVE eachXrefCrse;
              END IF;
              SET second_semi_pos = LENGTH(xnames);
          ELSE
              SET crse_code = SUBSTR(xnames, first_semi_pos, second_semi_pos - first_semi_pos);
          END IF;
          
          INSERT INTO all_eval_xref
             VALUES (crse_code, strm, evalid);
          
          SET first_semi_pos = second_semi_pos + 1;
        END LOOP eachXrefCrse;

    UNTIL done END REPEAT;
    CLOSE curs;
    CREATE INDEX crseCodeIndx ON all_eval_xref(crse_code);
    CREATE INDEX crseStrmIndx ON all_eval_xref(crse_code,termcore);
    CREATE INDEX evalIndx ON all_eval_xref(evalunitid);
END//

#------------------------------ 
# crosslists
#-------------

# Given a course identifier, select and output
# all cross-listed courses. Example:
#
#     call crosslists('ENGR 070A');

#     +-----------+
#     | crse_code |
#     +-----------+
#     | CS 106A   |
#     | ENGR 070A |
#     +-----------+


DROP PROCEDURE IF EXISTS crosslists;
CREATE PROCEDURE crosslists(in reference_crse_code varchar(50))
BEGIN
    SELECT distinct crse_code
     FROM (SELECT evalunitid
             FROM all_eval_xref
            WHERE  crse_code = reference_crse_code
            LIMIT  1
          ) AS CrseXrefEvalUnit
          LEFT JOIN all_eval_xref USING(evalunitid)
    WHERE evalunitid = CrseXrefEvalUnit.evalunitid;
END//



#------------------------------ 
# TOTAL_ENROLLMENT
#-------------

DROP FUNCTION IF EXISTS total_enrollment;

CREATE FUNCTION TOTAL_ENROLLMENT(the_subject varchar(8), 
                                 the_catalog_nbr varchar(10), 
                                 the_strm int,
                                 count_xlisted_distinctly tinyint)
   RETURNS INT
   DETERMINISTIC
BEGIN
/*
Given a course name, quarter, and a policy about cross-listed
courses, return the total enrollment. If count_xlisted_distinctly
is 1, or NULL, then the enrollment number will include students 
from other courses that might be cross-listed with the given course.
I.e. the returned number is the grand total. 

Otherwise only the students enrolled for the given class are
counted.

The course is provided by the subject and catalog numbers. The 
count_xlisted_distinctly is 1, 0, or NULL. If null, the default
of 1 is chosen, returning the grand total.

Examples: 
   SELECT TOTAL_ENROLLMENT('stats', '60', 1172, NULL)
   ==> 106
   SELECT TOTAL_ENROLLMENT('stats', '60', 1172, 1)
   ==> 106
   SELECT TOTAL_ENROLLMENT('psych', '10', 1172, 1)
   ==> 106
   SELECT TOTAL_ENROLLMENT('stats', '160', 1172, 1)
   ==> 106

But:

   SELECT TOTAL_ENROLLMENT('stats', '160', 1172, 0)
   ==> 2

   SELECT TOTAL_ENROLLMENT('stats', '60', 1172, 0)
  ==> 77

   SELECT TOTAL_ENROLLMENT('psych', '10', 1172, 0)
  ==> 27

Assumptions: 
       * the function is run where table student_enrollment
         is available

*/

    DECLARE the_crse_id INT;
    DECLARE total_enrollment INT;

    -- Default the count xlisted distinctly is 0
    IF count_xlisted_distinctly IS NULL
    THEN
        SET count_xlisted_distinctly = 0;
    END IF;

    -- Get crse_id for the course during that quarter:

    IF count_xlisted_distinctly
    THEN
        SELECT COUNT(distinct emplid) INTO total_enrollment
          FROM student_enrollment
         WHERE subject     = the_subject
           AND catalog_nbr = the_catalog_nbr
           AND strm        = the_strm;
      
         RETURN(total_enrollment);
    END IF;

    -- Count all students from all cross-listed courses:

    SELECT crse_id INTO the_crse_id
      -- ******FROM student_enrollment
      FROM table_load_workspace.student_enrollment
     WHERE subject     = the_subject
       AND catalog_nbr = the_catalog_nbr
       AND strm        = the_strm
     LIMIT 1;
     
    -- Count ALL students, taking any of the xlisted
    -- courses during the given strm:

    SELECT COUNT(distinct emplid) INTO total_enrollment
      FROM student_enrollment
     WHERE crse_id = the_crse_id
       AND strm    = the_strm;

    RETURN(total_enrollment);
END//

#--------------------------
# prependCourseZeroIfNeeded
#--------------------------

# Given a course name, ensure that the number
# part has three digits, prepending zeros if
# needed.
# Examples: 'chem 19'   = 'chem 019'
#           'chem 2'    = 'chem 002'
#           'chem 2ABS' = 'chem 002ABS'
#           'chem 123'  = 'chem 123'
    
DROP FUNCTION IF EXISTS prependCourseZeroIfNeeded; //
CREATE FUNCTION prependCourseZeroIfNeeded(course_name varchar(20))
RETURNS VARCHAR(21)
DETERMINISTIC
BEGIN
    # Isolate the course number (e.g. 41, 041, 41X, 041X, 100ASB):
    SELECT 1 + INSTR(course_name, ' ') INTO @course_num_start;
    # Course name is from pos 1 to start of number minus 2 (back over the space):
    SELECT SUBSTR(course_name, 1, @course_num_start - 2) INTO @course_name_part;
    SELECT substr(course_name, @course_num_start) INTO @course_num_part;

    IF (@course_num_part regexp '[0-9][0-9][0-9]')
    THEN
        # Number already has three digits:
        RETURN course_name;
    ELSEIF (@course_num_part regexp '[0-9][0-9]')
    THEN
        # Number has two digits
        RETURN CONCAT(@course_name_part, ' 0', @course_num_part);
    ELSE
        # Number has 1 digit:
        RETURN CONCAT(@course_name_part, ' 00', @course_num_part);
    END IF;
END//


#--------------------------
# print
#--------------------------

# PRINT procedure for progress messages:

drop procedure if exists print;
create procedure print(str varchar(255))
begin
    select concat(now(), ': ', str) as '';
end//


DELIMITER ;
