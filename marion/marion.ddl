define database "marion.gdb" page_size 4096;


/*	Global Field Definitions	*/

define field CHANGED_BY varying [10]
	query_name WHO;
define field CHANGE_NO long;
define field CHANGE_TAG varying [128]
	query_name BRIEF;
define field CHANGE_WHAT blob segment_length 80
	query_name FULL;
define field COMMENT blob segment_length 80;
define field COMPONENT varying [20];
define field C_NO long;
define field DATE date;
define field DERIVATIVE short
	valid if (derivative = 1 OR 
	       derivative MISSING);
define field DESC varying [128];
define field D_MODULE varying [40];
define field FILE_TYPE char [5]
	missing_value is "   ";
define field FLAGS short;
define field HEADER blob segment_length 255;
define field HOST varying [20];
define field KIT_DATE date;
define field KIT_MAKER varying [20];
define field KIT_NAME varying [20];
define field LOG_NAME varying [20];
define field MAKEFILE blob segment_length 80 sub_type text;
define field MODULE varying [40];
define field NAME char [10];
define field OP_SYST varying [10];
define field OS short;
define field OUT_DATE date;
define field PLATFORM varying [15];
define field PLATFORM_CODE char [2];
define field PYXIS$FORM blob segment_length 80
	system_flag 2;
define field PYXIS$FORM_NAME char [31]
	system_flag 2;
define field PYXIS$FORM_TYPE char [16]
	system_flag 2;
define field QLI$PROCEDURE blob segment_length 80 sub_type text
	system_flag 2;
define field QLI$PROCEDURE_NAME char [31]
	system_flag 2;
define field RDB$2 date;
define field RETURN_DATE date
	query_name WHEN;
define field SHARED_BY varying [40];
define field SINCE date;
define field SOURCE blob segment_length 256;
define field TAKE_DATE date;
define field USR varying [10]
	missing_value is " ";
define field VERSION char [16];
define field WHERE varying [128];


/*	Relation Definitions	*/


define relation BASE_LEVEL
    VERSION	position 0;

define relation CHANGE_NOS
    CHANGE_NO	position 1;

define relation COMPONENTS
    COMPONENT	position 0
	query_name COMP,
    DESC;

define relation DEPENDENCIES
    MODULE	position 0
	query_name MOD,
    COMPONENT	position 1,
    DEPENDENCY based on MODULE	position 2
	query_name CHILD;

define relation EXTRACTS
    LOG_NAME	position 0,
    DATE	position 1,
    COMPONENT	position 2,
    SINCE	position 3;

define relation EXTRACT_FILES
    LOG_NAME	position 0,
    DATE	position 1,
    COMPONENT	position 2,
    MODULE	position 3;

define relation FILE_STACK
    MODULE	position 1
	query_name MOD,
    COMPONENT	position 2,
    D_MODULE	position 3,
    SOURCE	position 4,
    USR	position 5;

define relation HISTORY
    OUT_DATE	position 0,
    RETURN_DATE	position 1,
    CHANGED_BY	position 2,
    CHANGE_WHAT	position 3,
    CHANGE_TAG	position 4,
    MODULE	position 5
	query_name MOD,
    COMPONENT	position 6
	query_name COMP,
    CHANGE_NO	position 7,
    HOST,
    DIFFS based on SOURCE,
    WHERE;

define relation KIT_RELEASE
    KIT_NAME	position 0,
    OP_SYST	position 1,
    KIT_DATE	position 2,
    COMPONENT	position 3,
    KIT_MAKER	position 4,
    COMMENT	position 5;

define relation MAKE_HISTORY
    COMPONENT	position 0,
    PLATFORM_CODE	position 1,
    WHO based on CHANGED_BY	position 2,
    WHEN based on RETURN_DATE	position 3,
    WHAT based on CHANGE_TAG	position 4,
    MAKEFILE	position 5;

define relation MAKE_TEMPLATES
    COMPONENT	position 0,
    PLATFORM_CODE	position 1,
    MAKEFILE	position 2;

define relation PLATFORMS
    PLATFORM_CODE	position 0,
    PLATFORM	position 1,
    OS	position 2;

define relation PYXIS$FORMS
	system_flag 2
    PYXIS$FORM_NAME	position 1
	system_flag 2,
    PYXIS$FORM_TYPE	position 2
	system_flag 2,
    PYXIS$FORM	position 3
	system_flag 2;

define relation QLI$PROCEDURES
	system_flag 2
    QLI$PROCEDURE_NAME	position 0
	system_flag 2,
    QLI$PROCEDURE	position 1
	system_flag 2;

define relation QUEUE
    MODULE	position 1,
    COMPONENT	position 2,
    USR	position 3,
    DATE	position 4;

