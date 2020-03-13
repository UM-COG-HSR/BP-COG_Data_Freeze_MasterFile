/************************************************************************************************************
* Program: Analytic File 2 - study population and exclusions.SAS            								*
* Folder: S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Aim 1\Data Management\Data\Freeze2020_Master\SAS Progs  *
* Author: Nick Tilton                          																*
* Created: 03/13/20                            																*
* Summary: Creates intermediate study population file and exclusions files									*
* Revisions: 																								*
*************************************************************************************************************/

/* Please provide info about this repository */
%let repo_name = BP-COG_Data_Freeze_MasterFile; /* Repository name on GitHub */
%let repo_maintainer = Nick Tilton;
%let repo_description = SAS repository for the 2020 freeze of the masterlong dataset;

%put repo_name := &repo_name;  /* Github Repository name */

/*****---- SAS Setup starts here -----*****/ 

/* Define global macro variable names */
%global 
 SAS_work_dir
 computer_name
 sas_batchmode   /* Y/N */
 sas_progname    
 sas_fullname
;

/* Store path to SAS working directory in `SAS_work_dir` macro variable */
/* Based on `https://communities.sas.com/t5/SAS-Communities-Library/Find-current-directory-path/ta-p/485785` */
/* Note the location of the file*/
filename setupc  "C:/Users/Public/SAS_work_directory.sas";
%include setupc;
%let SAS_work_dir =  %SAS_work_directory;
%put SAS_work_dir := &SAS_work_dir;   
%put sysuserid    := &sysuserid;   /* User id */

/*--- Load repository assets ----*/ 
filename fx "&SAS_work_dir/_load_repo_assets.inc";
%include fx;

%computer_name;  /* Stores computer name in `computer_name` global macro variable */
%put computer_name := &computer_name;
%our_sas_session_info;
/***** SAS Setup ends here *****/

/*****----  Our program starts here  *****/


%let BPCOGpath = S:\Intmed_Rsrch2\GenMed\Restricted\BP COG;

%let MasterPath = &BPCOGpath.\Aim 1\Data Management\Data\Freeze2020_Master\SAS Master Data;
%let AnalysPath = &BPCOGpath.\Aim 1\Data Management\Data\Freeze2020_Master\SAS Analytic File;
%let FormatPath = &BPCOGpath.\Aim 1\Data Management\Data\formats;
%let IntrmdPath = &BPCOGpath.\Aim 1\Data Management\Data\Freeze2020_Master\SAS Intermediate Files;
%let ExclusPath = &BPCOGpath.\Aim 1\Data Management\Data\Freeze2020_Master\SAS Exclusions;
%let CogPath = &BPCOGpath.\Aim 1\Data Management\Data\Freeze2020_Master\SAS Cognitive Data;
%let MemPath = &BPCOGpath.\Aim 1\Data Management\Data;
%let CohortPath = &BPCOGpath.\Original Cohort Files;

libname frz "&MasterPath";
libname mem "&MemPath";
libname fmts "&FormatPath";
libname intm "&IntrmdPath";
libname anls "&AnalysPath";
libname cog "&CogPath";
libname excl "&ExclusPath";
libname ARIC "&CohortPath.\ARIC\SAS Files";
libname CARDIA "&CohortPath.\CARDIA\SAS Files";
libname CHS "&CohortPath.\CHS\SAS Files";
libname FOS "&CohortPath.\FOS\SAS Files";
libname MESA "&CohortPath.\MESA\SAS Files";
libname NOMAS "&CohortPath.\NOMAS\SAS Files";

options fmtsearch=(fmts) nofmterr;

%macro today_YYMMDD();
%let z=0;
%let y2=%sysfunc(today(),year2.);
%let m2=%sysfunc(today(),month2.);
%let d2=%sysfunc(today(),day2.);
%if %eval(&m2)<=9 %then %let m2 = &z&m2;
%if %eval(&d2)<=9 %then %let d2 = &z&d2;
%let ymd = &y2&m2&d2;
&ymd;
%mend;

%let ymd = %today_YYMMDD();

/* get latest filedate */
data _null_;
retain late_dt;
rc=filename('mydir',"&MasterPath");
did=dopen('mydir');
numopts=doptnum(did);
memcount=dnum(did);
if (memcount gt 0) then do i = 1 to memcount;
	filename=dread(did,i);
	if i=1 then late_dt=input(substr(filename,12,6),best6.);
	curr_dt=input(substr(filename,12,6),best6.);
	if curr_dt > late_dt then late_dt = curr_dt;
	fid = mopen(did, filename,'i',0,'d');
	rc=fclose(fid);
	if i=memcount then call symputx("filedate",late_dt);
