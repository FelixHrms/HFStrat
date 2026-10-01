*IMPORT basis;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\data\usbasis.csv"    out=basis_us    dbms=csv    replace;   
guessingrows=max; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\data\eubasis.csv"    out=basis_eu    dbms=csv    replace;   
guessingrows=max; run;
proc sql; create table basis as select p.*, q.* from basis_eu p left join basis_us q on p.date=q.date order by p.date;quit;

*create ctd 1 and 2; 
data firstsecondCTD; format contract cusip $10.;informat contract cusip $10.;
	set 
	basis (rename=(ty1_fut_cur_gen_ticker = contract ty1_fut_ctd_cusip=cusip) keep = date ty1_fut_cur_gen_ticker ty1_fut_ctd_cusip)
	basis (rename=(fv1_fut_cur_gen_ticker = contract fv1_fut_ctd_cusip=cusip) keep = date fv1_fut_cur_gen_ticker fv1_fut_ctd_cusip)
	basis (rename=(tu1_fut_cur_gen_ticker = contract tu1_fut_ctd_cusip=cusip) keep = date tu1_fut_cur_gen_ticker tu1_fut_ctd_cusip)
	basis (rename=(uxy1_fut_cur_gen_ticker = contract uxy1_fut_ctd_cusip=cusip) keep = date uxy1_fut_cur_gen_ticker uxy1_fut_ctd_cusip)
	basis (rename=(wn1_fut_cur_gen_ticker = contract wn1_fut_ctd_cusip=cusip) keep = date wn1_fut_cur_gen_ticker wn1_fut_ctd_cusip)
	basis (rename=(us1_fut_cur_gen_ticker = contract us1_fut_ctd_cusip=cusip) keep = date us1_fut_cur_gen_ticker us1_fut_ctd_cusip)
	basis (rename=(rx1_fut_cur_gen_ticker = contract rx1_fut_ctd_cusip=cusip) keep = date rx1_fut_cur_gen_ticker rx1_fut_ctd_cusip)
	basis (rename=(oe1_fut_cur_gen_ticker = contract oe1_fut_ctd_cusip=cusip) keep = date oe1_fut_cur_gen_ticker oe1_fut_ctd_cusip)
	basis (rename=(du1_fut_cur_gen_ticker = contract du1_fut_ctd_cusip=cusip) keep = date du1_fut_cur_gen_ticker du1_fut_ctd_cusip)
	basis (rename=(ik1_fut_cur_gen_ticker = contract ik1_fut_ctd_cusip=cusip) keep = date ik1_fut_cur_gen_ticker ik1_fut_ctd_cusip)
	basis (rename=(oat1_fut_cur_gen_ticker = contract oat1_fut_ctd_cusip=cusip) keep = date oat1_fut_cur_gen_ticker oat1_fut_ctd_cusip)
	basis (rename=(ub1_fut_cur_gen_ticker = contract ub1_fut_ctd_cusip=cusip) keep = date ub1_fut_cur_gen_ticker ub1_fut_ctd_cusip)
	basis (rename=(bts1_fut_cur_gen_ticker = contract bts1_fut_ctd_cusip=cusip) keep = date bts1_fut_cur_gen_ticker bts1_fut_ctd_cusip);
run;
proc sql; 
	create table firstsecondCTD as select contract, cusip, count(date) as n from firstsecondCTD group by contract, cusip order by contract, -n;
	create table firstsecondCTD as select contract, cusip, n, sum(n) as totaln, max(n) as maxn from firstsecondCTD group by contract order by contract, cusip;
quit;
data firstsecondCTD; set firstsecondCTD; by contract cusip; frac=n/totaln;run;
proc sort data=firstsecondCTD ; by contract descending frac;run;
data firstsecondCTD; set firstsecondCTD; by contract; order+1 ; if first.contract then order=1;run;
proc transpose data=firstsecondCTD(where=(order le 2)) out=firstsecondCTD(drop= _NAME_ rename=( _1=ctd1 _2=ctd2)); by contract;id order; var cusip;run;
data firstsecondCTD; set firstsecondCTD; where contract ne "";run;
proc export data=firstsecondCTD outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\firstsecondCTD.csv" replace;run;
proc export data=firstsecondCTD outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\firstsecondCTD.dta" replace;run;

