/*
 *	PROGRAM:	SMM source maintainence manager 
 *	MODULE:		marion.e	
 *	DESCRIPTION:	a database application for managing source code	
 */                                         
  
/*
 * The contents of this file are subject to the InterBase Public License
 * Version 1.0 (the "License"); you may not use this file except in
 * compliance with the License.
 * 
 * You may obtain a copy of the License at http://www.Inprise.com/IPL.html.
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.  The Original Code was created by Inprise
 * Corporation and its predecessors.
 * 
 * Portions created by Inprise Corporation are Copyright (C) Inprise
 * Corporation. All Rights Reserved.
 * 
 * Contributor(s): ______________________________________.
 */

#include <stdlib.h>
#include <string.h>
#include "../marion/marion.h"
                         
USHORT	quit;
TEXT	share_since_date[30];
TEXT 	component[20];
TEXT 	pathname [60];
TEXT 	log_name [60];
TEXT 	dbb_name [128];
TEXT	user_name [64];
TEXT	password [64];
USHORT 	op_sys_code, log_info;
USHORT	verbose;
USHORT	smm_since;
USHORT	smm_version;
USHORT	doc_version;
SSHORT	headers;
USHORT	capabilities;

#ifdef VMS
#define OP_SYS_CODE	OS_VMS
#define DBB_NAME	"marion_db"
#endif

#ifdef PC_PLATFORM
#define OP_SYS_CODE	OS_PC
#define DBB_NAME	"jedi:/usr/gds/dev/marion.gdb"
#endif

#if (defined WIN_NT || defined OS2_ONLY)
#define OP_SYS_CODE	OS_WIN_NT
#define DBB_NAME	"yoda:/usr/gds.yoda/dev/marion.gdb"
#define COMPARE		stricmp
#endif

#ifdef mpexl
#define OP_SYS_CODE	OS_MPEXL
#endif

#ifdef apollo
#define OP_SYS_CODE	OS_UNIX
#endif

#ifdef sun
#ifndef SOLARIS
#define OP_SYS_CODE	OS_UNIX
#endif
#endif

#ifdef MAC
#define OP_SYS_CODE	OS_UNIX
#endif

#ifdef ultrix
#define OP_SYS_CODE	OS_UNIX
#endif

#ifdef DGUX
#ifdef DG_X86
#define OP_SYS_CODE	OS_UNIX_NO_DOLLAR
#else
#define OP_SYS_CODE	OS_UNIX
#endif /* DG_X86 */
#endif /* DGUX */

#ifndef OP_SYS_CODE
#ifdef UNIX
#define OP_SYS_CODE	OS_UNIX_NO_DOLLAR
#else
#define OP_SYS_CODE	NONE
#endif
#endif

#ifndef DBB_NAME
#define DBB_NAME	"source/marion.gdb"
#endif

#ifdef VMS
#define LOG_FILE "SYS$LOGIN:MAKE_%s.LOG"
#endif

#define STD_NAME	"MARION"
#define DV_NAME		"GUS"

#ifndef COMPARE
#define COMPARE strcasecmp
#endif

DATABASE 
	SMM = COMPILETIME FILENAME "marion.gdb";

extern	EXEC_run();

#ifdef _ANSI_PROTOTYPES_
extern int	set_component (TEXT *);
#else
extern int	set_component();
#endif

static int	abandon PROTO ((TEXT *));
static int	add_component PROTO ((TEXT *));
static int	add_derivative PROTO ((TEXT *));
static int	add_module PROTO ((TEXT *, TEXT *));
static int	clear_path PROTO ((void));
static int	commit PROTO ((void));
static int	echo_values PROTO ((void));
static int	get_module PROTO ((TEXT *, TEXT *));
static int	init PROTO ((void));
static int	interact PROTO ((void));
static int	list_all PROTO ((TEXT *));
static int	list_components PROTO ((void));
static int	list_history PROTO ((TEXT *, TEXT *));
static int	list_modules PROTO ((TEXT *, TEXT *));
static int	moby_put PROTO ((TEXT *));
static int	multiple_add PROTO ((void));
static int	multiple_share PROTO ((TEXT *));
static int	my_modules PROTO ((void));
static int	obsolete PROTO ((TEXT *, TEXT *));
static int	out_report PROTO ((TEXT *));
static int	put_module PROTO ((TEXT *, TEXT *));
static int	queue PROTO ((TEXT *, TEXT *));
static int	reinstate PROTO ((TEXT *, TEXT *));
static int	rollback PROTO ((void));
static int	share_module PROTO ((TEXT *, TEXT *));
static int	set_opsys PROTO ((TEXT *));
static int	set_or_clear_obsolete PROTO ((TEXT *,TEXT *, USHORT));
static int	set_pathname PROTO ((TEXT *));

/* the command structure */

