clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Does the carry survive the funding cost, implied repo of the US futures against the repo spread hedge funds pay, both over SOFR
* a long basis position earns the implied repo rate of the futures and pays the repo rate on the bond, so the trade carries when the implied repo exceeds the funding rate
* implied repo from Bloomberg for the front contract of each root, in percent, trimmed at the first and last percentile within root and year since it swings in the delivery month
* the funding spread as in the repo chart, overnight borrowing positions weighted by volume, FOMC days dropped, position level spreads trimmed within year

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

* implied repo over SOFR by contract root, one column per root
use "$key/basis_stacked.dta", clear
keep if country_future == "US"
keep date root implied_repo
merge m:1 date using `sofr', keep(match) nogen
gen irr = (implied_repo - sofr)*100 /*basis points*/
drop if missing(irr)
gen year = year(date)
bysort root year: egen p1 = pctile(irr), p(1)
bysort root year: egen p99 = pctile(irr), p(99)
drop if irr < p1 | irr > p99
keep date root irr
reshape wide irr, i(date) j(root) string
tempfile irr
save `irr'

* the repo spread funds pay, overnight borrowing positions
use "$int/sftds.dta", clear
keep if country == "US" & !missing(borrowing_rate) & borrowing_volume > 0 & borrowing_term <= 1
keep date isin borrowing_volume borrowing_rate
merge m:1 date using `sofr', keep(match) nogen
gen spread = (borrowing_rate - sofr)*100
gen fomc = 0
foreach d in 16mar2022 4may2022 15jun2022 27jul2022 21sep2022 2nov2022 14dec2022 1feb2023 22mar2023 3may2023 26jul2023 18sep2024 7nov2024 18dec2024 17sep2025 29oct2025 10dec2025 {
	replace fomc = 1 if inrange(date, td(`d'), td(`d') + 3)
}
drop if fomc == 1
gen year = year(date)
bysort year: egen p1 = pctile(spread), p(1)
bysort year: egen p99 = pctile(spread), p(99)
drop if spread < p1 | spread > p99
collapse (mean) spread [aw = borrowing_volume], by(date)
merge 1:1 date using `irr', keep(match) nogen

* time series on the left, the six implied repo spreads and the funding spread
tw (line irrTU date, lw(thin))(line irrFV date, lw(thin))(line irrTY date, lw(thin))(line irrUXY date, lw(thin))(line irrUS date, lw(thin))(line irrWN date, lw(thin)) ///
	(line spread date, lc(black) lw(medthick)), ///
	legend(order(1 "TU" 2 "FV" 3 "TY" 4 "UXY" 5 "US" 6 "WN" 7 "Repo spread paid by funds") pos(6) rows(2) size(small) symxsize(6)) ///
	ytitle("Rate minus SOFR, bp") xtitle("") yline(0) name(ts, replace)

* net carry per contract, implied repo minus the funding rate, means with Newey West standard errors over 20 trading days
local k = 0
foreach r in TU FV TY UXY US WN {
	local ++k
	gen carry`r' = irr`r' - spread
	preserve
		keep if !missing(carry`r')
		sort date
		gen long t = _n
		tsset t
		newey carry`r', lag(20)
		local m`k' = _b[_cons]
		local s`k' = _se[_cons]
	restore
}
clear
set obs 6
gen x = _n
gen mean = .
gen se = .
forvalues k = 1/6 {
	replace mean = `m`k'' if x == `k'
	replace se = `s`k'' if x == `k'
}
gen lo = mean - 1.96*se
gen hi = mean + 1.96*se
tw (bar mean x, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(1 "TU" 2 "FV" 3 "TY" 4 "UXY" 5 "US" 6 "WN") xtitle("") ///
	ytitle("Implied repo minus funding rate, bp") yline(0) legend(off) name(bar, replace)
graph combine ts bar, cols(2)