*create  and export futures-day data;
data basis(keep=date ty1_: tu1_: fv1_: uxy1_: us1_: wn1_: rx1_: oe1_: du1_: ik1_: oat1_: ub1_: bts1_: ); set basis; 
if TY2_OPEN_INT>TY1_OPEN_INT then do; 
TY1_FUT_IMPLIED_REPO_RT=TY2_FUT_IMPLIED_REPO_RT;ty1_fut_cur_gen_ticker=ty2_fut_cur_gen_ticker;ty1_fut_ctd_net_basis=ty2_fut_ctd_net_basis;TY1_OPEN_INT=TY2_OPEN_INT;
end;
if tu2_OPEN_INT>tu1_OPEN_INT then do; 
tu1_FUT_IMPLIED_REPO_RT=tu2_FUT_IMPLIED_REPO_RT;tu1_fut_cur_gen_ticker=tu2_fut_cur_gen_ticker;tu1_fut_ctd_net_basis=tu2_fut_ctd_net_basis;Tu1_OPEN_INT=Tu2_OPEN_INT;
end;
if fv2_OPEN_INT>fv1_OPEN_INT then do; 
fv1_FUT_IMPLIED_REPO_RT=fv2_FUT_IMPLIED_REPO_RT;fv1_fut_cur_gen_ticker=fv2_fut_cur_gen_ticker;fv1_fut_ctd_net_basis=fv2_fut_ctd_net_basis;fv1_OPEN_INT=fv2_OPEN_INT;
end;
if uxy2_OPEN_INT>uxy1_OPEN_INT then do; 
uxy1_FUT_IMPLIED_REPO_RT=uxy2_FUT_IMPLIED_REPO_RT;uxy1_fut_cur_gen_ticker=uxy2_fut_cur_gen_ticker;uxy1_fut_ctd_net_basis=uxy2_fut_ctd_net_basis;uxy1_OPEN_INT=uxy2_OPEN_INT;
end;
if us2_OPEN_INT>us1_OPEN_INT then do; 
us1_FUT_IMPLIED_REPO_RT=us2_FUT_IMPLIED_REPO_RT;us1_fut_cur_gen_ticker=us2_fut_cur_gen_ticker;us1_fut_ctd_net_basis=us2_fut_ctd_net_basis;us1_OPEN_INT=us2_OPEN_INT;
end;
if wn2_OPEN_INT>wn1_OPEN_INT then do; 
wn1_FUT_IMPLIED_REPO_RT=wn2_FUT_IMPLIED_REPO_RT;wn1_fut_cur_gen_ticker=wn2_fut_cur_gen_ticker;wn1_fut_ctd_net_basis=wn2_fut_ctd_net_basis;wn1_OPEN_INT=wn2_OPEN_INT;
end;
if rx2_OPEN_INT>rx1_OPEN_INT then do; 
rx1_FUT_IMPLIED_REPO_RT=rx2_FUT_IMPLIED_REPO_RT;rx1_fut_cur_gen_ticker=rx2_fut_cur_gen_ticker;rx1_fut_ctd_net_basis=rx2_fut_ctd_net_basis;rx1_OPEN_INT=rx2_OPEN_INT;
end;
if oe2_OPEN_INT>oe1_OPEN_INT then do; 
oe1_FUT_IMPLIED_REPO_RT=oe2_FUT_IMPLIED_REPO_RT;oe1_fut_cur_gen_ticker=oe2_fut_cur_gen_ticker;oe1_fut_ctd_net_basis=oe2_fut_ctd_net_basis;oe1_OPEN_INT=oe2_OPEN_INT;
end;
if du2_OPEN_INT>du1_OPEN_INT then do; 
du1_FUT_IMPLIED_REPO_RT=du2_FUT_IMPLIED_REPO_RT;du1_fut_cur_gen_ticker=du2_fut_cur_gen_ticker;du1_fut_ctd_net_basis=du2_fut_ctd_net_basis;du1_OPEN_INT=du2_OPEN_INT;
end;
if ik2_OPEN_INT>ik1_OPEN_INT then do; 
ik1_FUT_IMPLIED_REPO_RT=ik2_FUT_IMPLIED_REPO_RT;ik1_fut_cur_gen_ticker=ik2_fut_cur_gen_ticker;ik1_fut_ctd_net_basis=ik2_fut_ctd_net_basis;ik1_OPEN_INT=ik2_OPEN_INT;
end;
if oat2_OPEN_INT>oat1_OPEN_INT then do; 
oat1_FUT_IMPLIED_REPO_RT=oat2_FUT_IMPLIED_REPO_RT;oat1_fut_cur_gen_ticker=oat2_fut_cur_gen_ticker;oat1_fut_ctd_net_basis=oat2_fut_ctd_net_basis;oat1_OPEN_INT=oat2_OPEN_INT;
end;
if ub2_OPEN_INT>ub1_OPEN_INT then do; 
ub1_FUT_IMPLIED_REPO_RT=ub2_FUT_IMPLIED_REPO_RT;ub1_fut_cur_gen_ticker=ub2_fut_cur_gen_ticker;ub1_fut_ctd_net_basis=ub2_fut_ctd_net_basis;ub1_OPEN_INT=ub2_OPEN_INT;
end;
if bts2_OPEN_INT>bts1_OPEN_INT then do; 
bts1_FUT_IMPLIED_REPO_RT=bts2_FUT_IMPLIED_REPO_RT;bts1_fut_cur_gen_ticker=bts2_fut_cur_gen_ticker;bts1_fut_ctd_net_basis=bts2_fut_ctd_net_basis;bts1_OPEN_INT= bts2_OPEN_INT;
end;
run;
data basis; set basis (rename=( Date=date));run;
proc export data=basis outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\basis.dta"  replace  ; run;
proc export data=basis outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\basis.csv"  replace  ; run;

data basis_stacked; format contract cusip $10.;informat contract cusip $10.;
	set 
	basis (rename=(ty1_fut_cur_gen_ticker = contract ty1_fut_ctd_cusip=cusip ty1_FUT_IMPLIED_REPO_RT=implied_repo ty1_OPEN_INT=open_interest ty1_FUT_CTD_NET_BASIS=net_basis ) )
	basis (rename=(fv1_fut_cur_gen_ticker = contract fv1_fut_ctd_cusip=cusip  fv1_FUT_IMPLIED_REPO_RT=implied_repo fv1_OPEN_INT=open_interest fv1_FUT_CTD_NET_BASIS=net_basis ))
	basis (rename=(tu1_fut_cur_gen_ticker = contract tu1_fut_ctd_cusip=cusip  tu1_FUT_IMPLIED_REPO_RT=implied_repo tu1_OPEN_INT=open_interest tu1_FUT_CTD_NET_BASIS=net_basis ) )
	basis (rename=(uxy1_fut_cur_gen_ticker = contract uxy1_fut_ctd_cusip=cusip  uxy1_FUT_IMPLIED_REPO_RT=implied_repo uxy1_OPEN_INT=open_interest uxy1_FUT_CTD_NET_BASIS=net_basis ) )
	basis (rename=(wn1_fut_cur_gen_ticker = contract wn1_fut_ctd_cusip=cusip  wn1_FUT_IMPLIED_REPO_RT=implied_repo wn1_OPEN_INT=open_interest wn1_FUT_CTD_NET_BASIS=net_basis ) )
	basis (rename=(us1_fut_cur_gen_ticker = contract us1_fut_ctd_cusip=cusip  us1_FUT_IMPLIED_REPO_RT=implied_repo us1_OPEN_INT=open_interest us1_FUT_CTD_NET_BASIS=net_basis ) )
	basis (rename=(rx1_fut_cur_gen_ticker = contract rx1_fut_ctd_cusip=cusip  rx1_FUT_IMPLIED_REPO_RT=implied_repo rx1_OPEN_INT=open_interest rx1_FUT_CTD_NET_BASIS=net_basis ))
	basis (rename=(oe1_fut_cur_gen_ticker = contract oe1_fut_ctd_cusip=cusip  oe1_FUT_IMPLIED_REPO_RT=implied_repo oe1_OPEN_INT=open_interest oe1_FUT_CTD_NET_BASIS=net_basis ))
	basis (rename=(du1_fut_cur_gen_ticker = contract du1_fut_ctd_cusip=cusip  du1_FUT_IMPLIED_REPO_RT=implied_repo du1_OPEN_INT=open_interest du1_FUT_CTD_NET_BASIS=net_basis ) )
	basis (rename=(ik1_fut_cur_gen_ticker = contract ik1_fut_ctd_cusip=cusip  ik1_FUT_IMPLIED_REPO_RT=implied_repo ik1_OPEN_INT=open_interest ik1_FUT_CTD_NET_BASIS=net_basis ))
	basis (rename=(oat1_fut_cur_gen_ticker = contract oat1_fut_ctd_cusip=cusip oat1_FUT_IMPLIED_REPO_RT=implied_repo oat1_OPEN_INT=open_interest oat1_FUT_CTD_NET_BASIS=net_basis ) )
	basis (rename=(ub1_fut_cur_gen_ticker = contract ub1_fut_ctd_cusip=cusip  ub1_FUT_IMPLIED_REPO_RT=implied_repo ub1_OPEN_INT=open_interest ub1_FUT_CTD_NET_BASIS=net_basis ))
	basis (rename=(bts1_fut_cur_gen_ticker = contract bts1_fut_ctd_cusip=cusip  bts1_FUT_IMPLIED_REPO_RT=implied_repo bts1_OPEN_INT=open_interest bts1_FUT_CTD_NET_BASIS=net_basis ) ); 