static struct cmd {
    SCHAR	*cmd_string;
    int		(*cmd_routine) ();
    SCHAR	*cmd_text;
    SSHORT	cmd_args;
} commands [] = {
    "A!", abandon, "Abandon! (module) ... Instead of PM,\n\t\trelinquish module without changes",2,
    "AC", add_component, "Add Component (name) ...\n\t\t\tAdd a new component to components",2,
    "AD", add_derivative, "Add Derivative (module, component)\n\t\tMove a derived file into database", 1,
    "AM", add_module, "Add Module (name, [infile])\n\t\tMove a new module into database", 1,
    "C",  commit, "Commit",0,
    "CP", clear_path, "Clear Pathname ... Resets pathname to null",0,
    "EV", echo_values, "Echo Values\n\t\tpathname, operating system and component if they are set", 0,
    "GM", get_module, "Get Module (module, [outfile])\n\t\tCopy a module to a file for modifications", 2,
    "INIT", init, "Provide initial values for a new marion.gdb",0,
    "LA", list_all,    "List All modules",1,
    "LC", list_components, "List Components",0,
    "LH", list_history, "List History (component, module)\n\t\t date, history, user",1,
    "LM", list_modules, "List Modules (component) in the named component",0,
    "MA", multiple_add, "Moby Add ... more than one module", 0,
    "MS", multiple_share, "Multiple Share ... more than one module",0,
    "MP", moby_put, "Multiple module put ...\n\t\treturn a group of modules to one component", 1,
    "MY", my_modules, "MY files ...\n\t\treport modules checked out with my user_name", 1,
    "OBS", obsolete, "OBSolete (module, [comp]) ... set module obsolete", 1,
    "OR", out_report, "Out Report ... show modules currently checked out", 1,
    "PM", put_module, "Put Module (module, [infile])\n\t\tReturns modified module to database",2,
    "QUEUE", queue, "QUEUE for file (module, [comp]) ... be notified of checking", 1,
    "RUN", EXEC_run, "RUN, (command_file) ... \n\t\texecute the specified command file.", 1,
    "SC", set_component, "Set Component (name)\n\t\tSpecify component for subsequent commands", 1,
    "SO", set_opsys, "Set Operating system\n\t\tChoose os2, vms, apollo",1, 
    "SP", set_pathname, "Set Path (name)\n\t\tSpecify pathname for subsequent file reads and writes.",1,
    "SM", share_module, "Share Module (module, [outfile])\n\t\tCopy module to file (use, but don't change).", 2,
    "XOB", reinstate, "XOBsolete  (module, [component])\n\t\tChange obsolete file's status to current", 1,
    "QUIT", NULL, "Exit from SMM",0,
    NULL, NULL, NULL, 0};

/* 
   table used to determine capabilities, checking for specific 
   fields in system relations 
*/

typedef struct rfr_tab_t {
    TEXT	*relation;
    TEXT	*field; 
    int		bit_mask;
} *RFR_TAB;
 
static struct rfr_tab_t rfr_table [] = {
	(TEXT *) "SOURCES",	(TEXT *) "HEADER",	CAP_header_field,
	0, 0, 0
};

#ifdef _ANSI_PROTOTYPES_
int CLIB_ROUTINE main (
    int		argc,
    SCHAR	*argv[])
#else
int CLIB_ROUTINE main (argc, argv)
    int		argc;
    SCHAR	*argv[];
#endif
{
/**************************************
 *
 *	m a i n
 *
 **************************************
 *
 * Functional description
 *	Main routine. Checks for a file in
 *	the user's home directory which contains
 *	database name and default component.
 *	Will parse command line database name and
 *	component.Opens the named or default db
 *	sets the component if any and hands over to loop.
 *
 **************************************/
TEXT 	sw_version [64];
TEXT  	opsys [10];
USHORT	share_command, any_base_level;
RFR_TAB	rel_field_table;

strcpy (dbb_name, DBB_NAME);
strcpy (sw_version, STD_NAME);

op_sys_code = OP_SYS_CODE;
log_info = doc_version = verbose = share_command = FALSE;
STUFF_use_argfile(dbb_name);
share_command = STUFF_handle_switches (argc, argv, dbb_name);

if (doc_version)
    strcpy (sw_version, DV_NAME);

/* Remove this line when SR10.4 is running and our Lock
   Manager threads aren't blocked while scripts run */

gds__set_debug (1L);

/* ready the database */

if (!user_name [0])
    {
    READY dbb_name AS SMM;
    }
else
    {
    READY dbb_name AS SMM USER user_name PASSWORD password;
    }
START_TRANSACTION;

/* Set capabilities by looking for desireable fields in system relations */

for (rel_field_table = rfr_table; rel_field_table->relation; rel_field_table++)
    {
    FOR X IN RDB$RELATION_FIELDS WITH
	X.RDB$RELATION_NAME EQ rel_field_table->relation AND
	X.RDB$FIELD_NAME EQ rel_field_table->field

	capabilities |= rel_field_table->bit_mask;

    END_FOR;
    }

if (!share_command)
    {   
    if (*component)
	set_component (component);

    FOR B IN BASE_LEVEL
	printf("\nWELCOME TO %s %s    %s\n\n",
	    sw_version, B.VERSION, VERSION);
    END_FOR;

    if (smm_version)
	gds__version (&SMM, NULL, NULL);

    echo_values();
    printf ("\n");

    while (interact())
	;
    }
else
    {
    STUFF_share_command();
    if (smm_version)
	{
	any_base_level = FALSE;

	FOR B IN BASE_LEVEL
	    any_base_level = TRUE;
	    printf("Marion version %s for %s\n", VERSION, B.VERSION);
	END_FOR;

	if (!any_base_level)
	    printf ("Marion version %s\n", VERSION);
	echo_values();
	gds__version (&SMM, NULL, NULL);
	}
    }

COMMIT;
FINISH SMM;
exit (FINI_OK);
}