end;
rc=dclose(did);
run;
%put &=filedate;

proc sort data=frz.masterlong_&filedate; by newid daysfromvisit1; run;
proc sort data=cog.cog_&filedate; by newid daysfromvisit1; run;

data tmp_bp1;
set cog.cog_&filedate; by newid;
retain foundt0 cog_idx_base;

if first.newid then do; 
	foundt0=0;
	cog_idx_base=.;
end;
if foundt0 = 0 then do;
	if sbp_locf ^= . then do; 
		foundt0=1;
		cog_idx_base=0;
	end;
end;
else cog_idx_base+1;
run;

proc sort data=tmp_bp1; by newid daysfromvisit1; run;

data tmp_bp1a;
set tmp_bp1;
by newid;
if first.newid;
run;

data tmp_bp2;
set tmp_bp1;
if foundt0;
run;

data tmp_bp2a;
set tmp_bp2;
by newid;
if first.newid;
run;

proc freq data=tmp_bp1a;
tables studyname;
run;

proc freq data=tmp_bp2a;
tables studyname;
run;

*permanent dataset for first exclusion criterion: no BP meas prior to 1st cog assmnt;
data excl.ex1;
merge tmp_bp1a (in=in1) tmp_bp2a (in=in2);
by newid;
if in1 and not in2;
run;

/* one cog after bp allowed - if first.newid... commented out */
data tmp_bp3;
set tmp_bp2;
by newid;
*if first.newid and last.newid then delete;
run;

proc freq data=tmp_bp1a;
tables studyname;
where cog_idx_base=0;
run;

*permanent dataset for 2nd exclusion criterion: only one cog assmnt after BP;
*no exclusion;
%macro skip_noexclusion;
data excl.ex2;
set tmp_bp2;
by newid;
if first.newid and last.newid;
run;
%mend;

*stroke date for censoring and excluding;

data date_cardia;
set cardia.cardia_ref;
length newid $21.;
format v1dt mmddyy10.;
newid=compress(id||'cardia');
v1dt=a02date;
keep newid v1dt;
run;

proc sort data=mem.stroke; by newid ttostk;
proc sort data=date_cardia; by newid; run;

data tmp_str;
merge mem.stroke (in=in1) date_cardia; by newid;
if in1;
if first.newid;
if ttostk=. then ttostk=intck('day',v1dt,strokedt);
drop v1dt;
run;
*end stroke section;

proc sort data=tmp_bp3; by newid daysfromvisit1;
proc sort data=frz.masterlong_&filedate out=tmp_race; by newid; where daysfromvisit1=0;
proc sort data=tmp_str; by newid; run;

data tmp_race;
set tmp_race;
by newid;
if first.newid;
run;

data tmp_bp4;
merge tmp_bp3 (in=in1) 
tmp_race (keep=newid female0 racebpcog hxstroke) 
tmp_str (drop=studyname strokedt);
by newid;
if in1;
run;

data tmp_bp5;
set tmp_bp4;
if racebpcog in (1 2 3);
if studyname='fos' and racebpcog=1 then delete;
run;

*3rd exclusion criterion: race other than black, white or hispanic;
data excl.ex3;
set tmp_bp4;
if (racebpcog not in (1 2 3));
if cog_idx_base=0;
run;

proc sort data=excl.ex3; by newid;
data excl.ex3;
set excl.ex3; by newid;
if first.newid;
run;

proc sort data=tmp_bp5;
by newid daysfromvisit1;
run;
 
data tmp_bp6;
set tmp_bp5;
by newid;
retain v0time;

if first.newid then v0time = daysfromvisit1;
if ttostk ^= . then ttostk_cog = ttostk - v0time; else ttostk_cog = .;
cogtime_d = daysfromvisit1 - v0time;
cogtime_y = cogtime_d / 365.25;

if strokeinc = . or (strokeinc = 1 and ttostk > daysfromvisit1) then strokeinc = 0; 

drop v0time;
run;

*4th exclusion criterion: history of stroke at cohort's baseline or incident stroke before first cog assessment;
data excl.ex4;
set tmp_bp6;
if hxstroke or (ttostk_cog <= 0 and ttostk_cog ne .);
if hxstroke then ex1 = 1; else ex1 = 0;
if (ttostk_cog <= 0 and ttostk_cog ne .) then ex2 = 1; else ex2 = 0;
if cog_idx_base=0;
run;

proc sort data=excl.ex4; by newid daysfromvisit1;
data excl.ex4b;
set excl.ex4; by newid;
if first.newid;
run;


data tmp_bp7;
set tmp_bp6;
if not (hxstroke or (ttostk_cog <= 0 and ttostk_cog ne .));
run;