keep  date contract cusip  implied_repo open_interest net_basis;
run;
data basis_stacked; set basis_stacked; root=substr(compress(contract, , 'd'),1,length(compress(contract, , 'd'))-1);run;
data basis_stacked(where=(net_basis ne .)); set basis_stacked; if root in ("TY","FV","TU","UXY","WN","US") then country_future="US"; 
else if root in ("DU","OE","RX","UB") then country_future="DE";
else if root in ("BTS","IK")  then country_future="IT" ;
else if root in ("OAT")  then country_future="FR" ;
run;
proc export data=basis_stacked outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\basis_stacked.dta" replace   ; run;
proc export data=basis_stacked outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\basis_stacked.csv" replace   ; run;



/*proc transpose data=basis out=basis2; by date;run;
data basis2; set basis2;format variable $30.; variable= substr(_NAME_, index(_NAME_, '_') +1); contract= substr(_NAME_, 1,index(_NAME_, '_')-1 );run;*/


*reshape deliverables; 
proc import datafile="J:\HF Strategies\hedge-fund-strategies\data\Deliverables_US.csv"    out=deliverables_US    dbms=csv    replace;    guessingrows=max; run;
data deliverables_US2;
    set deliverables_US;    length deliverable $100;    i = 1;    do while(scan(deliverable, i, ' ') ne '');        token = scan(deliverable, i, ' ');
        if token =: '91' then do;   /* starts with 91 */            cusip = token;           output;        end;        i + 1;    end;    keep contract cusip;
run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\data\Deliverables_EU.csv"    out=deliverables_EU    dbms=csv    replace;    guessingrows=max; run;
data deliverables_EU2; format contract $5. cusip $10.;
set deliverables_EU (keep=contract deliverable1 rename=(deliverable1=cusip))
 deliverables_EU (keep=contract deliverable2 rename=(deliverable2=cusip))
 deliverables_EU (keep=contract deliverable3 rename=(deliverable3=cusip))
 deliverables_EU (keep=contract deliverable4 rename=(deliverable4=cusip))
 deliverables_EU (keep=contract deliverable5 rename=(deliverable5=cusip))
 deliverables_EU (keep=contract deliverable6 rename=(deliverable6=cusip))
 deliverables_EU (keep=contract deliverable7 rename=(deliverable7=cusip))
 deliverables_EU (keep=contract deliverable8 rename=(deliverable8=cusip))
 deliverables_EU (keep=contract deliverable9 rename=(deliverable9=cusip))
 deliverables_EU (keep=contract deliverable10 rename=(deliverable10=cusip))
 deliverables_EU (keep=contract deliverable11 rename=(deliverable11=cusip))
 deliverables_EU (keep=contract deliverable12 rename=(deliverable12=cusip));
run;
data deliverables; set deliverables_US2 deliverables_EU2; where cusip ne "";run;
proc sort data=deliverables; by contract cusip;run;
data deliverables; set deliverables (rename=( Contract=contract));run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\Deliverables.csv"   data=deliverables replace;  run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\Deliverables.dta"   data=deliverables replace;  run;

/*create deliverables and ctd that can be matched easily with bond=day dataset*/
data basis_stacked_alt1; set basis_stacked; keep date contract root country_future;run;
proc sql; create table basis_stacked_alt1 as select p.*, q.* from basis_stacked_alt1 p left join deliverables q on p.contract=q.contract order by p.date, q.cusip;quit;
data basis_stacked_alt1; set basis_stacked_alt1; where cusip ne "";run;
proc transpose data=basis_stacked_alt1 out=basis_stacked_alt1; by date cusip;var contract;run;
data basis_stacked_alt1; set basis_stacked_alt1; drop _NAME_; rename COL1=deliverable_contract1 COL2=deliverable_contract2;run;

data basis_stacked_alt2; set basis_stacked; keep date contract root country_future;run;
proc sql; create table basis_stacked_alt2 as select p.*, q.* from basis_stacked_alt2 p left join firstsecondctd q on p.contract=q.contract order by p.date, p.contract;quit;
proc transpose data=basis_stacked_alt2(keep=date contract ctd1 ctd2) out=basis_stacked_alt2(rename=(_NAME_=level col1=cusip)); by date contract; var ctd1 ctd2 ; run;
proc sort data=basis_stacked_alt2 ; by date cusip;run;
data basis_stacked_alt2; set basis_stacked_alt2; where cusip ne ""; run;
proc transpose data=basis_stacked_alt2 out=basis_stacked_alt2(drop=_NAME_); by date cusip; id level; var contract;run;

proc sql; create table day_bond_deliverable_ctd as select coalesce(p.date, q.date) format ddmmyy10. as date, coalesce(p.cusip, q.cusip) as cusip, 
p.deliverable_contract1, p.deliverable_contract2, q.ctd1, q.ctd2
from basis_stacked_alt1 p full join basis_stacked_alt2 q on p.date=q.date and p.cusip=q.cusip
order by date, cusip;quit;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\day_bond_deliverable_ctd.csv"   data=day_bond_deliverable_ctd replace;  run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\key dataframe\day_bond_deliverable_ctd.dta"   data=day_bond_deliverable_ctd replace;  run;


*CREATE BOND DAY FILE WITH BOTH NS AND SVENSSON PRICES FOR ALL COUNTRIES, APPEND;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\NelsonSiegel\NelsonSiegel_DE_Prices.csv"    out=ns_DE dbms=csv    replace;    guessingrows=10000; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\NelsonSiegel\NelsonSiegel_FR_Prices.csv"    out=ns_FR dbms=csv    replace;    guessingrows=10000; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\NelsonSiegel\NelsonSiegel_IT_Prices.csv"    out=ns_IT dbms=csv    replace;    guessingrows=10000; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\NelsonSiegel\NelsonSiegel_ES_Prices.csv"    out=ns_ES dbms=csv    replace;    guessingrows=10000; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\NelsonSiegel\NelsonSiegel_US_Prices.csv"    out=ns_US dbms=csv    replace;    guessingrows=10000; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\Svensson\Svensson_DE_Prices.csv"    out=sv_DE dbms=csv    replace;    guessingrows=10000; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\Svensson\Svensson_FR_Prices.csv"    out=sv_FR dbms=csv    replace;    guessingrows=10000; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\Svensson\Svensson_IT_Prices.csv"    out=sv_IT dbms=csv    replace;    guessingrows=10000; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\Svensson\Svensson_ES_Prices.csv"    out=sv_ES dbms=csv    replace;    guessingrows=10000; run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\Svensson\Svensson_US_Prices.csv"    out=sv_US dbms=csv    replace;    guessingrows=10000; run;