#ifdef _ANSI_PROTOTYPES_
static int abandon (
    TEXT	*module)
#else
static abandon (module)
    TEXT	*module;
#endif
{
/**************************************
 *
 *	a b a n d o n
 *
 **************************************
 *
 * Functional description
 *	Abandon modification of a module
 *	Does reality check user/module/record
 *
 *	10/88 added failure message.	
 *
 **************************************/
TEXT	comp [20];
USHORT	history_count = 0, queue_count = 0;

STUFF_manage_component (comp);

FOR H IN HISTORY WITH
    H.COMPONENT EQ comp AND
    H.MODULE EQ module AND
    H.CHANGED_BY EQ RDB$USER_NAME AND
    H.RETURN_DATE MISSING

    ERASE H;
    history_count++;

END_FOR;

/* get rid of the any entries in the checkout queue;
   figure out whether we were next in line in the queue */

FOR Q IN QUEUE WITH
    Q.COMPONENT EQ comp AND
    Q.MODULE EQ module AND
    Q.USR EQ RDB$USER_NAME

    ERASE Q;
    queue_count++;

END_FOR;
            
if (!history_count && !queue_count)
    {
    if (!STUFF_who_has (module, comp))
	printf ("%s in %s is not checked out.\n", module, comp);

    /* assume that abandon in this case means to pass on the 
       module to the next user in the queue */

    STUFF_notify_queue (comp, module);
    }
    
/* if we had the module out, notify the next user that
   it is now available */

if (history_count)
    STUFF_notify_queue (comp, module);

commit();
}

#ifdef _ANSI_PROTOTYPES_
static int add_component (
    TEXT 	*name)
#else
static add_component (name)
    TEXT 	*name;
#endif
{
/**************************************
*
*	a d d _ c o m p o n e n t
*
**************************************
*
* Functional description
*	Add a new component name to the database
*
**************************************/

STORE C IN COMPONENTS USING
    strncpy (C.COMPONENT, name, 19);
END_STORE
ON_ERROR
    {
    if (gds__status[1] == isc_no_dup)
        STUFF_error_report (name, "", 6, NULL);
    else
	STUFF_error_report (name, "", 0, gds__status);
    rollback();
    return;
    }
END_ERROR;

commit();
}

#ifdef _ANSI_PROTOTYPES_
static int add_derivative (module)
    TEXT	*module;    
#else
static add_derivative (module)
    TEXT	*module;    
#endif
{
/**************************************
 *
 *	a d d _ d e r i v a t i v e 
 *
 **************************************
 *
 * Functional description
 * 	Allows the user to store in the database files derived
 *	from a file under marion.  called by interact (AD) 
 *	and by add_module
 *
 **************************************/
TEXT	comp [20];

if (doc_version)
    {
    printf ("AD is irrelevant to document management.\n");
    return;
    }

STUFF_manage_component (comp);

if (!(STUFF_checked_out_by_me (comp, module, NULL)))
    return;

if (!(STUFF_store_derivative (module, comp)))
    {
    rollback();
    return;
    }

commit();
}

#ifdef _ANSI_PROTOTYPES_
static int add_module (
    TEXT 	*module,
    TEXT	*infile)
#else
static add_module (module, infile)  
    TEXT 	*module, *infile;
