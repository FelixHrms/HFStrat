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

**# Net repo positions and OFR comparison

use "$int/sftds_agg.dta", clear

preserve
	keep if country=="US" & ilb==0
	collapse (sum) net, by(date)
	tw (scatter net date), ytitle("Billions") xtitle("") yline(0, lcolor(black))
	graph export "$fig/net_repo_US.png", replace width(3220)
restore

preserve
	keep if inlist(country, "DE", "IT", "FR", "ES") & ilb==0
	collapse (sum) net, by(date country)
	tw (scatter net date if country=="DE") (scatter net date if country=="IT") (scatter net date if country=="FR") (scatter net date if country=="ES"), ///
		legend(order(1 "DE" 2 "IT" 3 "FR" 4 "ES") position(6) cols(4) region(lstyle(none))) ytitle("Billions") xtitle("") yline(0, lcolor(black))
	graph export "$fig/net_repo_EA.png", replace width(3220)
restore

preserve
	keep if  country=="US"
	gen bond_dollarduration=net*duration
	gen bond_dollarconvexity=net*convexity	
	collapse (sum) net bond_dollarduration bond_dollarconvexity, by(date )
	gen year=year(date)
	gen quarter=quarter(date)
	collapse (last) net bond_dollarduration bond_dollarconvexity , by(year quarter )
	merge 1:1 year quarter using "$key/BondExposure.dta" , nogen keep(1 3)
	gen netOFR=(BondExposureLong-BondExposureShort)/10^9
	reg net netOFR
	local b  : display %4.2f _b[netOFR]
	local se : display %4.2f _se[netOFR]
	local r2 : display %4.2f e(r2)
	local n  = e(N)
	tw (scatter net netOFR)(lfit net netOFR) , ytitle("SFTDS net long positions") xtitle("OFR net long positions") legend(off) ///
		note("Slope `b' (s.e. `se'), R{superscript:2} `r2', `n' quarters")
	graph export "$fig/ofrcomp.png", replace width(3220)
restore

**# Concentration of funds and dealers

**# Funds: each day funds are ranked by the absolute value of their net repo
* position, the figure shows the share of the five largest in the total across
* all funds trading directly

use "$int/sftds.dta", clear
gen us = substr(isin, 1, 2) == "US"
drop if nbonds < 600
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
* in the total across all dealers

