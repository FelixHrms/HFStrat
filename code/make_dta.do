clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"
capture mkdir "$root/data"
capture mkdir "$int"
capture mkdir "$fig"

capture confirm file "$key/sftds_dataframe.dta"
if _rc {
	import delimited "$key/sftds_dataframe.csv", clear
	capture drop v1
	gen date = date(business_date, "YMD")
	format date %td
	rename security_isin isin
	save "$key/sftds_dataframe.dta", replace
}
capture confirm file "$key/emir_dataframe.dta"
if _rc {
	import delimited "$key/emir_dataframe.csv", clear
	capture drop v1
	gen date = date(business_date, "YMD")
	format date %td
	save "$key/emir_dataframe.dta", replace
}

/*Each bond is CTD for one contract only ever*/
use "$key/basis_stacked.dta",clear
collapse (count) net_basis = n,by(date cusip)
tab net_basis

/*create bonds info*/
use "$key/bond_day.dta" ,clear 
keep isin bondtype country issuedate maturitydate coupontype couponfreq couponrate  cusip8 cusip9
duplicates drop
sort isin
by isin: egen n=count(issuedate)
tab count
save "$int/bond_info.dta" , replace

/*create futures exposures US*/
use "$key/futuresexposure.dta" ,clear 
collapse (sum) futures_dolduration futures_dolconvexity , by(tuesday)
save "$int/sumfutexp.dta" , replace

/*create futures exposures EU*/
use "$key/emir_dataframe.dta",clear
drop if is_bond_future==0
drop if date > mdy(10,1,2024)
gen net = long_futures-short_futures
drop if abs(net)>3*10^8

collapse (sum) net , by(date futures_identifier)
drop if futures_identifier==""
rename futures_identifier contract
merge m:1 contract using "$key/firstsecondctd.dta", keep(1 3) nogen
drop ctd2
rename ctd1 cusip8
collapse (sum) net , by(date cusip8)
merge 1:1 date cusip8 using "$key/bond_day.dta" , keepusing(duration convexity isin) keep(1 3)
gen country=substr(isin,1,2)
gen futures_dolduration = net*duration
gen futures_dolconvexity = net*convexity
collapse futures_dolduration futures_dolconvexity net, by(date country)
sepscatter net date ,separate(country)
sepscatter futures_dolduration date ,separate(country)
save "$int/sumfutexpEU.dta" , replace

/*resuts*/
use "$key/sftds_dataframe.dta" , clear

encode isin, g(bond)
encode entity_id, g(fund)

drop if borrowing_volume >3*10^9
drop if lending_volume >3*10^9	

gen country=substr(isin,1,2)
sort date entity_id isin

replace borrowing_volume=borrowing_volume/10^9
replace lending_volume=lending_volume/10^9

*********FELIX ADDITION: FLIP BORROWING AND LENDING FOR THESE TWO ENTITIES AND THE BEGINNING OF THE SAMPLE***************
*************************************************************************************************************************
gen tmp = borrowing_volume if inlist(entity_id,"P5XEQYFJP74DYQX88M80","O1XNTICYRCAHEAMEQI31") & date < td(24apr2021)
replace borrowing_volume = lending_volume if !missing(tmp)
replace lending_volume = tmp if !missing(tmp)
drop tmp
*************************************************************************************************************************
*************************************************************************************************************************

gen net=(borrowing_volume-lending_volume)

by date: egen nbonds = nvals(isin)
by date: egen nfunds = nvals(entity_id)

preserve
	keep date nbonds nfunds 
	duplicates drop
	scatter nbonds date 
	scatter nfunds date 
	scatter nbonds nfunds
restore

save "$int/sftds.dta" , replace

drop if nbonds < 600 

/* THE MAJORITY OF TRADING IN SFTDS IS BY FUNDS DIRECTLY, NOT VIA BANKS, ESPECIALLY TRUE FOR US*/
preserve
	drop if substr(isin,1,2) == "US"
	collapse (sum) net, by(date  bank_indicator)
	tw (scatter net date if bank_indicator==1) (scatter net date if bank_indicator==0) , legend(order(1 "Via Banks" 2 "Direct"))