#endif
{
/************************************** 
 *
 *	a d d _ m o d u l e   
 *
 ***************************************
 *
 * Functional description
 *      Prompt user for name of new module
 *      Store other fields in source, history
 *      load blob from file
 *      
 *      reorganized 10/19/88 :
 *      a two part store:
 *      (now adding works like putting). To do this
 *      we've modified the store trigger on source
 *      - return date in history must be manually set.
 *
 *      in the middle we add any derived files.
 *
 ************************************/ 
TEXT	comp [20], s [4];

STUFF_manage_component (comp);
STUFF_upcase (module, module); 

if (!STUFF_init_source(comp, module) ||
    !STUFF_update_source (module, comp, infile))
    {
    rollback();
    return;
    }

if (!doc_version)
    {
    printf  ("Are any files derived from %s on ", module); 
    STUFF_echo_osname (op_sys_code, FALSE);
    STUFF_get_string  ("?(y or n)", s, 4);
    
    if (*s == 'y' || *s == 'Y')  
        if (!STUFF_store_derivative (module, comp)) 
            {
            rollback();
            return;
            }
    }

STUFF_close_history (module, comp); 

EXEC_run (ADD_TEMPLATE, module, comp, NULL, TRUE);
commit();
}

#ifdef _ANSI_PROTOTYPES_
static int clear_path (void)
#else
static clear_path ()
#endif
{
/**************************************
 *
 *	c l e a r _ p a t h
 *
 **************************************
 *
 * Functional description
 * 	reset path to null
 *
 **************************************/

*pathname = 0;
}

#ifdef _ANSI_PROTOTYPES_
static int commit (void)
#else
static commit ()
#endif
{
/**************************************
 *
 *	c o m m i t
 *
 **************************************
 *
 * Functional description
 *	Commit the default transaction.
 *
 **************************************/

if (gds__trans)
    COMMIT;

START_TRANSACTION;
}

#ifdef _ANSI_PROTOTYPES_
static int echo_values (void)
#else
static echo_values ()
#endif
{
/**************************************
 *
 *	e c h o _ v a l u e s
 *
 **************************************
 *
 * Functional description
 *	Show the preset globals.
 *
 **************************************/

printf ("Component = %s\nPath = %s\nOperating System = ",
    component, pathname);	
STUFF_echo_osname (op_sys_code, TRUE);
}

#ifdef _ANSI_PROTOTYPES_
static int get_module (
    TEXT	*module,
    TEXT	*outfile)
#else
static get_module (module, outfile)
    TEXT	*module, *outfile;
#endif
{
/**************************************
 *
 *	g e t _ m o d u l e
 *
 **************************************
 *
 * Functional description
 *	Source code check_out with intent to modify
 *	does reality check on names of module component
 *	checks history.changed_by with return_date missing
 *	if  none exists then sets  changed_by and dumps blob to file 
 *	ELSE fingers the current holder
 *      And all most all by function calls! (8/2)
 *
 **************************************/
TEXT	comp [20], s [4];
BOOLEAN	store_history;

STUFF_manage_component (comp);

if (!STUFF_exists_YN (comp, module) ||
    STUFF_derived (comp,module) ||
    STUFF_obsolete (comp, module))
    return;

if (!(store_history = STUFF_store_history (comp, module)) ||
    !STUFF_written_out (comp, module, outfile, headers))
    {
    rollback();

    if (!store_history)
	{
        printf ("Do you want to be notified of checkin"); 
        STUFF_get_string  ("?(y or n)", s, 4);
    
        if (*s == 'y' || *s == 'Y')  
    	    {
  	    STUFF_store_queue (comp, module);
	    commit();
   	    }
	}

    return;
    }

/* get rid of the any of our entries in the checkout queue */

FOR Q IN QUEUE WITH
    Q.COMPONENT EQ comp AND
    Q.MODULE EQ module AND
    Q.USR EQ RDB$USER_NAME

    ERASE Q;

END_FOR;
            
commit();
}

#ifdef _ANSI_PROTOTYPES_
static int init (void)
#else
static init ()
#endif
{
/**************************************
 *
 *	i n i t
 *
 **************************************
 *
 * Functional description
 *
 *	Set the values a marion database needs before it
 *	gets started
 *
 **************************************/
TEXT ver[16];

STORE C IN CHANGE_NOS USING
	C.CHANGE_NO = 1;
END_STORE
ON_ERROR
    rollback();
    return;
END_ERROR;

STUFF_get_string ("Version or base_level (maint, v3, api...)", ver, 16);

STORE V IN BASE_LEVEL USING
	strcpy (V.VERSION, ver);
END_STORE;
}

