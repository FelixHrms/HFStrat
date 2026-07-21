/*Each bond is CTD for one contract only ever*/
use "J:/hf strategies/hedge-fund-strategies/key dataframe/basis_stacked.dta",clear
collapse (count) net_basis = n,by(date cusip)
tab net_basis

/*create bonds info*/
use "J:/hf strategies/hedge-fund-strategies/key dataframe/bond_day.dta" ,clear 
keep isin bondtype country issuedate maturitydate coupontype couponfreq couponrate  cusip8 cusip9
duplicates drop
sort isin
by isin: egen n=count(issuedate)
tab count
save "J:/hf strategies/hedge-fund-strategies/data/intermediate/bond_info.dta" , replace

/*create futures exposures US*/
use "J:\HF Strategies\hedge-fund-strategies\Key dataframe\futuresexposure.dta" ,clear 
collapse (sum) futures_dolduration futures_dolconvexity , by(tuesday)
save "J:/hf strategies/hedge-fund-strategies/data/intermediate/sumfutexp.dta" , replace

/*create futures exposures EU*/
use "J:/hf strategies/hedge-fund-strategies/key dataframe/emir_dataframe.dta",clear
drop if is_bond_future==0
drop if date > mdy(10,1,2024)
gen net = long_futures-short_futures
drop if abs(net)>3*10^8

collapse (sum) net , by(date futures_identifier)
drop if futures_identifier==""
rename futures_identifier contract
merge m:1 contract using "J:/hf strategies/hedge-fund-strategies/key dataframe/firstsecondctd.dta", keep(1 3) nogen
drop ctd2
rename ctd1 cusip8
collapse (sum) net , by(date cusip8)
merge 1:1 date cusip8 using "J:/hf strategies/hedge-fund-strategies/key dataframe/bond_day.dta" , keepusing(duration convexity isin) keep(1 3)
gen country=substr(isin,1,2)
gen futures_dolduration = net*duration
gen futures_dolconvexity = net*convexity
collapse futures_dolduration futures_dolconvexity net, by(date country)
sepscatter net date ,separate(country)
sepscatter futures_dolduration date ,separate(country)
save "J:/hf strategies/hedge-fund-strategies/data/intermediate/sumfutexpEU.dta" , replace

/*resuts*/
use "J:/hf strategies/hedge-fund-strategies/key dataframe/sftds_dataframe.dta" , clear

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

save "J:/hf strategies/hedge-fund-strategies/data/intermediate/sftds.dta" , replace

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
use "J:/hf strategies/hedge-fund-strategies/data/intermediate/sftds.dta", clear
collapse (sum) net, by(date isin)
*keep net date isin entity_id
encode isin, g(bond)
merge m:1 isin using  "J:/hf strategies/hedge-fund-strategies/data/intermediate/bond_info.dta" , keep(1 3) nogen 
gen cusip=cusip8
merge 1:1 date cusip using "J:/hf strategies/hedge-fund-strategies/key dataframe/basis_stacked.dta" , gen(mergebasis)
drop if date <mdy(1,4,2021)|date>mdy(9,30,2025)
bysort date: egen nbonds=nvals(cusip)
drop if nbonds<600
tab mergebasis
gen ttm=(maturitydate-date)/365
gen ilb=inlist(bondtype,"11","12")|coupontype==3
encode bondtype, gen(bondtype_n)

merge 1:1 date isin using "J:/hf strategies/hedge-fund-strategies/key dataframe/bond_day.dta" , keep(1 3) gen(mergeprices) ///
keepusing(refprice refyield selected_ns price_curve_ns yield_curve_ns selected_sv price_curve_sv yield_curve_sv yield_check duration convexity perconvexity amt_pub amt_tot matgroup otr_number)

merge 1:1 date cusip using "J:/hf strategies/hedge-fund-strategies/key dataframe/day_bond_deliverable_ctd.dta" , keep(1 3) gen(mergectddlv) 

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
save "J:/hf strategies/hedge-fund-strategies/data/intermediate/sftds_agg.dta" , replace