foreach m in EA US {
	if "`m'" == "EA" use "$int/fund_dealer_day.dta", clear
	if "`m'" == "US" use "$int/fund_dealer_day_USD.dta", clear

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

use "$int/fund_dealer_bond_day.dta", clear
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

use "$int/fund_dealer_day.dta", clear
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

**# Pricing errors, CTD and OTR positions, duration and convexity, convexity gap and volatility

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

	tw (scatter futures_dolduration tuesday, ysc(reverse)) (scatter bond_dollarduration tuesday, yaxis(2) ) ,  legend(order(1 "DollarDuration: Futures" 2  "DollarDuration: Bond")           position(6) cols(2) region(lstyle(none))) ytitle("") ytitle("", axis(2))
		graph export "$fig/dur1.png", replace width(3220)
	tw (scatter futures_dolconvexity tuesday, ysc(reverse)) (scatter bond_dollarconvexity tuesday, yaxis(2) ) ,  legend(order(1 "DollarConvexity: Futures" 2  "DollarConvexity: Bond")           position(6) cols(2) region(lstyle(none))) ytitle("") ytitle("", axis(2))
		graph export "$fig/con1.png", replace width(3220)

	reg futures_dolduration bond_dollarduration
	local b  : display %4.2f _b[bond_dollarduration]
	local se : display %4.2f _se[bond_dollarduration]
	local r2 : display %4.2f e(r2)
	local n  = e(N)
	tw (scatter futures_dolduration bond_dollarduration) (lfit futures_dolduration bond_dollarduration), ytitle("Futures dollar duration") xtitle("Bond dollar duration") legend(off) ///
		note("Slope `b' (s.e. `se'), R{superscript:2} `r2', `n' weeks")
		graph export "$fig/duration_scatter.png", replace width(3220)
	reg futures_dolconvexity bond_dollarconvexity
	local b  : display %4.2f _b[bond_dollarconvexity]
	local se : display %4.2f _se[bond_dollarconvexity]
	local r2 : display %4.2f e(r2)
	local n  = e(N)
	tw (scatter futures_dolconvexity bond_dollarconvexity) (lfit futures_dolconvexity bond_dollarconvexity), ytitle("Futures dollar convexity") xtitle("Bond dollar convexity") legend(off) ///
		note("Slope `b' (s.e. `se'), R{superscript:2} `r2', `n' weeks")
		graph export "$fig/convexity_scatter.png", replace width(3220)
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

**# Bid ask spreads, yield spread of US bonds by type and the on the run notes in 32nds as in Liberty Street Economics

use "$key/bond_bidask.dta", clear
keep if country == "US"
* yield spread, ask minus bid price over duration times mid price, in basis points, the price spread expressed in yield terms
gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
* price spread in 32nds of a point, a point is one percent of par
gen spread32 = (ask_price - bid_price)*32

preserve
	keep if inlist(bondtype, "1", "2", "4")
	collapse (mean) bidask, by(date bondtype)
	tw (scatter bidask date if bondtype=="1", msize(vsmall))(scatter bidask date if bondtype=="2", msize(vsmall))(scatter bidask date if bondtype=="4", msize(vsmall)), ///
		legend(order(1 "Bonds" 2 "Notes" 3 "Bills") pos(6) rows(1)) ytitle("Yield bid ask spread, bp") xtitle("")
		graph export "$fig/bidask_type.png", replace width(3220)
restore

* on the run 2, 5 and 10 year notes, 21 day moving average, ten year on a right axis at twice the scale, the 2020 spike is clipped at the top
keep if bondtype == "2" & inlist(matgroup, 2, 5, 10) & otr_number == 1
collapse (mean) spread32, by(date matgroup)
bysort matgroup (date): gen t = _n
tsset matgroup t
tssmooth ma ma = spread32, window(20 1 0)
sum ma if inlist(matgroup, 2, 5), detail
local cap = ceil(r(p99)/0.25)*0.25
sum ma if matgroup == 10, detail
local cap = max(`cap', ceil(r(p99)/0.5)*0.25)
replace ma = min(ma, cond(matgroup == 10, 2*`cap', `cap'))
keep if inrange(date, td(1jan2020), td(31oct2025))
tw (line ma date if matgroup==2)(line ma date if matgroup==5)(line ma date if matgroup==10, yaxis(2)), ///
	ylabel(0(`=`cap'/4')`cap', axis(1)) ylabel(0(`=`cap'/2')`=2*`cap'', axis(2)) ytitle("32nds of a point", axis(1)) ytitle("32nds of a point", axis(2)) xtitle("") ///
	legend(order(1 "Two year (left axis)" 2 "Five year (left axis)" 3 "Ten year (right axis)") pos(6) rows(1))
	graph export "$fig/bidask_otr.png", replace width(3220)

**# Bid ask spread of CTD bonds against all other bonds held by funds, US only, weighted by borrowing positions
* yield spread, ask minus bid price over duration times mid price, in basis points, from the cleaned Bloomberg quotes

use "$key/bond_bidask.dta", clear
gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
keep date isin bidask
tempfile bidask
save `bidask'

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
merge m:1 date isin using `bidask', keep(match) nogen
collapse (mean) bidask [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/
tw (line bidask date if isctd==1)(line bidask date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Yield bid ask spread, bp") xtitle("") name(ts, replace)

* means and the gap with Newey West standard errors over 20 trading days, the daily spreads are autocorrelated
reshape wide bidask, i(date) j(isctd)
sort date
gen t = _n
tsset t
foreach g in 0 1 {
	newey bidask`g', lag(20)
	local m`g' = _b[_cons]
	local s`g' = _se[_cons]
}
gen gap = bidask1 - bidask0
newey gap, lag(20)

