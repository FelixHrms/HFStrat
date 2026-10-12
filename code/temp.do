clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Current age of CTD bonds against all other bonds held by funds, US only, weighted by borrowing positions
* age is the date minus the issue date in years, for tapped lines it counts from the first issuance
* residual maturity is the mirror image, maturity date minus date, which equals original maturity minus age

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd issuedate) nogen
gen age = (date - issuedate)/365
count if missing(age)
collapse (mean) age [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/

* time series on the left
tw (line age date if isctd==1)(line age date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Age since issuance, years") xtitle("") name(ts, replace)

* means and the gap with Newey West standard errors over 20 trading days, the daily series are autocorrelated
reshape wide age, i(date) j(isctd)
sort date
gen t = _n
tsset t
foreach g in 0 1 {
	newey age`g', lag(20)
	local m`g' = _b[_cons]
	local s`g' = _se[_cons]
}
gen gap = age1 - age0
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
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Age since issuance, years") legend(off) name(bar, replace)
graph combine ts bar, cols(2) name(us, replace)

**# Euro area, lending side, weighted by the funds' lending positions
* funds are short the cash bond and lend cash against it, so the lending side carries the trade
* Bunds and BTPs are tapped for months after the first auction, so age counts from the first issuance of the line

use "$int/sftds.dta", clear
keep if country != "US" & lending_volume > 0
keep date isin lending_volume
merge m:1 date isin using "$int/sftds_agg.dta", keep(match) keepusing(isctd issuedate) nogen
gen age = (date - issuedate)/365
count if missing(age)
collapse (mean) age [aw = lending_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/

* time series on the left
tw (line age date if isctd==1)(line age date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Age since issuance, years") xtitle("") name(ts, replace)

* means and the gap with Newey West standard errors over 20 trading days, the daily series are autocorrelated
reshape wide age, i(date) j(isctd)
sort date
gen t = _n
tsset t
foreach g in 0 1 {
	newey age`g', lag(20)
	local m`g' = _b[_cons]
	local s`g' = _se[_cons]
}
gen gap = age1 - age0
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
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Age since issuance, years") legend(off) name(bar, replace)
graph combine ts bar, cols(2) name(ea, replace)