data bond_ns; set ns_DE (keep = bondcode bondtype country issuedate maturitydate coupontype couponfreq couponrate firstcoupondate refdate refprice refyield
selected price_curve yield yield_curve duration convexity perconvexity 
rename =(selected = selected_ns price_curve=price_curve_ns yield=yield_check_ns yield_curve=yield_curve_ns duration=duration_ns convexity=convexity_ns perconvexity=perconvexity_ns))
ns_IT (keep = bondcode bondtype country issuedate maturitydate coupontype couponfreq couponrate firstcoupondate refdate refprice refyield
selected price_curve yield yield_curve duration convexity perconvexity 
rename =(selected = selected_ns price_curve=price_curve_ns yield=yield_check_ns yield_curve=yield_curve_ns duration=duration_ns convexity=convexity_ns perconvexity=perconvexity_ns))
ns_FR (keep = bondcode bondtype country issuedate maturitydate coupontype couponfreq couponrate firstcoupondate refdate refprice refyield
selected price_curve yield yield_curve duration convexity perconvexity 
rename =(selected = selected_ns price_curve=price_curve_ns yield=yield_check_ns yield_curve=yield_curve_ns duration=duration_ns convexity=convexity_ns perconvexity=perconvexity_ns))
ns_ES (keep = bondcode bondtype country issuedate maturitydate coupontype couponfreq couponrate firstcoupondate refdate refprice refyield
selected price_curve yield yield_curve duration convexity perconvexity 
rename =(selected = selected_ns price_curve=price_curve_ns yield=yield_check_ns yield_curve=yield_curve_ns duration=duration_ns convexity=convexity_ns perconvexity=perconvexity_ns));
run;
data bond_sv; set sv_DE (keep = bondcode bondtype country issuedate maturitydate coupontype couponfreq couponrate firstcoupondate refdate refprice refyield
selected price_curve yield yield_curve duration convexity perconvexity 
rename =(selected = selected_sv price_curve=price_curve_sv yield=yield_check_sv yield_curve=yield_curve_sv duration=duration_sv convexity=convexity_sv perconvexity=perconvexity_sv))
sv_IT (keep = bondcode bondtype country issuedate maturitydate coupontype couponfreq couponrate firstcoupondate refdate refprice refyield
selected price_curve yield yield_curve duration convexity perconvexity 
rename =(selected = selected_sv price_curve=price_curve_sv yield=yield_check_sv yield_curve=yield_curve_sv duration=duration_sv convexity=convexity_sv perconvexity=perconvexity_sv))
sv_FR (keep = bondcode bondtype country issuedate maturitydate coupontype couponfreq couponrate firstcoupondate refdate refprice refyield
selected price_curve yield yield_curve duration convexity perconvexity 
rename =(selected = selected_sv price_curve=price_curve_sv yield=yield_check_sv yield_curve=yield_curve_sv duration=duration_sv convexity=convexity_sv perconvexity=perconvexity_sv))
sv_ES (keep = bondcode bondtype country issuedate maturitydate coupontype couponfreq couponrate firstcoupondate refdate refprice refyield
selected price_curve yield yield_curve duration convexity perconvexity 
rename =(selected = selected_sv price_curve=price_curve_sv yield=yield_check_sv yield_curve=yield_curve_sv duration=duration_sv convexity=convexity_sv perconvexity=perconvexity_sv));
run;
proc sql; create table bond as select p.bondcode, p.bondtype, p.country, p.issuedate, p.maturitydate, p.coupontype, p.couponfreq, p.couponrate, p.firstcoupondate, p.refdate,
p.refprice, p.refyield, 
p.selected_ns, p.price_curve_ns, p.yield_check_ns, p.yield_curve_ns, p.duration_ns, p.convexity_ns, p.perconvexity_ns, 
q.selected_sv, q.price_curve_sv, q.yield_check_sv, q.yield_curve_sv, q.duration_sv, q.convexity_sv, q.perconvexity_sv
from bond_ns p left join bond_sv q on p.bondcode=q.bondcode and p.refdate=q.refdate order by p.refdate, p.bondcode;
quit;
data bond(drop=couponrate_str firstcoupondate_str yield_check_ns_str duration_ns_str convexity_ns_str perconvexity_ns_str 
yield_check_sv_str duration_sv_str convexity_sv_str perconvexity_sv_str); 
set bond(rename=(couponrate=couponrate_str firstcoupondate=firstcoupondate_str yield_check_ns=yield_check_ns_str duration_ns=duration_ns_str convexity_ns=convexity_ns_str
perconvexity_ns=perconvexity_ns_str yield_check_sv=yield_check_sv_str duration_sv=duration_sv_str convexity_sv=convexity_sv_str perconvexity_sv=perconvexity_sv_str));
format firstcoupondate yymmdd10.;
if couponrate_str="NaN" then couponrate_str="";couponrate=input(couponrate_str,best32.);
if firstcoupondate_str="NaT" then firstcoupondate_str="";firstcoupondate=input(firstcoupondate_str,yymmdd10.);
if yield_check_ns_str="Inf" then yield_check_ns_str="";yield_check_ns=input(yield_check_ns_str,best32.);
if duration_ns_str="NaN" then duration_ns_str="";duration_ns=input(duration_ns_str,best32.);
if convexity_ns_str="NaN" then convexity_ns_str="";convexity_ns=input(convexity_ns_str,best32.);
if perconvexity_ns_str="NaN" then perconvexity_ns_str="";perconvexity_ns=input(perconvexity_ns_str,best32.);
if yield_check_sv_str="Inf" then yield_check_sv_str="";yield_check_sv=input(yield_check_sv_str,best32.);
if duration_sv_str="NaN" then duration_sv_str="";duration_sv=input(duration_sv_str,best32.);
if convexity_sv_str="NaN" then convexity_sv_str="";convexity_sv=input(convexity_sv_str,best32.);
if perconvexity_sv_str="NaN" then perconvexity_sv_str="";perconvexity_sv=input(perconvexity_sv_str,best32.);
run;
/*proc gplot data=bond2; plot convexity_sv*convexity_ns; plot perconvexity_sv*perconvexity_ns;plot duration_ns*duration_sv;plot yield_check_ns*yield_check_sv;run;quit;*/
data bond; set bond(drop=duration_sv convexity_sv perconvexity_sv yield_check_sv);
rename duration_ns=duration convexity_ns=convexity perconvexity_ns=perconvexity yield_check_ns=yield_check bondcode=isin;
run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\Data\EA_ISIN_TO_CUSIPS.csv"    out=EU_ids dbms=csv    replace;    guessingrows=max; run;
proc sql; 
create table bond as select p.*, q.cusip from bond p left join eu_ids q on p.isin=q.isin order by p.refdate, p.isin;
quit;