restore
preserve
	drop if substr(isin,1,2) != "US"
	collapse (sum) net, by(date  bank_indicator)
	tw (scatter net date if bank_indicator==1) (scatter net date if bank_indicator==0) , legend(order(1 "Via Banks" 2 "Direct"))
restore

/*35% of positions are made up by 5 funds, 50% by the top 10 */
preserve
	drop if bank_indicator==1
	collapse (sum) net, by(date entity_id)
	gen absnet=abs(net)
	gsort date -absnet
	by date: gen n=_n
	by date: egen sumtop=sum(absnet*(n<=10))
	by date :  egen sumall=sum(absnet)
	gen frac=sumtop/sumall
	scatter frac date	
	sum frac
restore

/*Positions in bonds are somewhat concentrated. Top 10 bonds for each country make up 22% of total positions in US 41 DE 28 IT, a single bond was at most 10% of total borrowing/lending in US (9 DE, 7 IT) */
preserve
	collapse (sum) net, by(date isin)
	gen country=substr(isin,1,2)
	gen absnet=abs(net)
	gsort date country -absnet
	by date country: gen n=_n
	by date country: egen sumtop=sum(absnet*(n<=10))
	by date country: egen sumall=sum(absnet)	
	by date country: egen nbonds=max(n)
	gen frac_top=sumtop/sumall
	gen frac = absnet/sumall
	sepscatter frac_top date	 , separate(country)
	bysort country:	sum frac_top frac nbonds
restore


/*CTD and OTR*/
use "$int/sftds.dta", clear
collapse (sum) net, by(date isin)
*keep net date isin entity_id
encode isin, g(bond)
merge m:1 isin using  "$int/bond_info.dta" , keep(1 3) nogen 
gen cusip=cusip8
merge 1:1 date cusip using "$key/basis_stacked.dta" , gen(mergebasis)
drop if date <mdy(1,4,2021)|date>mdy(9,30,2025)
bysort date: egen nbonds=nvals(cusip)
drop if nbonds<600
tab mergebasis
gen ttm=(maturitydate-date)/365
gen ilb=inlist(bondtype,"11","12")|coupontype==3
encode bondtype, gen(bondtype_n)

merge 1:1 date isin using "$key/bond_day.dta" , keep(1 3) gen(mergeprices) ///
keepusing(refprice refyield selected_ns price_curve_ns yield_curve_ns selected_sv price_curve_sv yield_curve_sv yield_check duration convexity perconvexity amt_pub amt_tot matgroup otr_number)

merge 1:1 date cusip using "$key/day_bond_deliverable_ctd.dta" , keep(1 3) gen(mergectddlv) 

gen newotrnumb=otr_number
replace newotrnumb=3 if otr_number>=3
label define otrnmbr 1 "1st" 2 "2nd" 3 "Other"
label values newotrnumb otrnmbr
gen newcountry="US"
replace newcountry="EU" if country!="US"
gen isnearotr=otr_number<3
	
gen isdlv=deliverable_contract1!=""|deliverable_contract2!=""
gen isctd=ctd1!=""|ctd2!=""
 
gen dyield=yield_check- yield_curve_sv
save "$int/sftds_agg.dta" , replace

foreach f in fund_dealer_day fund_dealer_day_USD {
	import delimited "$key/`f'.csv", varnames(1) clear
	capture drop v1
	gen date = date(business_date, "YMD")
	format date %td
	foreach v in borrowing_volume lending_volume {
		replace `v' = 0 if missing(`v')
	}
	gen flip = inlist(fund_id, "P5XEQYFJP74DYQX88M80", "O1XNTICYRCAHEAMEQI31") & date < td(24apr2021)
	foreach s in volume haircut tenor {
		gen tmp = borrowing_`s'
		replace borrowing_`s' = lending_`s' if flip
		replace lending_`s' = tmp if flip
		drop tmp
	}
	drop flip
	save "$int/`f'.dta", replace
}

import delimited "$key/fund_dealer_bond_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
gen flip = inlist(fund_id, "P5XEQYFJP74DYQX88M80", "O1XNTICYRCAHEAMEQI31") & date < td(24apr2021)
foreach s in volume rate trades {
	gen tmp = borrowing_`s'
	replace borrowing_`s' = lending_`s' if flip
	replace lending_`s' = tmp if flip
	drop tmp
}
drop flip
save "$int/fund_dealer_bond_day.dta", replace