#ifdef _ANSI_PROTOTYPES_
static int interact (void)
#else
static interact ()
#endif
{
/**************************************
 *
 *	i n t e r a c t
 *
 **************************************
 *
 * Functional description
 *	Read a command, parse it, execute it, and return.  If end of
 *	file, return FALSE.
 *
 **************************************/
struct cmd	*cmd;
TEXT		buffer[128], command[20]; 
TEXT            name[80], name2[80], name3[80], name4[80], *p;
SSHORT		n, c; 
printf ("smm> ");

/* Get command line */

p = buffer;

while (TRUE)
    {
    c = getchar();
    if (c == '\n')
	break;
    if (c == EOF)
	return FALSE;
    *p++ = c;
    }

/* Parse into command and module/component name */

*p = command [0] = name4 [0] = name3 [0] = name2 [0] = name [0] = 0;
n = sscanf (buffer, "%s%s%s%s%s", command, name, name2, name3, name4);

if (n <= 0)
    return TRUE;

/* Upper command and name, name2 is filename, so leave alone */

STUFF_upcase (command, command);
STUFF_upcase (name, name);

/* Interpret command */

for (cmd = commands; cmd->cmd_string; cmd++)
    if (n >= cmd->cmd_args && strcmp (cmd->cmd_string, command) == 0)
	{
        if (!cmd->cmd_routine)
	    return FALSE;
	(*cmd->cmd_routine)(name, name2, name3, name4);
	return TRUE;
	}

printf ("Commands are:\n");

for (cmd = commands; cmd->cmd_string; cmd++)
    printf ("\t%s\t%s\n", cmd->cmd_string, cmd->cmd_text);

return TRUE;
}

#ifdef _ANSI_PROTOTYPES_
static int list_all (
     TEXT    *option)
#else
static list_all (option)
     TEXT    *option;
#endif
{
/**************************************
 *
 *	l i s t _ a l l
 *
 **************************************
 *
 * Functional description
 *	List all modules, sorted by component
 *
 *      option controls printing of obsolete module names
 *      if option = "ALL" we print everything
 *
 **************************************/

FOR C IN COMPONENTS SORTED BY C.COMPONENT
    list_modules (C.COMPONENT, option);
END_FOR;
}

#ifdef _ANSI_PROTOTYPES_
static int list_components (void)
#else
static list_components ()
#endif
{
/**************************************
 *
 *	l i s t _ c o m p o n e n t s
 *
 **************************************
 *
 * Functional description
 *
 *	list components
 *
 **************************************/

FOR C IN COMPONENTS SORTED BY C.COMPONENT
    printf ("%s:\n",C.COMPONENT);
END_FOR;
}

#ifdef _ANSI_PROTOTYPES_
static int list_history (
   TEXT		*comp,
   TEXT		*module) 
#else
static list_history (comp,module)
   TEXT		*comp, *module; 
#endif
{
/**************************************
 *
 *	l i s t _ h i s t o r y
 *
 **************************************
 *
 * Functional description
 *
 **************************************/

if (NULL_STR(comp))
    STUFF_manage_component (comp);	

if (NOT_NULL(module))
    {
    STUFF_upcase (module, module);
    STUFF_report_history (comp, module);
    }
else
    FOR S IN SOURCES WITH S.COMPONENT = comp
        STUFF_report_history (comp, S.MODULE);
    END_FOR;
}

#ifdef _ANSI_PROTOTYPES_
static int list_modules (
	TEXT 	*comp,
	TEXT	*option)
#else
static list_modules (comp, option)
	TEXT 	*comp, *option;
#endif
{
/**************************************
 *
 *	l i s t _ m o d u l e s
 *
 **************************************
 *
 * Functional description
 *	List all modules, in the specified component 
 *      except obsolete ones (unless all specified).
 *
 **************************************/
USHORT	all;

STUFF_upcase (option, option);

all = (NOT_NULL (option)) && !strcmp (option, "ALL");

if (NULL_STR (comp))
    STUFF_manage_component (comp);	

FOR C IN COMPONENTS WITH C.COMPONENT EQ comp

    printf ("%s:\n", C.COMPONENT);

    FOR S IN SOURCES WITH
	S.COMPONENT EQ C.COMPONENT AND
	S.DERIVED_FROM MISSING
	SORTED BY S.MODULE

	if (all)
            printf ("      %s\n", S.MODULE);
	else
	    if (S.FLAGS.NULL || !(S.FLAGS & FLAGS_obsolete))
		{
                printf ("      %s\n", S.MODULE);
		FOR D IN SOURCES WITH
		    D.COMPONENT EQ S.COMPONENT AND
		    D.DERIVED_FROM EQ S.MODULE

		    printf ("            %s derived from %s\n", D.MODULE, S.MODULE);

		END_FOR;
		}

    END_FOR;

END_FOR;
}

#ifdef _ANSI_PROTOTYPES_
static int moby_put (
    TEXT	*comp)
#else
static moby_put (comp)
    TEXT	*comp;
#endif
{
 /**************************************
 *
 *	m o b y _ p u t
 *
  **************************************
 *
 * Functional description
 *
 *	return several modules to a single component
 *	all at once and without doing a make
 *	for each one. 
 *      11/88 the meat of the matter is being moved to
 *      STUFF_loop_change in order to make handling derived
 *      file retrieval less complex
 *
 **************************************/
                
if (!*comp)
    STUFF_manage_component (comp);
            
if (STUFF_loop_change (comp))
   commit();
else
   rollback();
}

