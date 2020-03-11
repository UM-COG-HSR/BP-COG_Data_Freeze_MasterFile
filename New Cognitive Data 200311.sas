/************************************************************************************************************
* Program: New Cognitive Data 200311.SAS            														*
* Folder: S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Aim 1\Data Management\Data\Freeze2020_Master\SAS Data   *              						*
* Author: Nick Tilton                          																*
* Created: 03/11/20                            																*
* Summary: Creates permanent master file with new cognitive data     										*
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

%let OutDataPath = S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Aim 1\Data Management\Data\Freeze2020_Master\SAS Data;
%let InDataPath = S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Aim 1\Hispanic vs White\New Cog Data 20_01_04;
%let ArchivePath = S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Aim 1\Data Analysis\SAS Data\Archive;
%let FormatPath = S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Aim 1\Data Management\Data\formats;
%let CohortPath = S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Original Cohort Files;

%let CogDataFile = interim-cvdcogharmonize-405.dta;

libname frz "&OutDataPath";
libname arc "&ArchivePath";
libname fmts "&FormatPath";
libname ARIC "&CohortPath.\ARIC\SAS Files";
libname CARDIA "&CohortPath.\CARDIA\SAS Files";
libname CHS "&CohortPath.\CHS\SAS Files";
libname FOS "&CohortPath.\FOS\SAS Files";
libname MESA "&CohortPath.\MESA\SAS Files";
libname NOMAS "&CohortPath.\NOMAS\SAS Files";
options fmtsearch=(fmts) nofmterr;


/************************************************************************************ 
*																					*
*	Replace all cognitive data with newly harmonized cognitive data					*
*		from Alden Gross - January, 2020											*
*																					*
*		InData STATA file: interim-cvdcogharmonize-405.dta							*
*		Output SAS file: work.tmp_newcog (temporary)								*
*		Permanent OutData file created in later step 								*
*																					*
************************************************************************************/


%macro newcogdata;

proc import out=newcogdata datafile = "&InDataPath.\&CogDataFile";
run;

data newcogdata;
set newcogdata;
drop uu1--ouu166;
run;

data newcogdata2;
length newid $ 20;
set newcogdata;
length studyname $ 6 nid id_cardia2 id_chs2 id_fos2 id_mesa2 id_nomas2 $ 12;
array ida1[5] id_cardia id_chs id_fos id_mesa id_nomas;
array ida2[5] $ id_cardia2 id_chs2 id_fos2 id_mesa2 id_nomas2;
do i=1 to 5; 
	ida2[i]=put(ida1[i],12.);
end;
if data=1 then do; nid=put(id_aric,7.); studyname='aric'; end;
else if data=2 then do; nid=id_cardia2; studyname='cardia'; end;
else if data=3 then do; nid=id_chs2; studyname='chs'; end;
else if data=4 then do; nid=id_fos2; studyname='fos'; end;
else if data=5 then do; nid=id_mesa2; studyname='mesa'; end;
else do; nid=id_nomas2; studyname='nomas'; end;
newid=compress(nid||studyname);
drop i id: nid;
run;

%let snames = aric cardia chs fos mesa nomas;
%let dvars = ti_aric2 ti_cardia ti_chs2 ti_fos ti_mesa ti_nomas;

%do snum = 1 %to 6;
	%if %eval(&snum) = 1 or %eval(&snum) = 6 %then %do;
		%let tvar = visitdt;
	%end;
	%else %if %eval(&snum) = 2 or %eval(&snum) = 5 %then %do;
		%let tvar = visitno;
	%end;
	%else %do;
		%let tvar = daysfromvisit1;
	%end;

	%let sn = %scan(&snames,&snum);
	%let dv = %scan(&dvars,&snum);

	data t1;
	set arc.Masterlong_181219;
	if studyname = "&sn";
	olddata=1;
	run;

	data t2;
	set newcogdata2;
	if studyname = "&sn"/* and gcp^=.*/;
	newdata=1;
	run;

	proc sql;
	create table ml&snum as
	select a.*, 
		b.gcp as gcp_2, b.gcp_se as gcp_se_2, b.gcp_sansphone as gcp_sansphone_2,
		b.exf as exf_2, b.exf_se as exf_se_2, b.exf_sansphone as exf_sansphone_2,
		b.mem as mem_2, b.mem_se as mem_se_2, b.mem_sansphone as mem_sansphone_2,
		a.olddata as odata, b.newdata as ndata
	from t1 as a
	left join t2 as b
	on a.newid = b.newid and a.&tvar = b.&dv;
	quit;
%end;

data work.tmp_newcog;
set ml1-ml6;
if ndata then do;
	if studyname^='cardia' then do;
		gcp=gcp_2; gcp_se=gcp_se_2; gcp_sansphone=gcp_sansphone_2;
		exf=exf_2; exf_se=exf_se_2; exf_sansphone=exf_sansphone_2;
		mem=mem_2; mem_se=mem_se_2; mem_sansphone=mem_sansphone_2;
	end;
	else do;
		if gcp^=. then do;
			gcp=gcp_2; gcp_se=gcp_se_2; gcp_sansphone=gcp_sansphone_2;
			exf=exf_2; exf_se=exf_se_2; exf_sansphone=exf_sansphone_2;
			mem=mem_2; mem_se=mem_se_2; mem_sansphone=mem_sansphone_2;
		end;
	end;
end;
drop olddata--ndata;
run;

proc datasets library=work memtype=data nolist;
delete ml1-ml6 newcogdata: t1 t2;
run;
quit;

%mend;

%newcogdata;

/************************************************************************************ 
*																					*
*	Death																			*
*		Died_All (New Variable) 													*
*		= 1 for all rows for participants who died during surveillance				*
*		= 0 for all rows for participants alive at current end of surveillance		*
*																					*
*	CHS Hispanic Ethnicity and Race													*
*		Racebpcog (Modified existing variable										*
*		= 3 (Hispanic) for all 62 CHS participants with Hispanic ethnicity 			*
*																					*
************************************************************************************/

data tmp_death;
set work.tmp_newcog;
Died_All = (not missing (ttodeath));
if studyname='chs' and hisp=1 then racebpcog = 3;
run;