sepscatter dyield ttm if abs(dyield)<10 & month(date)==4 & year(date)==2022 & country=="US" ,separate(bondtype )

sepscatter dyield ttm if abs(dyield)<10 & month(date)==4 & year(date)==2022 & country!="US" ,separate(coupontype )

preserve
	keep if country=="US" & abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	reghdfe net  ,a(date)
	reghdfe net isctd isdlv ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield isnearotr ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield isnearotr duration convexity,a(date) vce(cluster date bond)
	binscatter dyield net ,n(100) line(none) xline(0) yline(0) 
restore

preserve
	keep if country!="US" & abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	reghdfe net  ,a(date)
	reghdfe net isctd isdlv ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield isnearotr ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield isnearotr duration convexity,a(date) vce(cluster date bond)
	binscatter dyield net ,n(100) line(none) xline(0) yline(0) 
restore

preserve
	keep if abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	binscatter dyield net ,n(100) line(none) xline(0) yline(0) 
restore

preserve
	collapse (sum) net, by(date newcountry isctd)
	tw (scatter net date if isctd==1)(scatter net date if isctd==0),by(newcountry) legend(order(1 "CTD" 2 "Not CTD") ) yline(0)
restore

preserve
	collapse (sum) net, by(date newotrnumb newcountry)
	sepscatter net date , separate(newotrnumb)
	tw (scatter net date if newotrnumb==1)(scatter net date if newotrnumb==2)(scatter net date if newotrnumb==3),by(newcountry) legend(order(1 "1st OTR" 2 "2nd OTR" 3 "Other") ) yline(0)
restore

preserve
	gen absnet=abs(net)
	gen qtyctd=absnet*isctd
	gen qtydlv=absnet*isdlv	
	gen qtyotr=absnet*isnearotr
	collapse (sum) absnet qtyctd qtydlv qtyotr , by(date newcountry)
	order newcountry date 
	gen fracctd=qtyctd/absnet
	gen fracdlv=qtydlv/absnet
	gen fracotr=qtyotr/absnet
	tw (scatter fracctd date if newcountry=="US") (scatter fracctd date if newcountry=="EU"), legend(order(1 "US" 2 "EU") ) yline(0) ylabel(0(0.1)1)
	tw (scatter fracdlv date if newcountry=="US") (scatter fracdlv date if newcountry=="EU"), legend(order(1 "US" 2 "EU") ) yline(0) ylabel(0(0.1)1)
	tw (scatter fracotr date if newcountry=="US") (scatter fracotr date if newcountry=="EU"), legend(order(1 "US" 2 "EU") ) yline(0) ylabel(0(0.1)1)
restore

preserve
	gen direction=net>0
	gen qtyctd=net*isctd
	gen qtydlv=net*isdlv	
	gen qtyotr=net*isnearotr
	collapse (sum) net qtyctd qtydlv qtyotr , by(date newcountry direction)
	order newcountry date 
	gen fracctd=qtyctd/net
	gen fracdlv=qtydlv/net
	gen fracotr=qtyotr/net
	gen side=" Long "
	replace side =" Short" if direction==0
	tw (line fracctd date if newcountry=="US"&direction==1, lc(blue))(line fracctd date if newcountry=="US"&direction==0,  lc(blue) lp(dash)) ///
	(line fracctd date if newcountry=="EU" &direction==1 , lc(red)) 	(line fracctd date if newcountry=="EU"&direction==0, lc(red)  lp(dashed)) ///
	, legend(order(1 "US Long" 2 "US Short" 3 "EU Long" 4 "EU Short" )) yline(0) ylabel(0(0.1)1)
	tw (line fracdlv date if newcountry=="US"&direction==1, lc(blue))(line fracdlv date if newcountry=="US"&direction==0,  lc(blue) lp(dash)) ///
	(line fracdlv date if newcountry=="EU" &direction==1 , lc(red)) 	(line fracdlv date if newcountry=="EU"&direction==0, lc(red)  lp(dash)) ///
	, legend(order(1 "US Long" 2 "US Short" 3 "EU Long" 4 "EU Short" )) yline(0) ylabel(0(0.1)1)
	tw (line fracotr date if newcountry=="US"&direction==1, lc(blue))(line fracotr date if newcountry=="US"&direction==0,  lc(blue) lp(dash)) ///
	(line fracotr date if newcountry=="EU" &direction==1 , lc(red)) 	(line fracotr date if newcountry=="EU"&direction==0, lc(red)  lp(dash)) ///
	, legend(order(1 "US Long" 2 "US Short" 3 "EU Long" 4 "EU Short" )) yline(0) ylabel(0(0.1)1)
	gen quad=newcountry+side
	*hist fracctd,by(quad)
	*hist fracdlv,by(quad)
	hist fracotr,by(quad)
