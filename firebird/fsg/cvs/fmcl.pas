program fmcl;
{ Adds Firebird Build Numbers to Changelog entries.
  To be used in combination with the other scripts in this directory 
  I have compiled my version with FPC 1.0 
  but most (Borland compatible) pascal compilers should do the trick
  no warranties whatsoever, use at your own risk
  FSG 2001}
var build_no_file:text;
    s:string;
    thisbuild : string;


procedure compute(var s:string);
var
    i:byte;
begin
  while s[1]='2' do
  //We will need to change this in the year 2999 :-) 
  begin
    s:=s+' Build No.: '+thisbuild;  //Add the actual Build number
    writeln(s);
                     // And dump it to stdout
    repeat
      readln(build_no_file,s);           //There should be another line
      if pos('/this_build',s) <> 0 then
  //I'm only interested in the next build number
      begin
                              //This will get nearly all of them
        writeln(s);
        delete(s, 1, pos('1.',s)+1);
        i:= Pos(')',s)-1;
        thisbuild:=copy(s,1,i);
      end
      else
      begin
       if length(s)=0 then
              //just to be sure that the next comparison works without segfaults :-)
           s:=' ';
       if s[1]<>'2' then
           writeln(s);
      end;
    until (s[1]='2') or eof(build_no_file);
  end;
  s:='';
end;


begin
  thisbuild:='0';
 //No idea where we will start
  assign(build_no_file,'');
 //read from stdin
  reset(build_no_file);
  
  while not eof(build_no_file) do
  begin
    readln(build_no_file,s);
 //Get a line
    compute(s);
 
  end;
  close(build_no_file);
end.