proc sql; create table bond_us as select p.tcusip as cusip, p.itype as bondtype, 
p.country, p.issuedate, p.maturitydate, p.refdate, p.couponrate, p.firstcoupondate, p.couponfreq, p.TDPUBOUT as amt_pub, p.TDtotOUT as amt_tot,
p.refprice, 
p.selected as selected_ns, p.price_curve as price_curve_ns, p.yield as yield_check_ns, p.yield_curve as yield_curve_ns, p.duration as duration_ns, p.convexity as convexity_ns, p.perconvexity as perconvexity_ns, 
p.selected as selected_sv, p.price_curve as price_curve_sv, p.yield as yield_check_sv, p.yield_curve as yield_curve_sv, p.duration as duration_sv, p.convexity as convexity_sv, p.perconvexity as perconvexity_sv 
from ns_us p left join sv_us q on p.tcusip=q.tcusip and p.refdate=q.refdate order by p.refdate, p.tcusip;
quit;
data bond_us(drop= firstcoupondate_str bondtype_num amt_tot_str amt_pub_str); 
set bond_us(rename=(firstcoupondate=firstcoupondate_str bondtype=bondtype_num amt_tot=amt_tot_str amt_pub=amt_pub_str));
format firstcoupondate yymmdd10.;
if firstcoupondate_str="NaT" then firstcoupondate_str="";firstcoupondate=input(firstcoupondate_str,yymmdd10.);
if amt_pub_str="NaN" then amt_pub_str="";amt_pub=input(amt_pub_str,best32.);
if amt_tot_str="NaN" then amt_tot_str="";amt_tot=input(amt_tot_str,best32.);
bondtype=strip(put(bondtype_num,$3.));
run;
/*proc gplot data=bond_us; plot convexity_sv*convexity_ns; plot perconvexity_sv*perconvexity_ns;plot duration_ns*duration_sv;plot yield_check_ns*yield_check_sv;run;quit;*/
data bond_us; set bond_us(drop=duration_sv convexity_sv perconvexity_sv yield_check_sv);
rename duration_ns=duration convexity_ns=convexity perconvexity_ns=perconvexity yield_check_ns=yield_check;
run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\Data\TreasuryCUSIP.csv"    out=US_ids dbms=csv    replace;    guessingrows=max; run;
proc sql; 
create table bond_us as select p.*, q.isin from bond_us p left join us_ids q on p.cusip=q.cusip order by p.refdate, p.cusip;
quit;

data bond_all;format date yymmdd10.; set bond bond_us;date=refdate;run;
proc sort data=bond_all; by date country isin;run;


*CREATE OFF AND ON THE RUN INDICATOR, MERGE WITH BOND DATA, AND EXPORT;
data onoff; set bond_all; ormat=(maturitydate-issuedate)/365;run;
proc sort data=onoff; by country bondtype refdate;run;
/*proc univariate data=onoff; by country bondtype; var ormat;histogram;run;*/
data onoff; set onoff(keep=refdate ormat isin country cusip bondtype issuedate maturitydate); 
if bondtype="DEM" then do; if ormat<3 then matgroup=2; else if ormat<6 then matgroup=5; else if ormat<8 then matgroup=7; else if ormat<12 then matgroup=10;
	else if matgroup<20 then matgroup=15; else if ormat>25 then matgroup=30;end;
if bondtype="GIL" then do; if ormat<9 then matgroup=7; else if ormat<13 then matgroup=10;
	else if matgroup<20 then matgroup=15; else if ormat>25 then matgroup=30;end;
if bondtype="GTC" then do; matgroup=1;end;
if bondtype="BON" then do; if ormat<4.5 then matgroup=3; else if ormat>4.5 then matgroup=5;end;
if bondtype="CUP" then do; if ormat<11 then matgroup=10; else if ormat>11 then matgroup=30;end;
if bondtype="LET" then do;  matgroup=1;end;
if bondtype="OBE" then do; if ormat<8 then matgroup=7; else if ormat<12 then matgroup=10; else if ormat<17 then matgroup=15; else if ormat<35 then matgroup=30;
	else if ormat>35 then matgroup=50;end;
if bondtype="PRL" then do; if ormat<7.5 then matgroup=5; else if ormat<11 then matgroup=10; else if ormat<20 then matgroup=15; else if ormat<35 then matgroup=30;
	else if ormat>35 then matgroup=50;end;
if bondtype="SIL" then do; if ormat<7.5 then matgroup=5; else if ormat<13 then matgroup=10; else if ormat>13 then matgroup=15;end;
if bondtype="BNI" then do;  matgroup=5;end;
if bondtype="BTA" then do;  matgroup=5;end;
if bondtype="FFS" then do; if ormat<15 then matgroup=10; else if ormat>15 then matgroup=30;end;
if bondtype="FTB" then do;  matgroup=1;end;
if bondtype="OAI" then do; if ormat<7.5 then matgroup=5; else if ormat<12.5 then matgroup=10; else if ormat<20 then matgroup=15; else if ormat>20 then matgroup=30;end;
if bondtype="OAT" then do; if ormat<4 then matgroup=3; else if ormat<7.5 then matgroup=5; else if ormat<12.5 then matgroup=10; else if ormat<18 then matgroup=15; 
	 else if ormat<27 then matgroup=20; else if ormat<33 then matgroup=30; else if ormat>33 then matgroup=50;end;
if bondtype="BOT" then do;  matgroup=1;end;
if bondtype="BTP" then do; if ormat<4 then matgroup=3; else if ormat<6.5 then matgroup=5; else if ormat<8.5 then matgroup=8; else if ormat<14 then matgroup=10; 
	 else if ormat<17 then matgroup=15; else if ormat<23 then matgroup=20; else if ormat<33 then matgroup=30; else if ormat>33 then matgroup=50;end;
if bondtype="BTi" then do; if ormat<7.5 then matgroup=5; else if ormat<13 then matgroup=10; else if ormat<18 then matgroup=15; else if ormat>18 then matgroup=30;end;
if bondtype="CCT" then do; if ormat<6.5 then matgroup=5; else if ormat>6.5 then matgroup=7.5;end;
if bondtype="CTZ" then do; matgroup=2;end;
if bondtype="ITA" then do; matgroup=5;end;
if bondtype="1" then do; matgroup=30;end;
if bondtype="2" then do; if ormat<2.5 then matgroup=2; else if ormat<3.5 then matgroup=3; else if ormat<6 then matgroup=5; else if ormat<8 then matgroup=7; 
	 else if ormat>7 then matgroup=10;end;