#ifdef _ANSI_PROTOTYPES_
static int multiple_add (void)
#else
static multiple_add ()
#endif
{
/**************************************
*
*	m u t i p l e _ a d d
*
**************************************
*
* Functional description
*	Command driven looping add
*
**************************************/
TEXT	module [40], infile [50], *p, c;
TEXT	input [80];
SSHORT	n; 

printf ("Type...module_name, [file_name]\n...'comp', component  to change component\n");
printf ("...'path', pathname  to set path\nor quit to return to command level.\n");

while (TRUE)
    {
    printf ("add> ");
    p = input;

/* Get input line */

    while (TRUE)
	{
	c = getchar();
	if (c == '\n')
	    break;
	*p++ = c;
        }

/* Parse into module/command and infile/component name */

    *p = module [0] = infile [0] = 0;
    n = sscanf (input, "%s%s", module, infile);
    if (n <= 0)
	return TRUE;
    
    if (!*infile) 
	strcpy (infile, module);
    STUFF_upcase (module, module);

    switch (*module)
	{	
	case 'C' :	if (!(strcmp ("COMP",module)))
			    {
			    STUFF_upcase (infile, infile);
			    set_component (infile);
			    break;
			    }
	case 'P' :	if (!(strcmp ("PATH", module)))
			    {
			    set_pathname (infile);
			    break;
			    }
	case 'Q' :	if (!(strcmp ("QUIT",module)))
			    return;

	default  : 	add_module (module, infile);
	}
    }
}

#ifdef _ANSI_PROTOTYPES_
static int multiple_share (
    TEXT	*comp)
#else
static multiple_share (comp)
    TEXT	*comp;
#endif
{
 /**************************************
 *
 *	m u l t i p l e _ s h a r e
 *
  **************************************
 *
 * Functional description
 *	Command driven looping share
 *
 **************************************/
TEXT 	module [40], outfile [50], *p, c;
TEXT 	input [80];
SSHORT	n; 

if (!*comp)
    STUFF_manage_component (comp);
printf ("Type...module_name, file_name\n...'comp', component  to change component\n");
printf ("'all' to share all files in a component\n");
printf ("'verbose' for a listing of files shared\nor \"quit\" to return to command level.\n");

while (TRUE)
    {
    printf ("share> ");

    p = input;

    /* Get input line */

    while (TRUE)
	{
	c = getchar();
	if (c == '\n')
	    break;
	*p++ = c;
	}

    /* Parse into module/command and infile/component name */

    *p = module [0] = outfile [0] = 0;
    n = sscanf (input, "%s%s", module, outfile);
    if (n <= 0)
	return TRUE;

    if (!*outfile) strcpy (outfile, module);
	STUFF_upcase (module, module);

    switch (*module)
	{
	case 'A' :  
	    if (!(strcmp ("ALL", module)))
		{
		STUFF_loop_share (comp);
		break;
		}
					
	case 'C' :
	    if (!(strcmp ("COMP",module)))
		{
		STUFF_upcase (outfile, outfile);
		set_component (outfile);
		break;
		}
	case 'Q' :  
	    if (!(strcmp ("QUIT",module)))
		return;

	case 'V' :  
	    {
	    if (!(strcmp ("VERBOSE",module)))
		verbose = TRUE;
	    break;
	    }

	default  :
	    share_module (module, outfile);
	}
    }
}


#ifdef _ANSI_PROTOTYPES_
static int my_modules(void)
#else
static int my_modules()
#endif
{
/**************************************
 *
 *	m y _ m o d u l e s
 *
 **************************************
 *
 * Functional description
 *	List all files currently checked out by
 *	my current user_name
 *
 **************************************/
struct tm	d;
SCHAR	queued [256], *q;

printf ("Modules currently checked out under this user_name:\n\n");

FOR H IN HISTORY WITH
    H.RETURN_DATE MISSING AND
    H.CHANGED_BY EQ RDB$USER_NAME

    queued [0] = 0;                     
    q = queued;

    FOR QUE IN QUEUE WITH 
	QUE.COMPONENT EQ H.COMPONENT AND
	QUE.MODULE EQ H.MODULE

	if (q == queued)
	    *q++ = '(';

	sprintf (q, "%s ", QUE.USR);
	while (*q) q++;
	
    END_FOR;

    if (q != queued)
	sprintf (q, "waiting)");

    printf ("\t%s %s %s", H.COMPONENT, H.MODULE, H.CHANGED_BY);
    gds__decode_date (&H.OUT_DATE, &d);
    printf (" %d/%d/%d %s\n", d.tm_mon + 1, d.tm_mday, d.tm_year, queued);
    printf ("\t%s\n\n", H.CHANGE_TAG);

END_FOR;

printf ("Modules currently queued for checkout by this user_name:\n\n");

FOR Q IN QUEUE WITH
    Q.USR EQ RDB$USER_NAME

    printf ("\t%s %s", Q.COMPONENT, Q.MODULE);
    gds__decode_date (&Q.DATE, &d);
    printf (" %d/%d/%d\n\n", d.tm_mon + 1, d.tm_mday, d.tm_year);

END_FOR;
            
}

