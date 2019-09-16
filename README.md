# mysql_utils
Collection of MySQL functions and procedures

Only some of the MySQL functions and procedures included are of
general interest. I don't have time to set aside the locally relevant
ones.

# H1 Generally Useful Functions and Procedures


- CREATE PROCEDURE createIndexIfNotExists (IN the_index_name varchar(255),
- CREATE PROCEDURE dropIndexIfExists (IN the_table_name varchar(255),
- CREATE PROCEDURE desca(IN the_table_name varchar(255))
- CREATE PROCEDURE RANDOM_ROWS  (IN src_tbl_name varchar(255),
- CREATE function COLUMN_NAMES(db_name varchar(255),
- CREATE PROCEDURE RANDOM_COL_VALUE(IN tbl_name varchar(255),
- CREATE FUNCTION get_primary_key_fld(table_name VARCHAR(255)) RETURNS varchar(255)
- CREATE FUNCTION GET_PRIMARY_KEY_TYPE(table_name VARCHAR(255)) RETURNS varchar(255)
- CREATE FUNCTION FULLY_QUALIFIED_TABLE_NAME(table_name varchar(255))
- CREATE FUNCTION DATABASE_NAME(table_name varchar(255))
- CREATE FUNCTION TABLE_BASENAME(table_name varchar(255))
- CREATE FUNCTION TEMP_NAME(prefix varchar(224)) RETURNS varchar(255)


## H2 Locally relevant only:

Files mysqlProcAndFuncBodies.sql and mysqlProcs.sql contain the
following special purpose routines that are relevant only locally.

### H3 File mysqlProcAndFuncBodies.sql

File mysql/mysqlProcAndFuncBodies.sql contains all the general purpose
routines, but also many that are related to json_to_relation

- CREATE FUNCTION idAnon2Int(anonId varchar(40))
- CREATE FUNCTION idInt2Forum(intId int(11))
- CREATE FUNCTION idForum2Anon(forumId varchar(255))
- CREATE FUNCTION idForum2Int(forumId varchar(255))
- CREATE FUNCTION idInt2Anon(intId int(11))
- CREATE FUNCTION idExt2Anon(extId varchar(100))
- CREATE FUNCTION idAnon2Ext(the_anon_screen_name varchar(40))
- CREATE FUNCTION idAnon2ExtByCourse(the_anon_id varchar(255), course_display_name varchar(255))
- CREATE PROCEDURE idAnon2Exts(the_anon_id varchar(255))
- CREATE FUNCTION wasCertified(anon_screen_name varchar(40), course_display_name varchar(255))
- CREATE FUNCTION  extractCourseraCourseName(courseraDbName varchar(255))
- CREATE FUNCTION isSharable(the_course_display_name varchar(255))
- CREATE FUNCTION  extractNovoEdCourseName(novoEdDbName varchar(255))
- CREATE FUNCTION  extractOpenEdXMoocDbCourseName(openEdxMoocDbDbName varchar(255))
- CREATE FUNCTION  extractMoocDbCourseName(maybeMoocDbName varchar(255))
- CREATE FUNCTION isMoocDbCourseName(maybeMoocDbName varchar(255))
- CREATE FUNCTION isUserEvent (an_event_type varchar(255))
- CREATE FUNCTION isEngineering(course_display_name varchar(255)) RETURNS tinyint
- CREATE FUNCTION isEngagementEvent (an_event_type varchar(255))
- CREATE PROCEDURE `createExtIdMapByCourse`(IN the_course_name varchar(255), IN tblName varchar(255))
- CREATE FUNCTION wordcount(str TEXT)
- CREATE FUNCTION isTrueCourseName(course_display_name varchar(255))
- CREATE FUNCTION enrollment(the_course_display_name varchar(255))
- CREATE FUNCTION `isDirectAccessUser`(anon_screen_name varchar(255)) RETURNS tinyint(1)
- CREATE PROCEDURE computeEnrollmentCoursera(IN course_name varchar(255), OUT enrollment INT)
- CREATE PROCEDURE computeEnrollmentNovoEd(IN course_name varchar(255), OUT enrollment INT)
- CREATE PROCEDURE `multipleDbQuery`(dbNameRegex varchar(255),
- CREATE FUNCTION dateInQuarter(dateInQuestion DATETIME, quarter varchar(6), academic_year varchar(4))
- CREATE FUNCTION makeUpperQuarterDate(quarter varchar(6), academic_year INT)
- CREATE FUNCTION `makeLowQuarterDate`(quarter varchar(6), academic_year INT)
- CREATE FUNCTION `videoNextProblem`(in_course_display_name VARCHAR(255),
- CREATE PROCEDURE allHomeworkSubmissionsToFile(IN the_course_display_name varchar(255),
- CREATE PROCEDURE allHomeworkSubmissions(IN the_course_display_name varchar(255))
- CREATE VIEW EventXtract AS
- CREATE VIEW Performance AS
- CREATE VIEW FinalGrade AS
- CREATE VIEW VideoInteraction AS
- CREATE VIEW Demographics AS


### H3 File mysqlProcs.sql

This file contains all the general purpose routines, but also a few
about Carta:


- CREATE FUNCTION STRMDIFF(strm1 int, strm2 int)
- CREATE FUNCTION strm2Quarter(strm int)
- CREATE FUNCTION date2Strm(the_date date) RETURNS int
- CREATE FUNCTION STRM_OF_DATE(the_date date) RETURNS int
- CREATE FUNCTION MAJOR(the_emplid varchar(255)) RETURNS varchar(10)
- CREATE FUNCTION  STUDYFIELD_FROM_ACAD_PLAN(plan varchar(30))
- CREATE FUNCTION course_json(json_data MEDIUMTEXT, wanted_fld VARCHAR(255))
- CREATE PROCEDURE parse_course_json(
- CREATE PROCEDURE `gen_xref_table`()
- CREATE PROCEDURE crosslists(in reference_crse_code varchar(50))
- CREATE FUNCTION TOTAL_ENROLLMENT(the_subject varchar(8), 
- CREATE FUNCTION prependCourseZeroIfNeeded(course_name varchar(20))
