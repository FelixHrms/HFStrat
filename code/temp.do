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

**# Borrowing repo rate of CTD bonds against all other bonds as a spread over SOFR, US only, weighted by fund positions

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

use "$int/sftds.dta", clear
keep if country == "US" & !missing(borrowing_rate) & borrowing_volume > 0
keep date isin borrowing_volume borrowing_rate
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
merge m:1 date using `sofr', keep(match) nogen
gen spread = (borrowing_rate - sofr)*100 /*basis points*/
collapse (mean) spread [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd

* the two means over the sample
tabstat spread, by(isctd) stat(mean n)

* time series on the left, bar chart on the right
tw (line spread date if isctd==1)(line spread date if isctd==0), legend(order(1 "CTD" 2 "Not CTD")) ytitle("Borrowing repo rate minus SOFR, bp") xtitle("") yline(0) name(ts, replace)
graph bar (mean) spread, over(isctd) ytitle("Borrowing repo rate minus SOFR, bp") name(bar, replace)
graph combine ts bar, cols(2)

**# Yield volatility of CTD bonds against all other bonds, US only, weighted by fund positions
* realized volatility per bond, standard deviation of daily yield changes in basis points over the past four weeks

capture which rangestat
if _rc ssc install rangestat

use date isin yield_check using "$key/bond_day.dta", clear
keep if substr(isin, 1, 2) == "US" & !missing(yield_check)
bysort isin (date): gen dy = (yield_check - yield_check[_n-1])*100 if date - date[_n-1] <= 5 /*skip gaps*/
rangestat (sd) dy (count) dy, interval(date -28 0) by(isin)
keep if dy_count >= 15
rename dy_sd vol
keep date isin vol
tempfile vol
save `vol'

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd) nogen
merge m:1 date isin using `vol', keep(match) nogen
collapse (mean) vol [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd

* the two means over the sample
tabstat vol, by(isctd) stat(mean n)

* time series on the left, bar chart on the right
tw (line vol date if isctd==1)(line vol date if isctd==0), legend(order(1 "CTD" 2 "Not CTD")) ytitle("Yield volatility, bp per day") xtitle("") name(ts, replace)
graph bar (mean) vol, over(isctd) ytitle("Yield volatility, bp per day") name(bar, replace)
graph combine ts bar, cols(2)

**# Position weighted average duration of CTD and other bonds, US only, same borrowing positions as above

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd duration) nogen
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd
tabstat duration [aw = borrowing_volume], by(isctd) stat(mean n)

**# Duration adjusted versions, the non CTD line is reweighted to the maturity mix of the CTD positions
* duration buckets under 3, 3 to 6, 6 to 9, 9 to 15 and above 15 years
* within a bucket and day both lines are position weighted means, the buckets are then averaged with the CTD position shares of that day

* repo spread over SOFR
use "$int/sftds.dta", clear
keep if country == "US" & !missing(borrowing_rate) & borrowing_volume > 0
keep date isin borrowing_volume borrowing_rate
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd duration) nogen
merge m:1 date using `sofr', keep(match) nogen
gen spread = (borrowing_rate - sofr)*100 /*basis points*/
drop if missing(duration)
gen bucket = cond(duration < 3, 1, cond(duration < 6, 2, cond(duration < 9, 3, cond(duration < 15, 4, 5))))
gen w = borrowing_volume
collapse (mean) spread (rawsum) w [aw = borrowing_volume], by(date isctd bucket)
bysort date isctd: egen wtot = total(w)
gen share = w/wtot
gen tmp = share if isctd == 1
bysort date bucket: egen share_ctd = max(tmp) /*CTD share of the bucket on the day, applied to both groups*/
drop if missing(share_ctd)
collapse (mean) spread [aw = share_ctd], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd
tabstat spread, by(isctd) stat(mean n)
tw (line spread date if isctd==1)(line spread date if isctd==0), legend(order(1 "CTD" 2 "Not CTD")) ytitle("Borrowing repo rate minus SOFR, bp") xtitle("") yline(0) name(ts, replace)
graph bar (mean) spread, over(isctd) ytitle("Borrowing repo rate minus SOFR, bp") name(bar, replace)
graph combine ts bar, cols(2)

* yield volatility
use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd duration) nogen
merge m:1 date isin using `vol', keep(match) nogen
drop if missing(duration)
gen bucket = cond(duration < 3, 1, cond(duration < 6, 2, cond(duration < 9, 3, cond(duration < 15, 4, 5))))
gen w = borrowing_volume
collapse (mean) vol (rawsum) w [aw = borrowing_volume], by(date isctd bucket)
bysort date isctd: egen wtot = total(w)
gen share = w/wtot
gen tmp = share if isctd == 1
bysort date bucket: egen share_ctd = max(tmp)
drop if missing(share_ctd)
collapse (mean) vol [aw = share_ctd], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd
tabstat vol, by(isctd) stat(mean n)
tw (line vol date if isctd==1)(line vol date if isctd==0), legend(order(1 "CTD" 2 "Not CTD")) ytitle("Yield volatility, bp per day") xtitle("") name(ts, replace)
graph bar (mean) vol, over(isctd) ytitle("Yield volatility, bp per day") name(bar, replace)
graph combine ts bar, cols(2)

**# Bid ask spread of CTD bonds against all other bonds, US only, weighted by fund positions
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

clear
set obs 2
gen isctd = _n - 1
gen mean = cond(isctd == 1, `m1', `m0')
gen se = cond(isctd == 1, `s1', `s0')
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
* CTD on the left as in the legend of the time series, one bar plot per group so the colours follow the same order as the lines
gen x = 1 - isctd
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Yield bid ask spread, bp") legend(off) name(bar, replace)
graph combine ts bar, cols(2)
