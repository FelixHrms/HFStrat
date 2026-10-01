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

**# Fund locations and German futures and repo positions

* ============================================================
* DE: Average net position by country group
* ============================================================

drop _all
clear all 

import delimited "$data/germany_fund_location.csv", clear

* --- pre-2023 ---
preserve
keep if business_date < "2023-01-01"

* --- Step 1: sum net_pos within (date, group) ---
collapse (sum) net_pos, by(business_date group)

* --- Step 2: average across dates within group ---
collapse (mean) net_pos, by(group)

* --- Impose plotting order (top -> bottom) ---
gen order = .
replace order = 1 if group == "DE"
replace order = 2 if group == "FR"
replace order = 3 if group == "IE"
replace order = 4 if group == "LU"
replace order = 5 if group == "Other EA"
replace order = 6 if group == "GB"
replace order = 7 if group == "KY"
replace order = 8 if group == "Other non-EA"

* Color split: positive = green, negative = red
gen pos = net_pos if net_pos >= 0
gen neg = net_pos if net_pos <  0

* Total for the title
sum net_pos, meanonly
local total : display %12.0fc r(sum)

* --- Horizontal bar chart ---
graph hbar (asis) pos neg, ///
    over(group, sort(order)) ///
    bar(1, color(green%85)) ///
    bar(2, color(red%85)) ///
    blabel(bar, format(%12.0fc)) ///
    legend(off) ///
    ytitle("Average net position") ///
    subtitle("Net total: `total'") ///
    yline(0, lcolor(black)) ///
	yscale(range(-35 5))

graph export "$fig/DE_countries_2022.png", replace width(2400)

restore


* --- post-2025 ---
preserve
keep if business_date > "2025-01-01"

* --- Step 1: sum net_pos within (date, group) ---
collapse (sum) net_pos, by(business_date group)

* --- Step 2: average across dates within group ---
collapse (mean) net_pos, by(group)

* --- Impose plotting order (top -> bottom) ---
gen order = .
replace order = 1 if group == "DE"
replace order = 2 if group == "FR"
replace order = 3 if group == "IE"
replace order = 4 if group == "LU"
replace order = 5 if group == "Other EA"
replace order = 6 if group == "GB"
replace order = 7 if group == "KY"
replace order = 8 if group == "Other non-EA"

* Color split: positive = green, negative = red
gen pos = net_pos if net_pos >= 0
gen neg = net_pos if net_pos <  0

* Total for the title
sum net_pos, meanonly
local total : display %12.0fc r(sum)

* --- Horizontal bar chart ---
graph hbar (asis) pos neg, ///
    over(group, sort(order)) ///
    bar(1, color(green%85)) ///
    bar(2, color(red%85)) ///
    blabel(bar, format(%12.0fc)) ///
    legend(off) ///
    ytitle("Average net position") ///
    subtitle("Net total: `total'") ///
    yline(0, lcolor(black)) ///
	yscale(range(-5 35))

graph export "$fig/DE_countries_2025.png", replace width(2400)

restore















* ============================================================
* US: Average net position by country group
* ============================================================

drop _all
clear all 

import delimited "$data/us_fund_location.csv", clear

* --- pre-2023 ---
preserve
keep if business_date < "2023-01-01"

* --- Step 1: sum net_pos within (date, group) ---
collapse (sum) net_pos, by(business_date group)

* --- Step 2: average across dates within group ---
collapse (mean) net_pos, by(group)

* --- Impose plotting order (top -> bottom) ---
gen order = .
replace order = 1 if group == "DE"
replace order = 2 if group == "FR"
replace order = 3 if group == "IE"
replace order = 4 if group == "LU"
replace order = 5 if group == "Other EA"
replace order = 6 if group == "GB"
replace order = 7 if group == "KY"
replace order = 8 if group == "Other non-EA"

* Color split: positive = green, negative = red
gen pos = net_pos if net_pos >= 0
gen neg = net_pos if net_pos <  0

* Total for the title
sum net_pos, meanonly
local total : display %12.0fc r(sum)