#ifdef _ANSI_PROTOTYPES_
static int obsolete (
    TEXT   *module,
    TEXT   *comp)
#else
static obsolete (module, comp)
    TEXT   *module, *comp;
#endif
{
/**************************************
 *
 *	o b s o l e t e
 *
 **************************************
 *
 * Functional description
 *	Set a module obsolete.
 *
 **************************************/

set_or_clear_obsolete (module, comp, TRUE);
}


#ifdef _ANSI_PROTOTYPES_
static int out_report (TEXT *username)
#else
static int out_report (username)
TEXT	*username;
#endif
{
/**************************************
 *
 *	o u t _ r e p o r t
 *
 **************************************
 *
 * Functional description
 *	Puts info on all currently checked out modules
 *	on the screen
 *
 **************************************/
struct tm	d;

FOR I IN IN_USE

	/* If a username was supplied, only show for that username */

    if (NOT_NULL (username) && COMPARE (I.PERSON, username) != 0)
	continue;

    printf ("%s %s ", I.WHAT, I.PERSON);
    gds__decode_date (&I.OUT_DATE, &d);
    printf (" %d/%d/%d\n", d.tm_mon + 1, d.tm_mday, d.tm_year);
    printf ("%s\n\n", I.INTENT);

END_FOR;
}

#ifdef _ANSI_PROTOTYPES_
static int queue(TEXT *module, TEXT *comp)
#else
static int queue(module, comp)
TEXT	*module;
TEXT	*comp;
#endif
{
/**************************************
 *
 *	q u e u e
 *
 **************************************
 *
 * Functional description
 *	Insert your user name into the queue
 *	for a module.
 *
 **************************************/
if (NULL_STR (comp))
    STUFF_manage_component (comp);

if (!STUFF_exists_YN (comp, module) ||
    STUFF_derived (comp,module) ||
    STUFF_obsolete (comp, module))
    return;

STUFF_store_queue (comp, module);
}

#ifdef _ANSI_PROTOTYPES_
static int rollback (void)
#else
static rollback ()
#endif
{
/**************************************
 *
 *	r o l l b a c k
 *
 **************************************
 *
 * Functional description
 *	commit the default transaction
 **************************************/

if (gds__trans)
    ROLLBACK;

START_TRANSACTION;
}

#ifdef _ANSI_PROTOTYPES_
static int put_module (
	TEXT 	*module,
	TEXT	*infile)
#else
static put_module (module, infile)
	TEXT 	*module, *infile;
#endif
{
/**************************************
 *
 *	p u t _ m o d u l e
 *
 **************************************
 *
 * Functional description
 *	Replace current source with modified source
 *	reality checks: component/module exist, right user
 *	read in from file. update history
 *	using "source/component/as path write readonly to 
 *	home directory of database
 *
 **************************************/
TEXT	comp [20], new_module [80], new_infile [80];

/*  For MPEXL, expand the input file name, if it is not specified,
    to derive the component and module.  */

if (op_sys_code == OS_MPEXL && infile [0] == '\0')
    {
    MPEXL_expand_name (module, comp, new_module);
    STUFF_lowcase (module, new_infile);
    module = new_module;
    infile = new_infile;
    printf ("File %s will be checked in as %s %s\n",
	infile, comp, module);
    }
else
    STUFF_manage_component (comp);

if (!STUFF_checked_out_by_me (comp, module))
    return;

if (STUFF_change (comp, module, infile))
    {
    commit();
    STUFF_notify_queue (comp, module);
    commit();
    }
else
    rollback();
}

#ifdef _ANSI_PROTOTYPES_
static int reinstate (
    TEXT    *module,
    TEXT    *comp)
#else
static reinstate (module, comp)
    TEXT    *module, *comp;
#endif
{
/**************************************
 *
 *	r e i n s t a t e
 *
 **************************************
 *
 * Functional description
 *	Retrieve an obsolete module.
 *
 **************************************/

set_or_clear_obsolete (module, comp, FALSE);
}

#ifdef _ANSI_PROTOTYPES_
int set_component (
    TEXT 	*name)   
#else
set_component (name)
    TEXT 	*name;    
