rem The contents of this file are subject to the InterBase Public License
rem Version 1.0 (the "License"); you may not use this file except in
rem compliance with the License.
rem 
rem You may obtain a copy of the License at http://www.Inprise.com/IPL.html.
rem 
rem Software distributed under the License is distributed on an "AS IS"
rem basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
rem the License for the specific language governing rights and limitations
rem under the License.  The Original Code was created by Inprise
rem Corporation and its predecessors.
rem 
rem Portions created by Inprise Corporation are Copyright (C) Inprise
rem Corporation. All Rights Reserved.
rem 
rem Contributor(s): ______________________________________.
@echo off
if "%1" == "" goto err
if not "%2" == "" goto err

echo Compressing DB in... %1
sed -f compress.sed %1 > .\sed.TMP
copy .\sed.TMP %1
del .\sed.TMP
goto end

:err
echo "Usage: compress_dbs filename"

:end