* --- Horizontal bar chart ---
graph hbar (asis) pos neg, ///
    over(group, sort(order)) ///
    bar(1, color(green%85)) ///
    bar(2, color(red%85)) ///
    blabel(bar, format(%12.0fc)) ///
    legend(off) ///
    ytitle("Average net position") ///
    subtitle("Net total: `total'") ///
    yline(0, lcolor(black)) ///
	ylabel(-5(2.5)5) ///
	yscale(range(-5 5))

graph export "$fig/US_countries_2022.png", replace width(2400)

restore


* --- post-2025 ---
preserve
keep if business_date > "2025-01-01"

* --- Step 1: sum net_pos within (date, group) ---
collapse (sum) net_pos, by(business_date group)

* --- Step 2: average across dates within group ---
collapse (mean) net_pos, by(group)

* --- Impose plotting order (top -> bottom) ---
gen order = .
replace order = 1 if group == "DE"
replace order = 2 if group == "FR"
replace order = 3 if group == "IE"
replace order = 4 if group == "LU"
replace order = 5 if group == "Other EA"
replace order = 6 if group == "GB"
replace order = 7 if group == "KY"
replace order = 8 if group == "Other non-EA"

* Color split: positive = green, negative = red
gen pos = net_pos if net_pos >= 0
gen neg = net_pos if net_pos <  0

* Total for the title
sum net_pos, meanonly
local total : display %12.0fc r(sum)

* --- Horizontal bar chart ---
graph hbar (asis) pos neg, ///
    over(group, sort(order)) ///
    bar(1, color(green%85)) ///
    bar(2, color(red%85)) ///
    blabel(bar, format(%12.0fc)) ///
    legend(off) ///
    ytitle("Average net position") ///
    subtitle("Net total: `total'") ///
    yline(0, lcolor(black)) ///
	yscale(range(-45 35))

graph export "$fig/US_countries_2025.png", replace width(2400)

restore

* ============================================================
* Repo and futures net - DE
* ============================================================

drop _all
clear all 

import delimited "$data/DE_netpositions_limitations.csv", clear

gen bdate = date(business_date, "YMD")
format bdate %td
drop business_date
rename bdate business_date

gen net_futures_plot = net_futures
replace net_futures_plot = 400  if net_futures >  400 & !missing(net_futures)
replace net_futures_plot = -400 if net_futures < -400

gen net_repo_plot = net_repo
replace net_repo_plot = 400  if net_repo >  400 & !missing(net_repo)
replace net_repo_plot = -400 if net_repo < -400

twoway ///
    (area net_futures_plot business_date, color(blue%50)) ///
    (area net_repo_plot    business_date, color(orange%50)), ///
    legend(order(1 "Futures positions" 2 "Repo positions") ///
           position(6) rows(1)) ///
    ytitle("Net position") ///
    xtitle("") ///
    yline(0, lcolor(black)) ///
    ylabel(-400(100)400)

graph export "$fig/net_repo_futures_DE.png", replace width(2400)

**# Net repo positions, OFR comparison, duration and convexity

**# US: net position in Treasuries, one series for the whole market
* input is hf_positions_US_svensson.csv, the file HF_TEMP_US.do reads from $dir

import delimited "$data/hf_positions_US_svensson.csv", clear
	drop date
	gen date = date(business_date, "YMD")
	format date %td
	drop if itype > 4 /*keep bonds, notes and bills*/
	gen dyield = yield - yield_curve
	gen net_long = (borrowing_volume - lending_volume)/10^9 /*net long position in bn*/
	gen net_long_dur = net_long*duration /*dollar duration*/
	gen net_long_conv = net_long*convexity /*dollar convexity*/
	drop if ttm < 0.25 /*eliminates short term bonds*/
	drop if abs(dyield) > 0.5 /*drop if the bond clearly does not fit the curve*/