restore

preserve
	keep if abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	binscatter net otr_number if otr_number<10 ,discrete line(none) by(country)
restore

preserve
	keep if  country=="US"
	gen bond_dollarduration=net*duration
	gen bond_dollarconvexity=net*convexity	
	collapse (sum) net bond_dollarduration bond_dollarconvexity, by(date )
	gen year=year(date)
	gen quarter=quarter(date)
	collapse (last) net bond_dollarduration bond_dollarconvexity , by(year quarter )
	merge 1:1 year quarter using "J:\HF Strategies\hedge-fund-strategies\key dataframe/BondExposure.dta" , nogen keep(1 3)
	gen netOFR=(BondExposureLong-BondExposureShort)/10^9
	tw (scatter net netOFR)(lfit net netOFR) , ytitle("SFTDS Net Long Positions") xtitle("OFR Net Long Positions") legend(off)
	reg   net netOFR
	reg   net netOFR ,nocon	
	reg   netOFR net
	reg   netOFR net ,nocon	
restore



use "J:/hf strategies/hedge-fund-strategies/data/intermediate/sftds_agg.dta" , clear
	keep if  country=="US" & ilb==0
	gen weekn=week(date)+year(date)*100
	gen tuesday=date-dow(date)+2
	format tuesday %td
	gen bond_dollarduration=net*duration
	gen bond_dollarconvexity=net*convexity
	collapse (sum) bond_dollarduration bond_dollarconvexity ,by(date tuesday)
	collapse (mean) bond_dollarduration bond_dollarconvexity ,by(tuesday)
	drop if tuesday==mdy(7,4,2023)
	merge 1:1 tuesday using "J:/hf strategies/hedge-fund-strategies/data/intermediate/sumfutexp.dta" , keep(1 3)
	
	sort tuesday 
	replace futures_dolduration=futures_dolduration/10^9
	replace futures_dolconvexity=futures_dolconvexity/10^9
	
	scatter futures_dolduration bond_dollarduration
	scatter futures_dolconvexity bond_dollarconvexity
	tw (line futures_dolduration tuesday, ysc(reverse)) (line bond_dollarduration tuesday, yaxis(2)) , legend(pos(6))
	tw (line futures_dolconvexity tuesday, ysc(reverse)) (line bond_dollarconvexity tuesday, yaxis(2)) , legend(pos(6))
	
	reg  futures_dolduration bond_dollarduration
	reg  futures_dolduration bond_dollarduration  if tuesday>mdy(5,1,2021)
	/* -4.073459 */
	reg  bond_dollarduration futures_dolduration

	gen futures_dolduration_resc1=-(futures_dolduration)/3.760466 
	gen futures_dolduration_resc2=-(futures_dolduration)*.1694139 +308
	gen futures_dolduration_resc3=-(futures_dolduration)*.3224487 
	
	scatter futures_dolduration_resc1 bond_dollarduration
	gen gapdur1= futures_dolduration_resc1-bond_dollarduration
	gen gapdur2= futures_dolduration_resc2-bond_dollarduration
	gen gapdur3= futures_dolduration_resc3-bond_dollarduration
	tw (line futures_dolduration_resc1 tuesday, ysc(reverse)) (line bond_dollarduration tuesday) , legend(pos(6))
	line gapdur3 tuesday 
	line gapdur1 tuesday 
	
	scatter futures_dolconvexity bond_dollarconvexity
	gen futures_dolconvexity_resc1=-futures_dolconvexity/3.755
	gen futures_dolconvexity_resc2=-futures_dolconvexity*0.1667511
	gen futures_dolconvexity_resc3=-futures_dolconvexity*0.3085725
	scatter futures_dolconvexity_resc1 bond_dollarconvexity
	reg futures_dolconvexity bond_dollarconvexity
	tw (line futures_dolconvexity_resc1 tuesday, ysc(reverse)) (line bond_dollarconvexity tuesday) , legend(pos(6))
	gen gapconv1= futures_dolconvexity_resc1-bond_dollarconvexity
	gen gapconv2= futures_dolconvexity_resc2-bond_dollarconvexity
	gen gapconv3= futures_dolconvexity_resc3-bond_dollarconvexity
	gen gapconvraw= futures_dolconvexity -bond_dollarconvexity
	line gapconv1 tuesday 
	line gapconvraw tuesday 

	merge 1:1 tuesday using "J:\HF Strategies\hedge-fund-strategies\Key dataframe\ImplVolTreasury_weekly.dta" , keep(1 3) nogen
	tw (line gapconv3 tuesday ) (line MOVE_Index___L1_ tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))
	
	tw (line gapconv3 tuesday ,ysc(reverse)) (line  TY_1M_50D_VOL_BVOL_Comdty___R1_ tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))
	tw (line gapconv3 tuesday ,ysc(reverse)) (line  MOVE_Index___L1_ tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))

	merge 1:1 tuesday using "J:\HF Strategies\hedge-fund-strategies\Key dataframe\ACMtermpremium_weekly.dta" , keep(1 3) nogen
	gen term= ACMTP10 -    ACMTP02
		
	tw (line gapconv1 tuesday ) (line  ACMTP10 tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))	
	tw (line gapconv1 tuesday ) (line  term tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))	
		
 reg  futures_dolconvexity bond_dollarconvexity term MOVE_Index___L1_,robust
  reg  futures_dolconvexity bond_dollarconvexity ACMTP10    ACMTP02 MOVE_Index___L1_,robust
 reg  futures_dolduration  bond_dollarduration term  MOVE_Index___L1_,robust

