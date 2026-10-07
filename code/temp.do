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

**# Bid ask spread of CTD bonds against all other bonds, US only, weighted by fund positions
* there are no quotes in the pipeline yet, this expects Data/bidask.csv with columns date (YMD), cusip (8 characters), bid, ask, both in price
* the spread is ask minus bid over the mid price, in basis points

import delimited "$data/bidask.csv", varnames(1) clear
capture drop v1
gen date2 = date(date, "YMD")
drop date
rename date2 date
format date %td
gen cusip8 = substr(cusip, 1, 8)
gen bidask = (ask - bid)/((ask + bid)/2)*10000
keep if !missing(bidask) & bidask >= 0
keep date cusip8 bidask
duplicates drop date cusip8, force
tempfile bidask
save `bidask'

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd cusip8) nogen
merge m:1 date cusip8 using `bidask', keep(match) nogen
collapse (mean) bidask [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/
label define ctd 0 "Not CTD" 1 "CTD"
label values isctd ctd

* the two means over the sample
tabstat bidask, by(isctd) stat(mean n)

* time series on the left, bar chart on the right
tw (line bidask date if isctd==1)(line bidask date if isctd==0), legend(order(1 "CTD" 2 "Not CTD")) ytitle("Bid ask spread, bp of price") xtitle("") name(ts, replace)
graph bar (mean) bidask, over(isctd) ytitle("Bid ask spread, bp of price") name(bar, replace)
graph combine ts bar, cols(2)