tempfile us_panel
save `us_panel'

collapse (sum) net_long, by(date)
tw (scatter net_long date), ///
	ytitle("Billions") xtitle("") ///
	yline(0, lcolor(black))
graph export "$fig/net_repo_US.png", replace width(3220)

**# US: SFTDS net position against the OFR hedge fund monitor, quarter ends
* same construction as ofrcomp.pdf in HF_TEMP_US.do, the last business day
* of each quarter in SFTDS against the Form PF bond exposure from the OFR
* monitor, with the slope of the fitted line printed on the chart

use `us_panel', clear
collapse (sum) net_long, by(date)
gen year = year(date)
gen quarter = quarter(date)
sort year quarter date
collapse (last) net_long, by(year quarter)
merge 1:1 year quarter using "$key/BondExposure.dta"
drop if _merge == 2
gen net = (BondExposureLong - BondExposureShort)/10^9

reg net_long net
local b  : display %4.2f _b[net]
local se : display %4.2f _se[net]
local r2 : display %4.2f e(r2)
local n  = e(N)
tw (scatter net_long net) (lfit net_long net), ///
	ytitle("SFTDS net long positions") xtitle("OFR net long positions") legend(off) ///
	note("Slope `b' (s.e. `se'), R{superscript:2} `r2', `n' quarters")
graph export "$fig/ofrcomp.png", replace width(3220)

**# Euro area: net position in DE, IT, FR and ES sovereign bonds
* input is hf_positions.csv, the file HF_TEMP.do reads from D:/mts

import delimited "$data/hf_positions.csv", clear
	drop date
	gen date = date(business_date, "YMD")
	format date %td
	replace yield = "" if substr(yield, 1, 3) == "inf"
	destring yield, replace
	replace amt_out = amt_out/10^9
	drop if strip != ""
	drop if !inlist(coupontype, 0, 1)
	gen diff_y  = yield - refyield
	gen diff_y2 = yield - yield_curve
	bysort date country: egen absmse = median(abs(diff_y2))
	drop if absmse > 0.2
	drop if yield > 7 | yield < -2 | refyield > 7 | refyield < -2
	drop if ttm < 0.25
	drop if abs(diff_y) > 0.25
	drop if abs(diff_y2) > 1
	gen net_long = (borrowing_volume - lending_volume)/10^9 /*net long position in bn*/

collapse (sum) net_long, by(date country)
tw (scatter net_long date if country == "DE") ///
   (scatter net_long date if country == "IT") ///
   (scatter net_long date if country == "FR") ///
   (scatter net_long date if country == "ES"), ///
	legend(order(1 "DE" 2 "IT" 3 "FR" 4 "ES") position(6) cols(4) region(lstyle(none))) ///
	ytitle("Billions") xtitle("") ///
	yline(0, lcolor(black))
graph export "$fig/net_repo_EA.png", replace width(3220)

**# US: futures against bond exposure, dollar duration and dollar convexity
* same construction as dur2.pdf and con2.pdf in HF_TEMP_US.do, one observation
* per Tuesday, the bond side sums the net repo position times duration or
* convexity across Treasuries, the futures side comes from futuresexposure.dta,
* with the fitted line and its slope printed on the chart

use `us_panel', clear
collapse (sum) net_long net_long_dur net_long_conv, by(date)
keep if dow(date) == 2
rename date tuesday
merge 1:m tuesday using "$key/futuresexposure.dta"
drop if _merge == 2
replace futures_dolduration = futures_dolduration/10^9
replace futures_dolconvexity = futures_dolconvexity/10^9
collapse (sum) futures_dolduration futures_dolconvexity, by(tuesday net_long net_long_dur net_long_conv)

tw (scatter futures_dolduration tuesday, ysc(reverse)) (scatter net_long_dur tuesday, yaxis(2) ) ,  legend(order(1 "DollarDuration: Futures" 2  "DollarDuration: Bond")           position(6) cols(2) region(lstyle(none))) ytitle("") ytitle("", axis(2))
	graph export "$fig/dur1.png", replace width(3220)
tw (scatter futures_dolconvexity tuesday, ysc(reverse)) (scatter net_long_conv tuesday, yaxis(2) ) ,  legend(order(1 "DollarConvexity: Futures" 2  "DollarConvexity: Bond")           position(6) cols(2) region(lstyle(none))) ytitle("") ytitle("", axis(2))
	graph export "$fig/con1.png", replace width(3220)

reg futures_dolduration net_long_dur
local b  : display %4.2f _b[net_long_dur]
local se : display %4.2f _se[net_long_dur]
local r2 : display %4.2f e(r2)
local n  = e(N)
tw (scatter futures_dolduration net_long_dur) (lfit futures_dolduration net_long_dur), ///
	ytitle("Futures dollar duration") xtitle("Bond dollar duration") legend(off) ///
	note("Slope `b' (s.e. `se'), R{superscript:2} `r2', `n' weeks")
