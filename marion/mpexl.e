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

#include <string.h>
#include "../marion/marion.h"

DATABASE 
    SMM = EXTERN FILENAME "marion.gdb";

BASED_ON SOURCES.COMPONENT	component_field;
BASED_ON SOURCES.MODULE		module_field;

#define	MAX_COMPONENT_LENGTH	sizeof (component_field)
#define MAX_MODULE_LENGTH	sizeof (module_field)
                              	
#define MAX_MPEXL_COMP_LEN	5
#define MAX_MPEXL_MOD_LEN	8
#define MAX_MPEXL_EXT_LEN	3

/*
 *  NB: Regarding upper/lower case:  Module names and component
 *      names are converted to upper case.   Compressed names are
 *      converted to lower case.
 */


MPEXL_compress_name (component, module, output)
    TEXT	*component, *module, *output;
{
/**************************************
 *
 *	M P E X L _ c o m p r e s s _ n a m e
 *
 **************************************
 *
 * Functional description         
 *	MPE/XL-specific translation of a component/module
 *	pair into an MPE/XL-compatible module name.  Assumes
 *	that filenames are unique using MAX_MPEXL_MOD_LEN
 *	characters and that components are unique using
 *	MAX_MPEXL_COMP_LEN characters.  It further assumes
 *	that module names containing underscores remain
 *	unique when the underscores are removed.
 *
 **************************************/
TEXT		*op, *end;

op = output;

/* Copy the first characters of the module name */

for (end = op + MAX_MPEXL_MOD_LEN; op < end && *module && *module != '.';)
    if (*module != '_')
	*op++ = *module++;
    else
	module++;

/* Now skip to the extension */

while (*module && *module != '.')
    module++;

/* Next copy the extension */

if (*module == '.')
    for (end = module + MAX_MPEXL_EXT_LEN + 1; module < end && *module;)
	*op++ = *module++;
else
    *op++ = '.';

/* Finally, the component name */

for (end = op + MAX_MPEXL_COMP_LEN; op < end && *component;)
    if (*component != '_')
	*op++ = *component++;
    else
	component++;

*op = 0;
}

MPEXL_expand_name (input, component, module)
    TEXT	*input, *component, *module;
{
/**************************************
 *
 *	M P E X L _ e x p a n d _ n a m e
 *
 **************************************
 *
 * Functional description         
 *	MPE/XL-specific translation of an MPE/XL-compatible module name
 *	into a component/module pair.
 *
 **************************************/
TEXT	mod [MAX_MODULE_LENGTH], mod1 [2], *p, *q, ext_beg [3], *ext_ptr, *comp;
int	len, count;

*component = *module = 0;

/* Extract the module name and the beginning of the
   extension from the input */

for (p = mod, q = input; *q && *q != '.';)
    *p++ = *q++;
*p = 0;

if (!(ext_beg [0] = *q++) || !(ext_beg [1] = *q))
    {
    printf ("*** No extension or component found in name %s ***\n", input);
    return;
    }

ext_beg [2] = 0;
ext_ptr = q;

count = 0;

FOR S IN SOURCES WITH
    S.MODULE STARTING WITH mod

    if (S.FILE_TYPE [0] == ' ')
	comp = ext_ptr;
    else
	{
	for (p = (TEXT *) S.FILE_TYPE; *p && *p != ' '; p++)
	    ;
	len = MIN (p - (TEXT *) S.FILE_TYPE, MAX_MPEXL_EXT_LEN);
	if (strncmp (S.FILE_TYPE, ext_ptr, len))
	    continue;
	comp = ext_ptr + len;
	}

    if (!strncmp (S.COMPONENT, comp, strlen (comp)))
	{
	count++;
	strcpy (component, S.COMPONENT);
	strcpy (module, S.MODULE);
	}

END_FOR;

if (count == 0)
    {
    /* Can't find a match.  Maybe the filename contains an underscore. */

    mod1 [0] = mod [0];
    mod1 [1] = 0;

    FOR S IN SOURCES WITH
	S.MODULE STARTING WITH mod1 AND
	S.MODULE CONTAINING "_"

	for (p = mod, q = (TEXT *) S.MODULE; *p; q++)
	    if (*q != '_')
		if (*p == *q)
		    p++;
		else
		    break;

	if (*p)
	    continue;

	if (S.FILE_TYPE [0] == ' ')
	    comp = ext_ptr;
	else
	    {
	    for (p = (TEXT *) S.FILE_TYPE; *p && *p != ' '; p++)
		;
	    len = MIN (p - (TEXT *) S.FILE_TYPE, MAX_MPEXL_EXT_LEN);
	    if (strncmp (S.FILE_TYPE, ext_ptr, len))
		continue;
	    comp = ext_ptr + len;
	    }

	if (!strncmp (S.COMPONENT, comp, strlen (comp)))
	    {
	    count++;
	    strcpy (component, S.COMPONENT);
	    strcpy (module, S.MODULE);
	    }

    END_FOR;
    }

if (count != 1)
    {
    printf ("*** Found %d modules matching name %s ***\n", count, input);
    return;
    }

for (p = module; *p && *p != ' '; p++)
    ;
*p = 0;

for (p = component; *p && *p != ' '; p++)
    ;
*p = 0;
}