data dem_chs;
set chs.levine_main;
if demen05 = 1;
length newid $21.;
newid = compress(id||'chs');
hxdem = 1;
keep newid;
run;

proc sort data=tmp_bp7;
by newid daysfromvisit1;
run;

data tmp_bp8;
merge tmp_bp7 (in=in1) dem_chs;
if in1;
if hxdem=. then hxdem=0;
run;

proc sort data=intm.dem_aric; by newid ttodem;
proc sort data=intm.dem_cardia; by newid ttodem;
proc sort data=intm.dem_chs; by newid ttodem;
proc sort data=intm.dem_fos; by newid ttodem; 
proc sort data=intm.dem_mesa; by newid ttodem; run;

data dem_all;
set intm.dem_aric intm.dem_cardia intm.dem_chs intm.dem_fos intm.dem_mesa;
by newid;
if first.newid;
run;

proc sort data=tmp_bp8;
by newid daysfromvisit1;
run;

data tmp_bp9;
merge tmp_bp8 (in=in1) dem_all;
by newid;
retain v0time;

if in1;
if first.newid then v0time = daysfromvisit1;
if ttodem ^= . then ttodem_cog = ttodem - v0time; else ttodem_cog = .;
drop v0time;
run;

data tmp_bp10;
set tmp_bp9;
if deminc=1 and ttodem_cog > cogtime_d then deminc=0;
run;

*5th exclusion criterion: history of dementia at cohort's baseline or incident dementia before first cog assessment;
data excl.ex5;
set tmp_bp10;
if hxdem or (ttodem_cog <= 0 and ttodem_cog ne .);
if cog_idx_base=0;
run;

proc sort data=excl.ex5; by newid;
data excl.ex5;
set excl.ex5; by newid;
if first.newid;
run;

data tmp_bp11;
set tmp_bp10;
if not (hxdem or (ttodem_cog <= 0 and ttodem_cog ne .));
run;

proc sort data=tmp_bp11;
by newid daysfromvisit1;
run;


data tmp_bp12;
set tmp_bp11;
by newid;
retain age0;
if first.newid then age0=age;
run;

proc sort data=tmp_bp12 out=t2_1 (keep=newid cog_idx_base cogtime_y sbp_locf gcp studyname); by newid cogtime_y; run;
data t2_2;
set t2_1; by newid;
tmpi=lag(cog_idx_base); 
tmpt=lag(cogtime_y);
if first.newid then do; 
tmpi=.; tmpt=.; founddup=0; end;
else if cog_idx_base = tmpi or cogtime_y = tmpt then founddup=1;
else founddup=0;
run;

proc sort data=t2_2; by newid descending founddup; run;
data t2_3;
set t2_2; by newid;
retain foundid;
if first.newid then do; 
	foundid=0;
	if founddup then foundid=1;
end;
if foundid;
run;

data t2_3b;
set t2_3;
by newid;
if first.newid;
keep newid foundid studyname;
run;

data t2_4;
set t2_2; by newid;
retain foundid;
if first.newid then do; 
	foundid=0;
	if founddup then foundid=1;
end;
run;

proc sort data=t2_3; by newid cogtime_y cog_idx_base;
run;

proc sort data=tmp_bp12; by newid cog_idx_base; 
proc sort data=t2_3b; by newid; 
proc sort data=t2_4 out=t2_5 (keep=newid cog_idx_base founddup foundid); by newid cog_idx_base; run; 


data excl.prelim2;
merge tmp_bp12 t2_5;
by newid cog_idx_base;
hisp=(racebpcog=3);
sbp120m=(mean_sbp_all-120)/10;
cogtime_y2=round(cogtime_y,0.01);
black=(racebpcog=1);
run;

proc sort data=excl.prelim2; by newid daysfromvisit1; run;
data firstobs;
set excl.prelim2;
by newid;
if first.newid;
run;

data excl.prelim3;
merge tmp_bp12 t2_3b;
by newid;
hisp=(racebpcog=3);
black=(racebpcog=1);
sbp120m=(mean_sbp_all-120)/10;
cogtime_y2=round(cogtime_y,0.01);
if foundid=.;
drop foundid;
run;

proc sort data=excl.prelim2; by newid daysfromvisit1 descending gcp; run;
data excl.prelim4;
set excl.prelim2;
by newid daysfromvisit1;
if first.newid or first.daysfromvisit1;
run;

data excl.firstobs;
set excl.prelim4;
by newid;
if first.newid;
run;

proc datasets library=work memtype=data nolist;
delete tmp: t2_: dem: date:;
run;
quit;