define relation SHARED
    MODULE	position 0
	query_name MOD,
    COMPONENT	position 1,
    SHARED_BY	position 2,
    TAKE_DATE	position 3;

define relation SOURCES
    FILE_TYPE	position 0,
    COMPONENT	position 1
	query_name COMP,
    MODULE	position 2
	query_name MOD,
    SOURCE	position 3,
    HEADER	position 4,
    DERIVED_FROM based on MODULE
	query_name SRC,
    FLAGS,
    OS;

define relation TESTDATE
    C1 based on RDB$2	position 0;


/*	View Definitions	*/


define view IN_USE of h in history with 
		h.out_date not missing and h.return_date missing
			        H.OUT_DATE	position 0,
    PERSON FROM H.CHANGED_BY	position 1,
    INTENT FROM H.CHANGE_TAG	position 3,
    WHAT varying [61] computed by (h.module |" "| h.component)	position 2;


/*	Index Definitions	*/


define index COMP_INDEX for COMPONENTS unique
	COMPONENT;

define index DEP_INDEX for DEPENDENCIES 
	COMPONENT;

define index DERIV_IDX for FILE_STACK unique
	D_MODULE,
	COMPONENT;

define index HISTORY_DATE for HISTORY 
	RETURN_DATE;

define index HIST_IDX2 for HISTORY 
	CHANGE_NO;

define index HIST_IDX3 for HISTORY 
	MODULE;

define index HIST_INDEX for HISTORY 
	COMPONENT,
	MODULE;

define index MAKE_INDEX for MAKE_TEMPLATES 
	COMPONENT,
	PLATFORM_CODE;

define index PYXIS$INDEX for PYXIS$FORMS unique
	PYXIS$FORM_NAME;

define index BY_NAME_IDX for SOURCES unique
	MODULE,
	COMPONENT;

define index DERIVED_INDEX for SOURCES 
	DERIVED_FROM;

/*	Add Security Classes to Defined Objects	*/



modify relation RDB$ROLES
	security_class SQL$RDB$ROLES;

modify relation TESTDATE
	security_class SQL$TESTDATE;


/*	Security Class Definitions / GRANT statements	*/


grant SELECT on RDB$ROLES to PUBLIC;

grant DELETE on RDB$ROLES to SYSDBA with grant option;

grant INSERT on RDB$ROLES to SYSDBA with grant option;

grant SELECT on RDB$ROLES to SYSDBA with grant option;

grant UPDATE on RDB$ROLES to SYSDBA with grant option;

grant DELETE on TESTDATE to BUILDER;

grant INSERT on TESTDATE to BUILDER;

grant SELECT on TESTDATE to BUILDER;

grant UPDATE on TESTDATE to BUILDER;


/*	Trigger Definitions	*/



define trigger CHANGE_NOS$STORE for CHANGE_NOS
	pre store 0:
if any c in change_nos 
with c.change_no > 0
abort 8;


	end_trigger;

define trigger FILE_STACK$STORE for FILE_STACK
	pre store 0:
begin
	new.usr = rdb$user_name;
        end;
    
	end_trigger;

define trigger HISTORY$STORE for HISTORY
	pre store 0:
begin
	if any h in history with new.component = h.component and
	new.module = h.module and h.return_date missing
	abort 4
	new.changed_by = rdb$user_name;
	new.out_date = 'today';
	end;
	

	end_trigger;

define trigger MAKE_HISTORY$STORE for MAKE_HISTORY
	pre store 0:
begin
	new.who = rdb$user_name;
	new.when = "today"
	end;

	end_trigger;

define trigger QUEUE$STORE for QUEUE
	pre store 0:
begin
	new.usr = rdb$user_name;
	new.date = 'today';
	end;

	end_trigger;

define trigger SOURCES$MODIFY for SOURCES
	pre modify 0:
begin
  if old.derived_from missing
  if any h in history with 
		old.module = h.module and old.component = h.component 
		and not h.changed_by = rdb$user_name and h.return_date missing
		abort 4;
	    else
		if not any h in history with 
		old.module = h.module and old.component = h.component 
		and h.return_date missing
		abort 5;
  end;


	end_trigger;

define trigger SOURCES$STORE for SOURCES
	pre store 0:
begin
        if not any c in components with 
    	    new.component = c.component
	        abort 1;
		else if any s in sources with 
	    new.component = s.component and
	    new.module = s.module
		abort 2;
		else 
		store h in history
	    h.changed_by = rdb$user_name;
	    h.change_tag = "history begins";
	    h.out_date = 'today';
	    h.module = new.module;
	    h.component = new.component;
		end_store;
	end;	

    
    
    
	end_trigger;


