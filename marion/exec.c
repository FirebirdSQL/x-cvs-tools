/*
 *	PROGRAM:	SMM source maintainence manager
 *	MODULE:		exec.c
 *	DESCRIPTION:	handle the dirty details of running commands
 *                      on vms and civilized systems
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

#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include "../marion/marion.h"
#ifdef ultrix
#include <sys/param.h>
#endif

#ifdef hpux
#define MAXPATHLEN	128
#define getwd(buf)	getcwd(buf, MAXPATHLEN)
#endif

#ifdef SOLARIS
#define MAXPATHLEN	128
#define getwd(buf)	getcwd(buf, MAXPATHLEN)
#endif

#ifdef SCO_UNIX
#define getwd(buf)	getcwd(buf, MAXPATHLEN)
#endif

#ifdef UNIXWARE
#define getwd(buf)	getcwd(buf, 255)
#endif

#if (defined WIN_NT || defined OS2_ONLY)
#include <direct.h>
#define getwd(buf)	getcwd(buf, 255)
#endif

#ifdef vms
#include "../jrd/lnmdef.h"
#endif

#ifdef PC_PLATFORM
#define MAXPATHLEN	128
#define getwd(buf)	getcwd(buf, MAXPATHLEN)
#endif

static int	run_apollo PROTO ((TEXT *));
#ifdef VMS
static int	run_vms PROTO ((TEXT *));
static int	make_desc PROTO ((TEXT *, struct dsc$descriptor_s *));
#endif /* VMS */

#ifdef _ANSI_PROTOTYPES_
int EXEC_run (
    TEXT	*command_string,
    TEXT	*arg1,
    TEXT	*arg2,
    TEXT	*arg3, 
    int		lower_flag)
#else
EXEC_run (command_string, arg1, arg2, arg3, lower_flag)
    TEXT	*command_string, *arg1, *arg2, *arg3; 
    int		lower_flag;
#endif
{
/**************************************
 *
 *	 E X E C _ r u n
 *
 **************************************
 *
 * Functional description
 *      This drives the system command execution code
 *
 **************************************/
TEXT	buffer [256], *bufloc, command [128];

/* copy all the arguments over and lower case them */

buffer [0] = 0;

sprintf (command, command_string, TEMPLATE_PATH);

if (NOT_NULL (command))
    {
    strcat (buffer, command);
    strcat (buffer, " ");
    }
if (NOT_NULL (arg1))
    {
    strcat (buffer, arg1);
    strcat (buffer, " ");
    }
if (NOT_NULL (arg2))
    {
    strcat (buffer, arg2);
    strcat (buffer, " ");
    }
if (NOT_NULL (arg3))
    {
    strcat (buffer, arg3);
    strcat (buffer, " ");
    }

if (lower_flag)
    for (bufloc = buffer; *bufloc = LOWER (*bufloc); bufloc++)
	;

#ifdef VMS     
run_vms (buffer);
#else
run_apollo (buffer); 
#endif

return TRUE;
}

#ifdef _ANSI_PROTOTYPES_
int EXEC_get_host_dir (
    TEXT    *host,
    TEXT    *dir)
#else
EXEC_get_host_dir (host, dir)
    TEXT    *host, *dir;
#endif
{
/**************************************
 *
 *	E X E C _ g e t _ h o s t _ d i r
 *
 **************************************
 *
 * Functional description
 *        execute the system calls that return the name
 *        of the machine you are working on and which directory
 *        you are in
 **************************************/
#ifdef VMS

#define LOGICAL_NAME_TABLE	"LNM$FILE_DEV"
#define HOST_NAME "sys$node"
typedef struct itm {
    SSHORT	itm_length;
    SSHORT	itm_code;
    SCHAR	*itm_buffer;
    SSHORT	*itm_return_length;
} ITM;


int	length, status, attr;
USHORT	n, l;
TEXT	*temp;
ITM	items [2];
struct dsc$descriptor_s	desc1, desc2;

temp = getenv ("PATH");
strcpy (dir, temp);

make_desc (HOST_NAME, &desc1);
make_desc (LOGICAL_NAME_TABLE, &desc2);

items[0].itm_length = 20;
items[0].itm_code = LNM$_STRING;
items[0].itm_buffer = host;
items[0].itm_return_length = &l;

items[1].itm_length = 0;
items[1].itm_code = 0;

attr = LNM$M_CASE_BLIND;

status = sys$trnlnm (&attr, &desc2, &desc1, NULL, items);

host [l] = 0;

#else
ISC_get_host (host, 20);

if (!getwd(dir))
    {
    printf ("FAILED: %s\n", dir);
    return FALSE;
    }
else
    return TRUE;
#endif
}

#ifndef VMS
#ifdef _ANSI_PROTOTYPES_
static int run_apollo (
    TEXT    *command_string)
#else
static run_apollo (command_string)
    TEXT    *command_string;
#endif
{
/**************************************
 *
 *	r u n _ a p o l l o  
 *
 **************************************
 *
 * Functional description
 *        run a command file with attendant
 *        data files.  
 **************************************/
SSHORT	result;
       
#ifdef apollo
    for (result = SIGVTALRM; result == SIGVTALRM; result = system (command_string))
        ;
#else
system (command_string);
#endif
}          
#endif
      
#ifdef VMS
#ifdef _ANSI_PROTOTYPES_
static int run_vms (
   TEXT	*command_line)
#else
static run_vms (command_line)
   TEXT	*command_line;
#endif
{
 /**************************************
 *
 *	r u n _ v m s
 *
 **************************************
 *
 * Functional description
 *      
 *     using VMS methods run an operating
 *     system command.  should work with or
 *     without an output file
 **************************************/
struct  dsc$descriptor_s	desc1, desc2, desc3;
UCHAR    event_flag;
ULONG	status, return_status, mask;


if (command_line)
    make_desc (command_line, &desc2);    

return_status = 0;
event_flag = 32;
mask = 1;

status = lib$spawn (
    ((command_line) ? &desc2 : NULL),	/* Command to be executed */
     NULL,                              /* Command file */
     NULL,                              /* Output file */
    &mask,			/* sub-process characteristics mask */
    NULL,			/* sub_process name*/
    NULL,			/* returned process id */
    &return_status,		/* completion status */
    &event_flag);		/* event flag for completion */

if (status & 1)
    {
    while (!return_status)
        sys$waitfr (event_flag);
    if (!(return_status & 1))
        lib$signal (return_status);	/* NOT (status).  jgalt 3/12/96 */
    }
else
    lib$signal (status);
}
#endif          

#ifdef VMS
#ifdef _ANSI_PROTOTYPES_
static int make_desc (
    TEXT	*string,
    struct dsc$descriptor_s	*desc)
#else
static int make_desc (string, desc)
    TEXT	*string;
    struct dsc$descriptor_s	*desc;
#endif
{
/**************************************
 *
 *	m a k e _ d e s c
 *
 **************************************
 *
 * Functional description
 *	Fill in a VMS descriptor with a null terminated string.
 *
 **************************************/

 desc->dsc$b_class = DSC$K_CLASS_S;
 desc->dsc$b_dtype = DSC$K_DTYPE_T;
 desc->dsc$w_length = strlen (string);
 desc->dsc$a_pointer = string;

return desc;
}
#endif