graph export "$fig/duration_scatter.png", replace width(3220)

reg futures_dolconvexity net_long_conv
local b  : display %4.2f _b[net_long_conv]
local se : display %4.2f _se[net_long_conv]
local r2 : display %4.2f e(r2)
local n  = e(N)
tw (scatter futures_dolconvexity net_long_conv) (lfit futures_dolconvexity net_long_conv), ///
	ytitle("Futures dollar convexity") xtitle("Bond dollar convexity") legend(off) ///
	note("Slope `b' (s.e. `se'), R{superscript:2} `r2', `n' weeks")
graph export "$fig/convexity_scatter.png", replace width(3220)

**# Concentration of funds and dealers

**# Funds: each day funds are ranked by the absolute value of their net repo
* position, the figure shows the share of the five largest in the total across
* all funds trading directly, same filters as Graph.do

import delimited "$key/sftds_dataframe.csv", clear
gen date = date(business_date, "YMD")
format date %td
drop business_date
rename security_isin isin

drop if borrowing_volume > 3*10^9
drop if lending_volume > 3*10^9
gen net = (borrowing_volume - lending_volume)/10^9
gen us = substr(isin, 1, 2) == "US"

* days with a thin cross section of bonds are dropped, as in Graph.do
egen tag = tag(date isin)
bysort date: egen nbonds = total(tag)
drop if nbonds < 600

* positions routed via banks are dropped, the figure is about funds trading directly
drop if bank_indicator == 1

tempfile funds
save `funds'

foreach m in EA US {
	use `funds', clear
	if "`m'" == "EA" drop if us == 1
	if "`m'" == "US" drop if us == 0
	collapse (sum) net, by(date entity_id)
	gen absnet = abs(net)
	gsort date -absnet
	by date: gen n = _n
	by date: egen sumtop = sum(absnet*(n<=5))
	by date: egen sumall = sum(absnet)
	gen frac = sumtop/sumall
	keep date frac
	duplicates drop
	scatter frac date, ///
		ytitle("Share of the five largest funds") xtitle("") ///
		ylabel(0(.2)1)
	graph export "$fig/frac_top5_funds_`m'.png", replace width(3220)
	sum frac
}

**# Dealers: each day dealers are ranked by the absolute value of their net repo
* position with all hedge funds, the figure shows the share of the five largest
* in the total across all dealers, same cleaning as dealer_fragility_qe.do
* inputs are fund_dealer_day.csv (EUR) and fund_dealer_day_USD.csv (USD), both
* from dealer_fragility_data.ipynb

