/*
 *	PROGRAM:	SMM source maintainence manager
 *	MODULE:		marion.h
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

#include <stdio.h>
#include <signal.h>
#include "../jrd/common.h"
#include "../jrd/time.h"
#include "../jrd/gds.h"
#include "../jrd/utl_proto.h"
#include "../jrd/isc_proto.h"

#ifdef VMS
#include descrip
#define TEMPLATE_PATH "@source:[commands]"
#define DATE_FILE    "/source/%s/date.save"
#define DIF_CMD_STRING  "$ %s %s %s %s"
#define SHEL3    "@%s %s %s"
#define SHEL2    "@%s %s"
#define SHEL1    "@%s"   

#define MAIL_FILE	"smm_mai.XXXXXX"

#else

#define DATE_FILE    "source/%s/date.save"
#define DIF_CMD_STRING "%s %s %s %s"
#define SHEL3    "%s %s %s %s"
#define SHEL2    "%s %s %s"
#define SHEL1    "%s %s"
#define SHEL0    "%s"   
#endif 
                                
#ifdef APOLLO
#define GDS_NULL	*gds__null
#define LIKENESS	"/gds/com/isc_diff" 
#else
#define GDS_NULL        0
#ifdef UNIX
#define LIKENESS	"diff -w" 
#else
#define LIKENESS	"isc_diff" 
#endif
#endif

#ifdef OS2
#define TEMPLATE_PATH	"../"
#define MAIL_FILE	"smm_mai.XXXXXX"
#endif

#ifdef WIN_NT
#define TEMPLATE_PATH	"../"
#define MAIL_FILE	"smm_mai.XXXXXX"
#endif

#ifdef MSDOS
#define MAIL_FILE	"smm_mai.XXXXXX"
#endif

#ifndef TEMPLATE_PATH
#define TEMPLATE_PATH	"source/"
#endif

#define ADD_TEMPLATE	"%sadd_template"
#define PUT_TEMPLATE	"%sput_template"
#define MPP_TEMPLATE	"%smpp_template"
#define MPM_TEMPLATE	"%smpm_template"

#define VERSION		"V2.7     4-Feb-97"
#define TEMP_FILE	"marion.XXXXXX"
#define OLDFILE		"smm_old.XXXXXX"
#define DIF_FILE	"smm_dif.XXXXXX"
#define CMD_STRING	"/bin/sh %s >%s 2>&1"

#ifndef MAIL_FILE
#define MAIL_FILE	"/tmp/smm_mai.XXXXXX"
#endif

#define LOWER(c) 		((c >= 'A' && c<= 'Z') ? c + 'a' - 'A': c )
#define NULL_STR(s)             (!s || !*s)
#define NOT_NULL(s)		(s && *s)

#define FLAGS_obsolete		1	/* Module is marked as obsolete */
#define FLAGS_noheader		2	/* Module does not have a header */

#define CAP_header_field	1	/* The database contains a header field */

#define	NONE			0
#define	OS_VMS			1
#define	OS_PC			2
#define	OS_WIN_NT		3
#define OS_MPEXL		4
#define	OS_UNIX			5
#define	OS_UNIX_NO_DOLLAR	6
