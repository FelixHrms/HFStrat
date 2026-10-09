clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Do hedge funds hold bills, and what is the share of the most held bond

use "$int/sftds.dta", clear
merge m:1 isin using "$int/bond_info.dta", keep(1 3) keepusing(bondtype) nogen
gen bill = inlist(bondtype, "4", "GTC", "LET", "FTB", "BOT")
gen newcountry = cond(country == "US", "US", "EU")

* net positions in bills versus all other bonds, same set up as the CTD chart
preserve
	collapse (sum) net, by(date newcountry bill)
	tw (scatter net date if bill==1)(scatter net date if bill==0), by(newcountry) legend(order(1 "Bills" 2 "Not bills")) yline(0)
restore

* share of the most held bond on one day, net position summed across funds
keep if date == td(15jan2025)
collapse (sum) net (count) nfunds = net (first) bondtype country, by(newcountry isin)
gen absnet = abs(net)

* across the whole region
bysort newcountry: egen total = sum(absnet)
gen weight = absnet / total
gsort newcountry -weight
by newcountry: gen rank = _n
list newcountry isin country bondtype net weight nfunds if rank <= 10, noobs sepby(newcountry)

* one example bond per bill code
use "$int/bond_info.dta", clear
keep if inlist(bondtype, "4", "GTC", "LET", "FTB", "BOT")
gen ormat = (maturitydate - issuedate) / 365
bysort bondtype (isin): keep if _n == 1
list bondtype country isin issuedate maturitydate ormat couponrate, noobs

**# Euro area, bid ask spread of CTD bonds against all other bonds, weighted by the funds' lending positions
* yield spread, ask minus bid price over duration times mid price, in basis points, from the cleaned Bloomberg quotes
* funds are short the cash bond and lend cash against it, so the lending positions are the ones that hold the bonds of the trade

use "$key/bond_bidask.dta", clear
keep if duration >= 1 /*under a year the tick size rather than liquidity sets the yield spread*/
gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
keep date isin bidask
tempfile bidask
save `bidask'

use "$int/sftds.dta", clear
keep if country != "US" & lending_volume > 0
keep date isin lending_volume
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
merge m:1 date isin using `bidask', keep(match) nogen

* diagnostics, the position weighted spread by bond type and country among the non CTD positions, and the bonds behind the ten worst non CTD days
preserve
	keep if isctd == 0
	merge m:1 isin using "$int/bond_info.dta", keep(match) keepusing(bondtype country) nogen
	tabstat bidask [aw = lending_volume], by(bondtype) stat(mean p50 p95 n) col(stat)
	tabstat bidask [aw = lending_volume], by(country) stat(mean p50 p95 n) col(stat)
	bysort date: egen voltot = total(lending_volume)
	gen contrib = bidask*lending_volume/voltot /*contribution of the position to the day's weighted mean*/
	bysort date: egen daymean = total(contrib)
	gsort -daymean -contrib
	egen dayrank = group(-daymean)
	bysort dayrank (contrib): gen posrank = _N - _n + 1
	format daymean contrib bidask %8.1f
	list date daymean isin bondtype country bidask lending_volume contrib if dayrank <= 10 & posrank <= 3, noobs sepby(date)
restore
collapse (mean) bidask [aw = lending_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd

* the two means over the sample
tabstat bidask, by(isctd) stat(mean sd n)

* time series on the left, means with 95 percent confidence bands on the right
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