foreach m in EA US {
	if "`m'" == "EA" import delimited "$key/fund_dealer_day.csv", varnames(1) clear
	if "`m'" == "US" import delimited "$key/fund_dealer_day_USD.csv", varnames(1) clear
	capture drop v1
	gen date = date(business_date, "YMD")
	format date %td
	foreach v in borrowing_volume lending_volume {
		replace `v' = 0 if missing(`v')
	}
	* two funds report borrowing and lending the wrong way round at the beginning
	* of the sample, flip the two sides for them before 24 April 2021 as in DT.do
	gen flip = inlist(fund_id, "P5XEQYFJP74DYQX88M80", "O1XNTICYRCAHEAMEQI31") & date < td(24apr2021)
	gen tmp = borrowing_volume
	replace borrowing_volume = lending_volume if flip
	replace lending_volume = tmp if flip
	drop tmp flip

	collapse (sum) borrowing_volume lending_volume, by(date dealer_id)
	gen net = borrowing_volume - lending_volume
	gen absnet = abs(net)
	gsort date -absnet
	by date: gen n = _n
	by date: egen sumtop = sum(absnet*(n<=5))
	by date: egen sumall = sum(absnet)
	gen frac = sumtop/sumall
	keep date frac
	duplicates drop
	scatter frac date, ///
		ytitle("Share of the five largest dealers") xtitle("") ///
		ylabel(0(.2)1)
	graph export "$fig/frac_top5_dealers_`m'.png", replace width(3220)
	sum frac
}

**# Funding architecture table

cap log close
log using "$key/funding_architecture.log", replace text

**# Repo terms by fund dealer pair and relationship stability, descriptives for the funding architecture section

**# Step 1: rate spread, pair rate minus the average over all other trades on the same bond and day, in basis points

