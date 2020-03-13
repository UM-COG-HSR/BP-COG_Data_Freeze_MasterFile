/************************************************************************************************************
* Program: Analytic File 1 - Create BP and COG vars.SAS            											*
* Folder: S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Aim 1\Data Management\Data\Freeze2020_Master\SAS Progs  *
* Author: Nick Tilton                          																*
* Created: 03/13/20                            																*
* Summary: Creates intermediate file with lagged BP measures after 1st cog assessment						*
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

libname frz "&MasterPath";
libname mem "&MemPath";
libname fmts "&FormatPath";
libname intm "&IntrmdPath";
libname anls "&AnalysPath";
libname cog "&CogPath";
libname excl "&ExclusPath";

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

data Anal1; set frz.masterlong_&filedate;
Keep newid studyname daysfromvisit1 sbpbpcog dbpbpcog gcp mem exf gcp_se exf_se mem_se gcp1bydesign age0 female0; *racebpcog hxstroke;
run;
/*-- Creating cog_idx variable ---*/
Proc sort data=Anal1; by newid daysfromvisit1;

data cog_idx0;
set Anal1;
by newid;
sbp2 = lag(sbpbpcog);
dbp2 = lag(dbpbpcog);
if first.newid then do; sbp2=.; dbp2=.; end;
run;

proc sort data=cog_idx0; by newid daysfromvisit1; 
data cog_idx;
  set cog_idx0;
  by newid;
  if (first.newid or gcp1bydesign = 1) then cog_idx =0;
  output;
  if gcp ne . then cog_idx+1;
run;

proc sql;
select max(cog_idx) into :max_cogidx
from cog_idx;
quit;

%let max_cogidx=&max_cogidx;

%macro pass_data(max_cogidx);
 		data Anal2;
		 set cog_idx;
		 _daysfromvisit1 = - daysfromvisit1; 
		 if cog_idx <=&cog_idx_val;    /*  <--- modify for every pass through the data*/ 
		run;

		proc sort data = Anal2;
		by newid  _daysfromvisit1;
		run;

		data Anal3;
		 format newid daysfromvisit1 diff1_aux;
		 set Anal2;
		 retain max_days .;
		 by newid; 
		 if first.newid then max_days = daysfromvisit1;
		 diff1_aux  = max_days - daysfromvisit1;
		 drop max_days _daysfromvisit1;
		run;

		proc sort;
		by newid  daysfromvisit1;
		run;

		data Anal4;
		 set Anal3;
		 by newid daysfromvisit1;
		 retain sbp_locf dbp_locf days_base_rtn; 

		 if first.newid then do;
			 sbp_locf = sbp2;
			 sum_sbp_all_rtn=0;
			 cnt_sbp_all_rtn=0;
			 sum_sbp_rtn = 0;
			 cnt_sbp_rtn = 0;

			 dbp_locf = dbp2;
			 sum_dbp_all_rtn=0;
			 cnt_dbp_all_rtn=0;
			 sum_dbp_rtn = 0;
			 cnt_dbp_rtn = 0;

		 	 dead_locf = dead;
		 end;

		 if gcp1bydesign = 1 then days_base_rtn =daysfromvisit1;
		 if sbp2 ne . then sbp_locf = sbp2;   /* sbp Last observation carried forward */
		 if dbp2 ne . then dbp_locf = dbp2;   /* sbp Last observation carried forward */
		 if dead ne . then dead_locf = dead;  /* sbp Last observation carried forward */
		 
		 /* Auxiliary variables used to create mean_sbp_all */
		 
		 sum_sbp_all_rtn + sbp2;
		 cnt_sbp_all_rtn + (sbp2 ne .); /*  count sbp*/

		 sum_dbp_all_rtn + dbp2;
		 cnt_dbp_all_rtn + (dbp2 ne .); /*  count dbp*/
		 
		 /*-- Auxiliary variables used to create mean5_sbp ( Note the use of <= 5000)--*/
		 
		 if diff1_aux <= 5000 then do;
		   sum_sbp_rtn + sbp2;        /*  cumulative sum */
		   cnt_sbp_rtn + (sbp2 ne .); /*  count sbp*/
		   sum_dbp_rtn + dbp2;        /*  cumulative sum */
		   cnt_dbp_rtn + (dbp2 ne .); /*  count dbp*/
		 end;

		 if last.newid then do;
		   age = age0 +daysfromvisit1/365.25;  /* Age at baseline gcp visit */
		   if cnt_sbp_all_rtn > 0 then mean5_sbp = sum_sbp_rtn/cnt_sbp_rtn;
		   if sum_sbp_all_rtn > 0 then mean_sbp_all = sum_sbp_all_rtn/cnt_sbp_all_rtn;
		   if cnt_dbp_all_rtn > 0 then mean5_dbp = sum_dbp_rtn/cnt_dbp_rtn;
		   if sum_dbp_all_rtn > 0 then mean_dbp_all = sum_dbp_all_rtn/cnt_dbp_all_rtn;
		   days_base = days_base_rtn; /*-- days_base: # days since baseline */
		 end;

		run;

		data dt_1rps&cog_idx_val;
		 format newid cog_idx time_var daysfromvisit1 days_base;
		 set Anal4(keep =newid studyname cog_idx dead_locf gcp daysfromvisit1 days_base age sbp_locf mean_sbp_all mean5_sbp
		    mean_sbp_all 
			dbp_locf mean_dbp_all mean5_dbp
		    mean_dbp_all mem exf gcp_se exf_se mem_se/*female0 racebpcog hxstroke*/);
		 by newid daysfromvisit1;
		 time_var = daysfromvisit1 - days_base;
		 if last.newid and gcp^=. and  cog_idx = &cog_idx_val;
		 Drop time_var days_base;
		run;
%mend;

%macro do_loop;
%let cog_idx_val=0;
%do i=0 %to &max_cogidx;
	%pass_data(i);
	proc append base=dt_1rps data=dt_1rps&i; run;
 	%let cog_idx_val = %eval(&cog_idx_val + 1);
%end;

data cog.cog_&ymd;
set dt_1rps;
run;

proc datasets library=work memtype=data nolist;
delete anal: cog_idx: dt_:;
run;
quit;
%mend;
%do_loop;