if bondtype="4" then do; matgroup=1;end;
if bondtype="11" then do; matgroup=30;end;
if bondtype="12" then do; if ormat<6.5 then matgroup=5; else if ormat>6.5 then matgroup=10;end;
run;
proc sort data=onoff; by country refdate bondtype matgroup descending issuedate;run; 
data onoff; set onoff; by country refdate bondtype matgroup descending issuedate; otr_number+1; if first.matgroup then otr_number=1;run; 
/*proc gplot data=onoff; plot ormat*matgroup=country;run;quit;*/
data onoff; set onoff; keep isin cusip refdate bondtype matgroup otr_number;run;

proc sql; create table bond_all as select p.*, q.* from bond_all p left join onoff q
on p.isin=q.isin and p.cusip=q.cusip and p.refdate=q.refdate and p.bondtype=q.bondtype
order by p.date, p.country, p.isin;
quit;

data bond_all; set bond_all(rename=(CUSIP=cusip9));cusip8=substr(cusip9,1,8);run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\bond_day.csv"   data=bond_all replace;  run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\bond_day.dta"   data=bond_all replace;  run;



*IMPORT OFR DATA (quarterly for bond, weekly for futures);
proc import datafile="J:\HF Strategies\hedge-fund-strategies\Data\BondExposure.csv"    out=BondExposure    dbms=csv    replace;    guessingrows=max; run;
data BondExposure; set BondExposure; year=year(date); quarter=qtr(date);run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\BondExposure.dta"   data=BondExposure replace;  run;


proc import datafile="J:\HF Strategies\hedge-fund-strategies\Data\NetFuturesExposure.csv"    out=NetFuturesExposure    dbms=csv    replace;    guessingrows=max; run;
data NetFuturesExposure_TU(keep=date fut_positions contract_series);set	NetFuturesExposure (rename=(OFR_TU = fut_positions) ); contract_series="TU";run;
data NetFuturesExposure_FV(keep=date fut_positions contract_series);set	NetFuturesExposure (rename=(OFR_FV = fut_positions) ); contract_series="FV";run;
data NetFuturesExposure_TY(keep=date fut_positions contract_series);set	NetFuturesExposure (rename=(OFR_TY = fut_positions) ); contract_series="TY";run;
data NetFuturesExposure_UXY(keep=date fut_positions contract_series);set	NetFuturesExposure (rename=(OFR_UXY = fut_positions) ); contract_series="UXY";run;
data NetFuturesExposure_US(keep=date fut_positions contract_series);set	NetFuturesExposure (rename=(OFR_US = fut_positions) ); contract_series="US";run;
data NetFuturesExposure_WN(keep=date fut_positions contract_series);set	NetFuturesExposure (rename=(OFR_WN = fut_positions) ); contract_series="WN";run;
data NetFuturesExposure_all(rename=(date=tuesday)); format  contract_series $3.; informat  contract_series $3.; 
set NetFuturesExposure_TU  NetFuturesExposure_FV NetFuturesExposure_TY 
NetFuturesExposure_UXY NetFuturesExposure_US NetFuturesExposure_WN;
run;

data findcontracts_TU(rename=(TU1_FUT_CUR_GEN_TICKER=current TU2_FUT_CUR_GEN_TICKER=next TU1_OPEN_INT=current_OI TU2_OPEN_INT=next_OI ));
	set	basis_us (keep=date TU1_FUT_CUR_GEN_TICKER TU2_FUT_CUR_GEN_TICKER TU1_OPEN_INT TU2_OPEN_INT) ; contract_series="TU";run;
data findcontracts_TY(rename=(TY1_FUT_CUR_GEN_TICKER=current TY2_FUT_CUR_GEN_TICKER=next TY1_OPEN_INT=current_OI TY2_OPEN_INT=next_OI ));
	set	basis_us (keep=date TY1_FUT_CUR_GEN_TICKER TY2_FUT_CUR_GEN_TICKER TY1_OPEN_INT TY2_OPEN_INT) ; contract_series="TY";run;
data findcontracts_FV(rename=(FV1_FUT_CUR_GEN_TICKER=current FV2_FUT_CUR_GEN_TICKER=next FV1_OPEN_INT=current_OI FV2_OPEN_INT=next_OI ));
	set	basis_us (keep=date FV1_FUT_CUR_GEN_TICKER FV2_FUT_CUR_GEN_TICKER FV1_OPEN_INT FV2_OPEN_INT) ; contract_series="FV";run;
data findcontracts_UXY(rename=(UXY1_FUT_CUR_GEN_TICKER=current UXY2_FUT_CUR_GEN_TICKER=next UXY1_OPEN_INT=current_OI UXY2_OPEN_INT=next_OI ));
	set	basis_us (keep=date UXY1_FUT_CUR_GEN_TICKER UXY2_FUT_CUR_GEN_TICKER UXY1_OPEN_INT UXY2_OPEN_INT) ; contract_series="UXY";run;
data findcontracts_US(rename=(US1_FUT_CUR_GEN_TICKER=current US2_FUT_CUR_GEN_TICKER=next US1_OPEN_INT=current_OI US2_OPEN_INT=next_OI ));
	set	basis_us (keep=date US1_FUT_CUR_GEN_TICKER US2_FUT_CUR_GEN_TICKER US1_OPEN_INT US2_OPEN_INT) ; contract_series="US";run;
data findcontracts_WN(rename=(WN1_FUT_CUR_GEN_TICKER=current WN2_FUT_CUR_GEN_TICKER=next WN1_OPEN_INT=current_OI WN2_OPEN_INT=next_OI ));
	set	basis_us (keep=date WN1_FUT_CUR_GEN_TICKER WN2_FUT_CUR_GEN_TICKER WN1_OPEN_INT WN2_OPEN_INT) ; contract_series="WN";run;
data findcontracts_all;  format  contract_series $3. current next $6.;informat  contract_series $3. current next $6.;  
set findcontracts_TU findcontracts_TY findcontracts_UXY findcontracts_US findcontracts_WN findcontracts_FV;run;

proc sql; create table NetFuturesExposure_all as select p.*, q.* from NetFuturesExposure_all p left join findcontracts_all q 
on p.contract_series=q.contract_series and p.tuesday=q.date order by p.tuesday, p.contract_series;quit;
proc sql; 
create table NetFuturesExposure_all as select p.*, q.ctd1 as currentctd from NetFuturesExposure_all p left join firstsecondCTD q on p.current=q.contract;
create table NetFuturesExposure_all as select p.*, q.ctd1 as nextctd from NetFuturesExposure_all p left join firstsecondCTD q on p.next=q.contract 
order by p.tuesday, p.contract_series ;
quit;

