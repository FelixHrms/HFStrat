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

**# Yield bid ask spread of US bonds over time by bond type, average across bonds
* (ask price minus bid price) over (modified duration times mid price), in basis points, duration from the bond day panel

import delimited "$key/bond_bidask.csv", varnames(1) clear
gen date2 = date(date, "YMD")
drop date
rename date2 date
format date %td
merge m:1 isin using "$int/bond_info.dta", keep(match) keepusing(bondtype country maturitydate) nogen
keep if country == "US" & inlist(bondtype, "1", "2", "4")
* Bloomberg quotes bills as discount rates in the price fields, turn them into prices
foreach s in bid ask {
	replace `s'_price = 100*(1 - `s'_price/100*(maturitydate - date)/360) if bondtype == "4"
}
merge 1:1 date isin using "$key/bond_day.dta", keep(match) keepusing(duration) nogen
gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
drop if missing(bidask)
* cleaning, bonds close to maturity blow up the formula through the duration, crossed quotes and the top percent of spreads are quote errors
drop if duration < 0.25
drop if bidask < 0
bysort bondtype: egen p99 = pctile(bidask), p(99)
drop if bidask > p99
collapse (mean) bidask, by(date bondtype)
tw (scatter bidask date if bondtype=="1", msize(vsmall))(scatter bidask date if bondtype=="2", msize(vsmall))(scatter bidask date if bondtype=="4", msize(vsmall)), legend(order(1 "Type 1" 2 "Type 2" 3 "Type 4")) ytitle("Yield bid ask spread, bp") xtitle("")

**# Bid ask spread of the on the run 2, 5 and 10 year notes in 32nds of a point, the Liberty Street Economics set up
* a point is one percent of par, the spread is ask price minus bid price times 32

import delimited "$key/bond_bidask.csv", varnames(1) clear
gen date2 = date(date, "YMD")
drop date
rename date2 date
format date %td
merge 1:1 date isin using "$key/bond_day.dta", keep(match) keepusing(bondtype matgroup otr_number) nogen
keep if bondtype == "2" & inlist(matgroup, 2, 5, 10) & otr_number == 1
gen spread32 = (ask_price - bid_price)*32
drop if missing(spread32) | spread32 < 0
* five day moving average over trading days, two and five year on the left axis, ten year on the right axis at twice the scale as in the post
bysort matgroup (date): gen t = _n
tsset matgroup t
tssmooth ma ma5 = spread32, window(4 1 0)
tw (line ma5 date if matgroup==2)(line ma5 date if matgroup==5)(line ma5 date if matgroup==10, yaxis(2)), ///
	ylabel(0(0.125)0.5, axis(1)) ylabel(0(0.25)1, axis(2)) ytitle("32nds of a point", axis(1)) ytitle("32nds of a point", axis(2)) xtitle("") ///
	legend(order(1 "Two year (left axis)" 2 "Five year (left axis)" 3 "Ten year (right axis)"))