import delimited "$key/bond_day_rate.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
gen ratesum_all = market_rate*market_trades
keep date security_isin ratesum_all market_trades
tempfile market
save `market'

import delimited "$key/fund_dealer_bond_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
gen flip = inlist(fund_id, "P5XEQYFJP74DYQX88M80", "O1XNTICYRCAHEAMEQI31") & date < td(24apr2021) /*as in DT.do*/
foreach s in volume rate trades {
	gen tmp = borrowing_`s'
	replace borrowing_`s' = lending_`s' if flip
	replace lending_`s' = tmp if flip
	drop tmp
}
foreach v in borrowing_trades lending_trades {
	replace `v' = 0 if missing(`v')
}
gen ratesum = cond(borrowing_trades > 0, borrowing_rate*borrowing_trades, 0) + cond(lending_trades > 0, lending_rate*lending_trades, 0)
gen trades = borrowing_trades + lending_trades
bysort fund_id security_isin date: egen ratesum_fund = total(ratesum)
bysort fund_id security_isin date: egen trades_fund = total(trades)
merge m:1 date security_isin using `market', keep(match) nogen
gen bench = (ratesum_all - ratesum_fund)/(market_trades - trades_fund) if market_trades - trades_fund >= 3 /*at least three trades by others*/
foreach l in borrowing lending {
	gen spread_`l' = (`l'_rate - bench)*100
	gen w_`l' = `l'_trades*!missing(spread_`l')
	gen spreadw_`l' = spread_`l'*w_`l'
}
collapse (sum) spreadw_* w_*, by(fund_id dealer_id date)
foreach l in borrowing lending {
	gen spread_`l' = spreadw_`l'/w_`l' /*average over the pair's trades of the day*/
}
keep fund_id dealer_id date spread_*
tempfile spreads
save `spreads'

**# Step 2: terms per pair and day, mean and percentiles by side

import delimited "$key/fund_dealer_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
gen flip = inlist(fund_id, "P5XEQYFJP74DYQX88M80", "O1XNTICYRCAHEAMEQI31") & date < td(24apr2021)
foreach s in volume haircut tenor {
	gen tmp = borrowing_`s'
	replace borrowing_`s' = lending_`s' if flip
	replace lending_`s' = tmp if flip
	drop tmp
}
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
merge 1:1 fund_id dealer_id date using `spreads', keep(master match) nogen
foreach l in borrowing lending {
	gen zero_haircut_`l' = `l'_haircut <= 0 if !missing(`l'_haircut)
	gen short_tenor_`l' = `l'_tenor <= 7 if !missing(`l'_tenor)
}
tabstat spread_borrowing borrowing_haircut zero_haircut_borrowing borrowing_tenor short_tenor_borrowing, stat(mean p10 p50 p90 n) col(stat)
tabstat spread_lending lending_haircut zero_haircut_lending lending_tenor short_tenor_lending, stat(mean p10 p50 p90 n) col(stat)
tempfile panel
save `panel'

**# Step 3: relationships per fund and quarter on absolute net positions, dealers, share of the largest dealer, share with dealers used a year earlier

gen net = borrowing_volume - lending_volume
gen quarter = qofd(date)
collapse (sum) net, by(fund_id dealer_id quarter)
gen gross = abs(net)
drop if gross <= 0
egen pair = group(fund_id dealer_id)
xtset pair quarter
gen gross_old = gross*!missing(L4.gross)
collapse (sum) gross gross_old (max) max_gross = gross (count) n_dealers = gross, by(fund_id quarter)
egen fund = group(fund_id)
xtset fund quarter
gen main_share = max_gross/gross
gen persist = gross_old/gross if !missing(L4.gross) /*funds active a year earlier*/
tabstat n_dealers main_share persist, stat(mean p10 p50 p90 n) col(stat)

**# Figure: highest minus lowest spread across the dealers of the same fund on the same day

use `panel', clear
foreach l in borrowing lending {
	bysort fund_id date: egen max_`l' = max(spread_`l')
	bysort fund_id date: egen min_`l' = min(spread_`l')
	bysort fund_id date: egen n_`l' = count(spread_`l')
	gen gap`l' = max_`l' - min_`l' if n_`l' >= 2
}
keep fund_id date gapborrowing gaplending
duplicates drop
reshape long gap, i(fund_id date) j(side) string
sum gap, detail
histogram gap if gap <= 100, fraction
graph export "$fig/rate_gap_within_fund.png", replace width(3220)

log close

**# Pricing errors, CTD and OTR positions, convexity gap and volatility

use "$int/sftds_agg.dta", clear

preserve
	keep if country=="US" & abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	binscatter dyield net ,n(100) line(none) xline(0) yline(0) 
		graph export "$fig/US_perror.png", replace width(3220)
restore

preserve
	keep if country!="US" & abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	binscatter dyield net ,n(100) line(none) xline(0) yline(0) 
		graph export "$fig/EA_perror.png", replace width(3220)
restore

preserve
	collapse (sum) net, by(date newcountry isctd)
	tw (scatter net date if isctd==1)(scatter net date if isctd==0),by(newcountry) legend(order(1 "CTD" 2 "Not CTD") ) yline(0)
		graph export "$fig/ctd.png", replace width(3220)
restore

preserve
	collapse (sum) net, by(date newotrnumb newcountry)
	tw (scatter net date if newotrnumb==1)(scatter net date if newotrnumb==2)(scatter net date if newotrnumb==3),by(newcountry) legend(order(1 "1st OTR" 2 "2nd OTR" 3 "Other") ) yline(0)
		graph export "$fig/otr.png", replace width(3220)
restore

use "$int/sftds_agg.dta" , clear
	keep if  country=="US" & ilb==0
	gen weekn=week(date)+year(date)*100
	gen tuesday=date-dow(date)+2
	format tuesday %td
	gen bond_dollarduration=net*duration
	gen bond_dollarconvexity=net*convexity
	collapse (sum) bond_dollarduration bond_dollarconvexity ,by(date tuesday)
	collapse (mean) bond_dollarduration bond_dollarconvexity ,by(tuesday)
	drop if tuesday==mdy(7,4,2023)
	merge 1:1 tuesday using "$int/sumfutexp.dta" , keep(1 3)
	
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

	merge 1:1 tuesday using "$key/ImplVolTreasury_weekly.dta" , keep(1 3) nogen
	tw (line gapconv3 tuesday ) (line MOVE_Index___L1_ tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))
	
	tw (line gapconv3 tuesday ,ysc(reverse)) (line  TY_1M_50D_VOL_BVOL_Comdty___R1_ tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))
		graph export "$fig/convexity_gap_tyvol.png", replace width(3220)
	tw (line gapconv3 tuesday ,ysc(reverse)) (line  MOVE_Index___L1_ tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))
		graph export "$fig/convexity_gap_move.png", replace width(3220)