proc sql; 
create table NetFuturesExposure_all as select p.*, q.duration as current_duration, q.convexity as current_convexity, q.perconvexity as current_perconvexity
from NetFuturesExposure_all p left join bond_all q on p.currentctd=q.cusip and p.tuesday=q.date order by p.tuesday, p.contract_series;
create table NetFuturesExposure_all as select p.*, q.duration as next_duration, q.convexity as next_convexity, q.perconvexity as next_perconvexity
from NetFuturesExposure_all p left join bond_all q on p.nextctd=q.cusip and p.tuesday=q.date order by p.tuesday, p.contract_series;
quit;
data NetFuturesExposure_all; set NetFuturesExposure_all; 
if next_duration=. then do;
futures_duration=current_duration;
futures_convexity=current_convexity;
end; else do;
futures_duration=(current_duration*current_OI+next_duration*next_OI)/(current_OI+next_OI);
futures_convexity=(current_convexity*current_OI+next_convexity*next_OI)/(current_OI+next_OI);;
end;
futures_dolduration=futures_duration*fut_positions;
futures_dolconvexity=futures_convexity*fut_positions;
run;

proc export data=NetFuturesExposure_all outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\futuresexposure.dta" replace;run;

/*CONVERT ALL THAT EXISTS IN CSV INTO DTA FOR EASE OF MERGE;*/
proc import datafile="J:\HF Strategies\hedge-fund-strategies\key dataframe\emir_dataframe.csv"    out=emir_dataframe    dbms=csv    replace;    guessingrows=100000; run;
/*data EMIR_DATAFRAME;
infile 'J:\HF Strategies\hedge-fund-strategies\key dataframe\emir_dataframe.csv' delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 ;
informat VAR1 best32. business_date yymmdd10.  entity_id $20. currency $3. futures_contract $29. maturity_month $10. is_bond_future best32. long_futures best32.
short_futures best32. sftds_overlap best32. futures_identifier $6. ;
format VAR1 best12.  business_date yymmdd10.  entity_id $20.  currency $3. futures_contract $29.  maturity_month $10.  is_bond_future best12. long_futures best12. 
short_futures best12. sftds_overlap best12.  futures_identifier $6. ;
input  VAR1 business_date entity_id  $ currency  $ futures_contract  $ maturity_month $ is_bond_future long_futures short_futures sftds_overlap futures_identifier  $;
run;*/
data emir_dataframe; set emir_dataframe; rename  business_date=date; drop var1;run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\emir_dataframe.dta"   data=emir_dataframe replace;  run;

proc import datafile="J:\HF Strategies\hedge-fund-strategies\key dataframe\sftds_dataframe.csv"    out=sftds_dataframe    dbms=csv    replace;    guessingrows=100000; run;
data sftds_dataframe; set sftds_dataframe; rename security_isin=isin business_date=date; drop var1;run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\sftds_dataframe.dta"   data=sftds_dataframe replace;  run;

proc import datafile="J:\HF Strategies\hedge-fund-strategies\key dataframe\overlap_hedge_funds.csv"    out=overlap_hedge_funds    dbms=csv    replace;    guessingrows=max; run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\overlap_hedge_funds.dta"   data=overlap_hedge_funds replace;  run;
proc import datafile="J:\HF Strategies\hedge-fund-strategies\key dataframe\sftds_hedgefunds.csv"    out=sftds_hedgefunds    dbms=csv    replace;    guessingrows=max; run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\sftds_hedgefunds.dta"   data=sftds_hedgefunds replace;  run;

proc import datafile="J:\HF Strategies\hedge-fund-strategies\key dataframe\ImplVolTreasury.csv"    out=ImplVolTreasury(where=(date ne .))    dbms=csv    replace;    guessingrows=max; run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\ImplVolTreasury.dta"   data=ImplVolTreasury replace;  run;
data ImplVolTreasury_weekly; set ImplVolTreasury; tuesday=date-weekday(date)+3; format tuesday ddmmyy10.;run;
proc sort data=ImplVolTreasury_weekly; by tuesday date;run;
proc univariate data=ImplVolTreasury_weekly noprint; by tuesday; var MOVE_Index___L1_ USSV0C10_BVOL_Curncy___L2_ USSV0C2_BVOL_Curncy___R2_ TY_1M_50D_VOL_BVOL_Comdty___R1_;
output mean=MOVE_Index___L1_ USSV0C10_BVOL_Curncy___L2_ USSV0C2_BVOL_Curncy___R2_ TY_1M_50D_VOL_BVOL_Comdty___R1_
out=ImplVolTreasury_weekly;run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\ImplVolTreasury_weekly.dta"   data=ImplVolTreasury_weekly replace;  run;



proc import datafile="J:\HF Strategies\hedge-fund-strategies\data\ACMtermpremium.csv"    out=ACMtermpremium(where=(date ne .))    dbms=csv    replace;    guessingrows=max; run;
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\ACMtermpremium.dta"   data=ACMtermpremium replace;  run;
data ACMtermpremium_weekly; set ACMtermpremium; tuesday=date-weekday(date)+3; format tuesday ddmmyy10.;run;
proc sort data=ACMtermpremium_weekly; by tuesday date;run;
proc summary data=ACMtermpremium_weekly nway; class tuesday; var _numeric_; output out=ACMtermpremium_weekly;run;
data ACMtermpremium_weekly(drop = date _FREQ_ _TYPE_ _STAT_); set ACMtermpremium_weekly(where=(_STAT_="MEAN"));run; 
proc export outfile="J:\HF Strategies\hedge-fund-strategies\Key dataframe\ACMtermpremium_weekly.dta"   data=ACMtermpremium_weekly replace;  run;



/*
*aggregate futures and bond positions correlate positively;
data k ; set emir_dataframe; net=long_futures-short_futures; if abs(net)<10**8;run;
proc sql; create table getnationality as select distinct contract, country_future from basis_stacked order by country_future, contract; quit;
proc sql; create table k as select p.*, q.country_future from k p left join getnationality q on p.futures_identifier = q.contract;quit;
proc sql; create table k2 as select date, futures_identifier, country_future, sum(net) as net from k where is_bond_future=1
group by date, futures_identifier, country_future order by date, country_future;quit;
proc sql; create table k2 as select p.*, q.net_basis from k2 p left join basis_stacked q on p.date=q.date and  p.futures_identifier=q.contract order by p.date, p.country_future;quit;
data k2; set k2; if net_basis ne . then iscurrent=1; else iscurrent=0;run;

proc sql; create table k3 as select date, country_future, sum(net) as net_future , sum(net*iscurrent) as net_current_future, avg(net_basis) as net_basis
from k2 group by date, country_future order by country_future, date;quit;
proc gplot data=k3; by country_future; plot (net_future net_current_future)*date/overlay legend;run;quit;


data j; set sftds_dataframe; net=borrowing_volume-lending_volume; if abs(net)<10**9; country=substr(isin,1,2);run;
proc sql; create table j2 as select date, country, sum(net) as net_bonds from j group by date, country;quit;

proc sql; create table l as select p.*, q.* from k3 p left  join j2 q on p.date=q.date and p.country_future=q.country order by  country, date;quit;

proc gplot data=l ; by country; plot net_bonds*net_future=country;run;quit;
proc gplot data=l ; by country; plot net_bonds*date; plot2 net_future*date;run;quit;
*/