#endif
{
/**************************************
 *
 *	s e t _ c o m p o n e n t
 *
 **************************************
 *
 * Functional description
 *	Specify the component for future commands
 *	global component == null for bad input
 *
 **************************************/
USHORT	count;

if (NOT_NULL (name))
    {
    count = 0;
    STUFF_upcase (name, name);

    FOR C IN COMPONENTS WITH C.COMPONENT EQ name
	count++;                                
    END_FOR; 

    if (count)
        STUFF_upcase (name, component);
    else
	{
	printf ("%s not in this database\n", name);
	return FALSE;
	}
    }
else
    component [0] = 0;

return TRUE;  
}

#ifdef _ANSI_PROTOTYPES_
static int set_opsys (
   TEXT 	*ops) 
#else
static set_opsys (ops)
   TEXT 	*ops; 
#endif
{
/**************************************
 *
 *	s e t _ o p s y s
 *
 **************************************
 *
 * Functional description
 *	Initialize or change a global opsys variable 
 *	changed to reflect new defines for op_sys_code
 *	needs looping structure
 *
 *	8/3 created opsys_table and only the names are the same
 *
 **************************************/
SSHORT 	code;
TEXT	answer [10];

if (!*ops)
    STUFF_get_string ("Enter the operating system", ops, 10);

while (TRUE)
    {
    code = STUFF_set_oscode (ops);
    STUFF_echo_osname (code, TRUE);
    STUFF_get_string ("Is this correct (y, n)", answer, sizeof (answer));
    if (UPPER (*answer) == 'Y')
	break;

    printf ("Operating systems are:\n");
    for (code = 0; STUFF_echo_osname (code, TRUE); code++)
	;
    STUFF_get_string ("Enter the operating system", ops, 10);
    }

op_sys_code = code;
}

#ifdef _ANSI_PROTOTYPES_
static int set_or_clear_obsolete (
    TEXT	*module,
    TEXT	*comp,
    USHORT	obs_flag)
#else
static set_or_clear_obsolete (module, comp, obs_flag)
    TEXT	*module, *comp;
    USHORT	obs_flag;
#endif
{
/**************************************
 *
 *	s e t _ o r _ c l e a r _ o b s o l e t e
 *
 **************************************
 *
 * Functional description
 *	The FLAGS field of SOURCES has a bit, which if
 *	set, indicates that the module is obsolete.
 *	When a module is obsolete, it will be shared only
 *	when it is specifically named in a share command.
 *
 **************************************/

STUFF_upcase (comp, comp);

if (NULL_STR (comp))
    STUFF_manage_component (comp);

if (!STUFF_exists_YN (comp, module))
    return;

STORE H IN SMM.HISTORY USING 
    strncpy (H.MODULE, module, 39);
    strncpy (H.COMPONENT, comp, 19);
    strcpy (H.CHANGE_TAG, (obs_flag) ?
	"setting module obsolete" : "module is no longer obsolete");
END_STORE
    ON_ERROR
        {
        STUFF_error_report (comp, module, 0, gds__status);
	rollback();
        return;
        }
    END_ERROR;

FOR S IN SOURCES WITH
    S.MODULE EQ module AND
    S.COMPONENT EQ comp

    MODIFY S USING
	if (obs_flag)
	    {
	    S.FLAGS |= FLAGS_obsolete;
	    S.FLAGS.NULL = 0;
	    }
	else if (!S.FLAGS.NULL)
	    S.FLAGS &= ~FLAGS_obsolete;
    END_MODIFY;

END_FOR;

STUFF_close_history (module, comp);
}

#ifdef _ANSI_PROTOTYPES_
static int set_pathname (
   TEXT 	*path) 
#else
static set_pathname (path)
   TEXT 	*path; 
#endif
{
/**************************************
 *
 *	s e t _ p a t h n a m e
 *
 **************************************
 *
 * Functional description
 *
 *	initialize or change a global path variable 
 **************************************/

if (NOT_NULL(path))
    {	
    STUFF_get_string ("Enter the pathname", path, 80);
    strcpy (pathname, path);
    return;
    }

STUFF_lowcase (path, pathname);
}

#ifdef _ANSI_PROTOTYPES_
static int share_module (
    TEXT 	*module,
    TEXT	*outfile) 
#else
static share_module (module, outfile)
    TEXT 	*module, *outfile; 
#endif
{
 /**************************************
 *
 *	s h a r e _ m o d u l e
 *
 **************************************
 *
 * Functional description
 *	Dumps module to file; stores or updates
 *	shared record
 *
 *	8/5 removed all references to shared relation.
 *     12/15 accomodate derived files
 *
 **************************************/
TEXT	comp [20];
USHORT	outfile_len;

STUFF_manage_component (comp);

if (!STUFF_exists_YN (comp, module))
    return;

STUFF_obsolete (comp, module);
STUFF_who_has (module, comp);
STUFF_share_a_module (comp, module, outfile);
}