egen tuesday_n= group(tuesday)
tsset tuesday_n

 reg  d.futures_dolconvexity d.bond_dollarconvexity d.term d.MOVE_Index___L1_,robust
  reg  d.futures_dolconvexity d.bond_dollarconvexity d.ACMTP10    d.ACMTP02 d.MOVE_Index___L1_,robust
 reg  d.futures_dolduration  d.bond_dollarduration d.term d.MOVE_Index___L1_,robust


use "J:/hf strategies/hedge-fund-strategies/data/intermediate/sftds_agg.dta" , clear
	keep if  country=="DE" & ilb==0
	gen bond_dollarduration=net*duration
	gen bond_dollarconvexity=net*convexity
	collapse (sum) bond_dollarduration bond_dollarconvexity ,by(date country)
	merge 1:1 date country using "J:/hf strategies/hedge-fund-strategies/data/intermediate/sumfutexpEU.dta" , keep(1 3)
	
	replace futures_dolduration=futures_dolduration/10^9
	replace futures_dolconvexity=futures_dolconvexity/10^9
	scatter futures_dolduration bond_dollarduration
	scatter futures_dolconvexity bond_dollarconvexity
	tw (line futures_dolduration date) (line bond_dollarduration date, yaxis(2)) , legend(pos(6))
	tw (line futures_dolconvexity date ) (line bond_dollarconvexity date, yaxis(2)) , legend(pos(6))

	tsset date
	gen fduration=l90.futures_dolduration
	tw (line fduration date) (line bond_dollarduration date, yaxis(2)) , legend(pos(6))