* CTD on the left as in the legend of the time series, one bar plot per group so the colours follow the same order as the lines
clear
set obs 2
gen isctd = _n - 1
gen mean = cond(isctd == 1, `m1', `m0')
gen se = cond(isctd == 1, `s1', `s0')
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
gen x = 1 - isctd
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Yield bid ask spread, bp") legend(off) name(bar, replace)
graph combine ts bar, cols(2)
	graph export "$fig/bidask_ctd.png", replace width(3220)

**# Borrowing repo rate of CTD bonds against all other bonds held by funds as a spread over SOFR, US only, overnight positions, weighted by borrowing positions
* two versions, the full sample and from 2023 when the US basis trade builds up

* SOFR, date in the second column and the rate in percent in the fourth
import delimited "$data/SOFR.csv", varnames(nonames) rowrange(2) clear
keep v2 v4
rename (v2 v4) (sofrdate sofr)
gen date = date(sofrdate, "YMD")
format date %td
destring sofr, replace
keep date sofr
tempfile sofr
save `sofr'

* overnight positions only, their rates are set fresh every day while term positions carry the rate of their start date, the term is the average contractual maturity in days
use "$int/sftds.dta", clear
keep if country == "US" & !missing(borrowing_rate) & borrowing_volume > 0 & borrowing_term <= 1
keep date isin borrowing_volume borrowing_rate
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
merge m:1 date using `sofr', keep(match) nogen
gen spread = (borrowing_rate - sofr)*100 /*basis points*/

* drop the days around FOMC rate changes, the decision day and the three days after, SOFR moves the day after the decision and the reported rates lag
gen fomc = 0
foreach d in 16mar2022 4may2022 15jun2022 27jul2022 21sep2022 2nov2022 14dec2022 1feb2023 22mar2023 3may2023 26jul2023 18sep2024 7nov2024 18dec2024 17sep2025 29oct2025 10dec2025 {
	replace fomc = 1 if inrange(date, td(`d'), td(`d') + 3)
}
drop if fomc == 1

* trim the fund bond day spreads at the first and last percentile within each year, stale and misreported rates in single positions pull the daily averages off
gen year = year(date)
bysort year: egen p1 = pctile(spread), p(1)
bysort year: egen p99 = pctile(spread), p(99)
drop if spread < p1 | spread > p99

collapse (mean) spread [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/
tempfile daily
save `daily'

foreach start in 1jan2021 1jan2023 {
	local suffix = cond("`start'" == "1jan2023", "_2023", "")
	use `daily', clear
	keep if date >= td(`start')

	* time series on the left
	tw (line spread date if isctd==1)(line spread date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Borrowing repo rate minus SOFR, bp") xtitle("") yline(0) name(ts, replace)

	* means and the gap with Newey West standard errors over 20 trading days, the daily spreads are autocorrelated
	reshape wide spread, i(date) j(isctd)
	sort date
	gen t = _n
	tsset t
	foreach g in 0 1 {
		newey spread`g', lag(20)
		local m`g' = _b[_cons]
		local s`g' = _se[_cons]
	}
	gen gap = spread1 - spread0
	newey gap, lag(20)

	* means with 95 percent bands on the right, CTD on the left as in the legend, one bar plot per group so the colours follow the same order as the lines
	clear
	set obs 2
	gen isctd = _n - 1
	gen mean = cond(isctd == 1, `m1', `m0')
	gen se = cond(isctd == 1, `s1', `s0')
	gen lo = mean - 1.96*se
	gen hi = mean + 1.96*se
	gen x = 1 - isctd
	tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Borrowing repo rate minus SOFR, bp") legend(off) name(bar, replace)
	graph combine ts bar, cols(2)
		graph export "$fig/repo_spread_ctd`suffix'.png", replace width(3220)
}

**# Haircut of CTD bonds against all other bonds held by funds, US only, overnight positions, weighted by borrowing positions
* the haircut is the average over the fund's borrowing trades in the bond on the day as reported in the SFTDS, in percent

use "$int/sftds.dta", clear
keep if country == "US" & !missing(borrowing_haircut) & borrowing_volume > 0 & borrowing_term <= 1
keep date isin borrowing_volume borrowing_haircut
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
collapse (mean) haircut = borrowing_haircut [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/

* time series on the left
tw (line haircut date if isctd==1)(line haircut date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Haircut, percent") xtitle("") yline(0) name(ts, replace)

* means and the gap with Newey West standard errors over 20 trading days, the daily haircuts are autocorrelated
reshape wide haircut, i(date) j(isctd)
sort date
gen t = _n
tsset t
foreach g in 0 1 {
	newey haircut`g', lag(20)
	local m`g' = _b[_cons]
	local s`g' = _se[_cons]
}
gen gap = haircut1 - haircut0
newey gap, lag(20)

* means with 95 percent bands on the right, CTD on the left as in the legend, one bar plot per group so the colours follow the same order as the lines
clear
set obs 2
gen isctd = _n - 1
gen mean = cond(isctd == 1, `m1', `m0')
gen se = cond(isctd == 1, `s1', `s0')
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
gen x = 1 - isctd
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Haircut, percent") legend(off) name(bar, replace)
graph combine ts bar, cols(2)
	graph export "$fig/haircut_ctd.png", replace width(3220)

**# Euro area, lending repo rate of CTD bonds against all other bonds as a spread over ESTR, overnight positions, weighted by fund positions
* funds are short the cash bond and lend cash against it, so the lending side carries the trade, a lower rate on the CTD is the cost of its specialness
* German collateral traded far below ESTR in the scarcity period of 2022 and 2023, which shows in both lines

* ESTR, day month year dates
import delimited "$data/ESTR.csv", varnames(1) clear
gen date2 = date(date, "DMY")
drop date
rename date2 date
format date %td
keep date estr
tempfile estr
save `estr'

* overnight lending positions only, the term is the average contractual maturity in days
use "$int/sftds.dta", clear
keep if country != "US" & !missing(lending_rate) & lending_volume > 0 & lending_term <= 1
keep date isin lending_volume lending_rate
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
merge m:1 date using `estr', keep(match) nogen
gen spread = (lending_rate - estr)*100 /*basis points*/

* drop the days around ECB rate changes, the decision Thursday through the Wednesday a week later when the new rate applies and two days beyond
gen ecb = 0
foreach d in 21jul2022 8sep2022 27oct2022 15dec2022 2feb2023 16mar2023 4may2023 15jun2023 27jul2023 14sep2023 6jun2024 12sep2024 17oct2024 12dec2024 30jan2025 6mar2025 17apr2025 5jun2025 {
	replace ecb = 1 if inrange(date, td(`d'), td(`d') + 9)
}
drop if ecb == 1

* trim the fund bond day spreads at the first and last percentile within each year
gen year = year(date)
bysort year: egen p1 = pctile(spread), p(1)
bysort year: egen p99 = pctile(spread), p(99)
drop if spread < p1 | spread > p99

collapse (mean) spread [aw = lending_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/

* time series on the left
tw (line spread date if isctd==1)(line spread date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Lending repo rate minus ESTR, bp") xtitle("") yline(0) name(ts, replace)

* means and the gap with Newey West standard errors over 20 trading days, the daily spreads are autocorrelated
reshape wide spread, i(date) j(isctd)
sort date
gen t = _n
tsset t
foreach g in 0 1 {
	newey spread`g', lag(20)
	local m`g' = _b[_cons]
	local s`g' = _se[_cons]
}
gen gap = spread1 - spread0
newey gap, lag(20)

* means with 95 percent bands on the right, CTD on the left as in the legend, one bar plot per group so the colours follow the same order as the lines
clear
set obs 2
gen isctd = _n - 1
gen mean = cond(isctd == 1, `m1', `m0')
gen se = cond(isctd == 1, `s1', `s0')
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
gen x = 1 - isctd
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Lending repo rate minus ESTR, bp") legend(off) name(bar, replace)
graph combine ts bar, cols(2)
	graph export "$fig/repo_spread_ctd_EA.png", replace width(3220)

**# Euro area, haircut of CTD bonds against all other bonds on the lending side, overnight positions, weighted by fund positions
* funds are short the cash bond and lend cash against it, the haircut is the average over the fund's lending trades in the bond on the day as reported in the SFTDS, in percent

use "$int/sftds.dta", clear
keep if country != "US" & !missing(lending_haircut) & lending_volume > 0 & lending_term <= 1
keep date isin lending_volume lending_haircut
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
collapse (mean) haircut = lending_haircut [aw = lending_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/

* time series on the left
tw (line haircut date if isctd==1)(line haircut date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Haircut on lending positions, percent") xtitle("") yline(0) name(ts, replace)

* means and the gap with Newey West standard errors over 20 trading days, the daily haircuts are autocorrelated
reshape wide haircut, i(date) j(isctd)
sort date
gen t = _n
tsset t
foreach g in 0 1 {
	newey haircut`g', lag(20)
	local m`g' = _b[_cons]
	local s`g' = _se[_cons]
}
gen gap = haircut1 - haircut0
newey gap, lag(20)

* means with 95 percent bands on the right, CTD on the left as in the legend, one bar plot per group so the colours follow the same order as the lines
clear
set obs 2
gen isctd = _n - 1
gen mean = cond(isctd == 1, `m1', `m0')
gen se = cond(isctd == 1, `s1', `s0')
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
gen x = 1 - isctd
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Haircut on lending positions, percent") legend(off) name(bar, replace)
graph combine ts bar, cols(2)
	graph export "$fig/haircut_ctd_EA.png", replace width(3220)