/*
*are overlapping funds trading a lot in EMIR? No!;
data k ; set emir_dataframe; net=long_futures-short_futures; if abs(net)<10**8;run;
proc sql; create table getnationality as select distinct contract, country_future from basis_stacked order by country_future, contract; quit;
proc sql; create table k as select p.*, q.country_future 
from k p left join getnationality q on p.futures_identifier = q.contract;quit;
proc sql; create table k2 as select date, sftds_overlap, country_future,
sum(net) as net from k where is_bond_future=1
group by date, sftds_overlap, country_future order by date, country_future;quit;
proc sql; create table k3 as select date, country_future, sum(net) as net_future ,
sum(net*sftds_overlap) as net_overlap
from k2 group by date, country_future order by country_future, date;quit;
proc gplot data=k3; by country_future; plot (net_future net_overlap)*date/overlay legend;run;quit;

*are overlapping funds trading a lot in SFTDS? More so;
data j; set sftds_dataframe; net=borrowing_volume-lending_volume; if abs(net)<10**9; country=substr(isin,1,2);run;
proc sql; 
create table j as select *, case when entity_id in (select distinct entity_id from k ) then 1 else 0 end as emirfund from j;
quit;
proc sql; create table j2 as select date, country, sum(net) as net_bonds, sum(net*emirfund) as net_bonds_overlap
from j group by date, country order by country, date;quit;
proc gplot data=j2 ; by country; plot (net_bonds net_bonds_overlap)*date/overlay legend; run;quit;
*/

/*
*export basis;
proc import datafile="D:\MTS\usbasis.csv"    out=basis2    dbms=csv    replace;    guessingrows=max; run;
proc import datafile="D:\MTS\USD_terms.csv"    out=USD_terms    dbms=csv    replace;    guessingrows=max; run;
proc import datafile="D:\MTS\treasurycusip.csv"    out=cusip    dbms=csv    replace;    guessingrows=max; run;
data basis2; set basis2; 
if TY2_OPEN_INT>TY1_OPEN_INT then do; TY1_FUT_IMPLIED_REPO_RT=TY2_FUT_IMPLIED_REPO_RT;ty1_fut_cur_gen_ticker=ty2_fut_cur_gen_ticker;ty1_fut_ctd_cusip=ty2_fut_ctd_cusip;end;
if tu2_OPEN_INT>tu1_OPEN_INT then do; tu1_FUT_IMPLIED_REPO_RT=tu2_FUT_IMPLIED_REPO_RT;tu1_fut_cur_gen_ticker=tu2_fut_cur_gen_ticker;tu1_fut_ctd_cusip=tu2_fut_ctd_cusip;end;
if fv2_OPEN_INT>fv1_OPEN_INT then do; fv1_FUT_IMPLIED_REPO_RT=fv2_FUT_IMPLIED_REPO_RT;fv1_fut_cur_gen_ticker=fv2_fut_cur_gen_ticker;fv1_fut_ctd_cusip=fv2_fut_ctd_cusip;end;
if uxy2_OPEN_INT>uxy1_OPEN_INT then do; uxy1_FUT_IMPLIED_REPO_RT=uxy2_FUT_IMPLIED_REPO_RT;uxy1_fut_cur_gen_ticker=uxy2_fut_cur_gen_ticker;uxy1_fut_ctd_cusip=uxy2_fut_ctd_cusip;end;
if us2_OPEN_INT>us1_OPEN_INT then do; us1_FUT_IMPLIED_REPO_RT=us2_FUT_IMPLIED_REPO_RT;us1_fut_cur_gen_ticker=us2_fut_cur_gen_ticker;us1_fut_ctd_cusip=us2_fut_ctd_cusip;end;
if wn2_OPEN_INT>wn1_OPEN_INT then do; wn1_FUT_IMPLIED_REPO_RT=wn2_FUT_IMPLIED_REPO_RT;wn1_fut_cur_gen_ticker=wn2_fut_cur_gen_ticker;wn1_fut_ctd_cwnip=wn2_fut_ctd_cwnip;end;
run;

proc sql; 
create table rates as select business_date, security_isin, avg(borrowing_rate) as rate from USD_terms group by business_date, security_isin order by business_date, security_isin; 
quit;
data imprepo; format contract cusip $10.;informat contract cusip $10.;
	set 
	basis2 (rename=(ty1_fut_cur_gen_ticker = contract ty1_fut_ctd_cusip=cusip TY1_FUT_IMPLIED_REPO_RT=impliedrepo) keep = date ty1_fut_cur_gen_ticker ty1_fut_ctd_cusip TY1_FUT_IMPLIED_REPO_RT)
	basis2 (rename=(fv1_fut_cur_gen_ticker = contract fv1_fut_ctd_cusip=cusip FV1_FUT_IMPLIED_REPO_RT=impliedrepo) keep = date fv1_fut_cur_gen_ticker fv1_fut_ctd_cusip FV1_FUT_IMPLIED_REPO_RT)
	basis2 (rename=(tu1_fut_cur_gen_ticker = contract tu1_fut_ctd_cusip=cusip TU1_FUT_IMPLIED_REPO_RT=impliedrepo) keep = date tu1_fut_cur_gen_ticker tu1_fut_ctd_cusip TU1_FUT_IMPLIED_REPO_RT)
	basis2 (rename=(uxy1_fut_cur_gen_ticker = contract uxy1_fut_ctd_cusip=cusip UXY1_FUT_IMPLIED_REPO_RT=impliedrepo) keep = date uxy1_fut_cur_gen_ticker uxy1_fut_ctd_cusip UXY1_FUT_IMPLIED_REPO_RT)
	basis2 (rename=(wn1_fut_cur_gen_ticker = contract wn1_fut_ctd_cusip=cusip WN1_FUT_IMPLIED_REPO_RT=impliedrepo) keep = date wn1_fut_cur_gen_ticker wn1_fut_ctd_cusip WN1_FUT_IMPLIED_REPO_RT)
	basis2 (rename=(us1_fut_cur_gen_ticker = contract us1_fut_ctd_cusip=cusip US1_FUT_IMPLIED_REPO_RT=impliedrepo) keep = date us1_fut_cur_gen_ticker us1_fut_ctd_cusip US1_FUT_IMPLIED_REPO_RT);
run;

proc sql; 
create table imprepo as select p.*, q.* from imprepo p left join cusip q on p.cusip=q.cusip order by date, contract;
create table imprepo as select p.*, q.* from imprepo p left join rates q on p.isin=q.security_isin and p.date=q.business_date order by date, contract;
quit;
proc gplot data=imprepo; plot impliedrepo*rate;run;quit;
proc gplot data=imprepo; plot (rate impliedrepo)*date/overlay legend;run;quit;


