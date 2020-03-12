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
%let FormatPath = S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Aim 1\Data Management\Data\formats;
%let CohortPath = S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Original Cohort Files;
%let MemPath = S:\Intmed_Rsrch2\GenMed\Restricted\BP COG\Aim 1\Data Management\Data;

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
libname NDE "&CohortPath.\nde.Death_dec2019_Events_Dec2019";  /* NOMAS Death and Events Dec 2019 */
libname mem "&MemPath";
options fmtsearch=(fmts) nofmterr;


/************************************************************************************ 
*																					*
*	Replace all cognitive data with newly harmonized cognitive data					*
*		from Alden Gross - January, 2020											*
*																					*
*		Input STATA file: interim-cvdcogharmonize-405.dta (InDataPath Folder)		*
*		Output SAS file: work.tmp_newcog (temporary)								*
*		Permanent OutDataPath file created in later step							*
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
	set mem.masterlong190604;
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
*	Death/MI/Stroke Updates (NOMAS)													*
*																					*
*	Death (All Cohorts)																*
*		Died_All (New Variable) 													*
*		= 1 for all rows for participants who died during surveillance				*
*		= 0 for all rows for participants alive at current end of surveillance		*
*																					*
*	Hispanic Ethnicity and Race (CHS)												*
*		Racebpcog (Modified existing variable										*
*		= 3 (Hispanic) for all 62 CHS participants with Hispanic ethnicity 			*
*																					*
************************************************************************************/



proc sort data=nomas.demo out=tmp_demo (keep=ID BDATE); by ID; run;
proc sort data=nde.Death_dec2019 out=tmp_death; by ID; run;

data nomas_death; 
length newid $21.;
merge tmp_death (in=in1) tmp_demo;
by ID;
if in1;
deathdt2=DEATHDATE;
newid=compress(id||'nomas');
studyname2='nomas';
dead2=1;
ttodeath2 = intck('day',BDATE,DEATHDATE);
keep newid deathdt2 dead2 ttodeath2 studyname2;
format deathdt2 mmddyy10.;
run;

proc sort data=nomas_death; by newid; run;
proc sort data=mem.death; by newid; run;
proc sort data=mem.masterlong190604; by newid; run;

Data mem.death;
merge mem.death (in=in1) nomas_death (in=in2); 
by newid;
if in2 then do;
	dead=dead2; deathdt=deathdt2; ttodeath=ttodeath2; studyname=studyname2;
end;
keep newid studyname deathdt ttodeath dead;
format deathdt mmddyy10.;
run;

proc sort data=nde.stroke_dec2019 out=tmp_stroke; by id; run;
proc sort data=tmp_death out=tmp_death2; by id; where vcause=1; run;

data nomas_stroke; 
length newid $21.;
merge tmp_stroke (in=in1) tmp_death2 (in=in2) tmp_demo;
by id;
if in1 or in2;
newid=compress(id||'nomas');
studyname2='nomas';
strokedt2=EVENTDATE;
strokeinc2=1;
if STROKETYPE=1 then stroketype2=1;
if STROKETYPE=2 then stroketype2=2;
if STROKETYPE=3 then stroketype2=3;
if STROKETYPE=4 then stroketype2=4;
ttostk2 = intck('day',BDATE,EVENTDATE);
*Fatal stroke (definite);
if in2 then do;
	strokefatal2=1;
	if missing(strokedt2) then do; 
		strokedt2=DEATHDATE;
		ttostk2 = intck('day',BDATE,DEATHDATE);
	end;
end;
keep newid studyname2 strokeinc2 ttostk2 strokedt2 stroketype2 strokefatal2;
format strokedt2 mmddyy10.;
run;

proc sort data=nomas_stroke; by newid; run;
proc sort data=mem.stroke; by newid; run;

data mem.stroke;
merge mem.stroke (in=in1) nomas_stroke (in=in2); 
by newid;
if in2 then do;
	strokeinc=strokeinc2; strokedt=strokedt2; ttostk=ttostk2; stroketype=stroketype2; strokefatal=strokefatal2; studyname=studyname2;
end;
keep newid studyname strokeinc strokedt ttostk stroketype strokefatal;
format strokedt mmddyy10.;
run;

proc sort data=nde.cardiac_dec2019 out=tmp_mi; by id; run;

data nomas_mi;
length newid $21.;
merge tmp_mi (in=in1) tmp_demo;
if in1;
newid=compress(id||'nomas');
studyname2='nomas';
*Incident MI (definite only);
if CARDDX=1 then midefinite2=1; else if CARDDX^=. then midefinite2=0;
*Incident MI (definite or probable);
if CARDDX=2 then miprobable2=1; else if CARDDX^=. then miprobable2=0;
*Date of MI;
midt2=EVENTDATE;
*Incident MI or fatal CHD;
if  CARDDX =1 then miinc2=1;
ttomi2=intck('day',BDATE,EVENTDATE);
if miinc2=1;
keep newid studyname2 midefinite2 miprobable2 midt2 miinc2 ttomi2;
run;

proc sort data=nomas_mi; by newid; run;
proc sort data=mem.mi; by newid; run;

data mi;
merge mem.mi (in=in1) nomas_mi (in=in2); 
by newid;
if in2 then do;
	miinc=miinc2; midt=midt2; ttosmi=ttomi2; midefinite=midefinite2; miprobable=miprobable2; studyname=studyname2;
end;
keep newid studyname miinc midefinite miprobable midt ttomi;
format midt mmddyy10.;
run;
