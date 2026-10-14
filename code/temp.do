clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Does the carry survive the funding cost, implied repo of the US futures against the repo spread hedge funds pay
* a long basis position earns the implied repo rate of the futures and pays the repo rate on the bond, so the trade carries when the implied repo exceeds the funding rate
* implied repo from Bloomberg for the front contract of each root, in percent, kept only at least 45 days before the last delivery day since the annualized rate blows up close to delivery
* two benchmarks, spot SOFR and the average SOFR realized from the date to the last delivery day, since the implied repo embeds the expected path of overnight rates
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

* cumulative SOFR on calendar days, the overnight rate applies over weekends and holidays, for the realized average to delivery
preserve
	tsset date
	tsfill
	replace sofr = sofr[_n-1] if missing(sofr)
	gen cum = sum(sofr)
	keep date cum
	tempfile cum
	save `cum'
restore

* implied repo by contract root with the delivery month from the ticker, root letters, one month code and one or two year digits, the last delivery day is the last day of the month
use "$key/basis_stacked.dta", clear
keep if country_future == "US"
keep date contract root implied_repo net_basis
drop if missing(implied_repo)
gen mcode = ustrregexs(1) if ustrregexm(contract, "^[A-Z]+([HMUZ])[0-9]{1,2}$")
gen ydig = ustrregexs(1) if ustrregexm(contract, "^[A-Z]+[HMUZ]([0-9]{1,2})$")
gen dmonth = cond(mcode == "H", 3, cond(mcode == "M", 6, cond(mcode == "U", 9, 12)))
gen dyear = cond(strlen(ydig) == 2, 2000 + real(ydig), 2020 + real(ydig))
gen lastdelivery = dofm(mofd(mdy(dmonth, 1, dyear)) + 1) - 1
format lastdelivery %td
gen todelivery = lastdelivery - date
drop if missing(todelivery)

* spot SOFR and the SOFR realized to delivery
merge m:1 date using `sofr', keep(match) nogen
merge m:1 date using `cum', keep(match) nogen
rename cum cum0
rename date date0
rename lastdelivery date
merge m:1 date using `cum', keep(1 3) nogen
rename cum cum1
rename date lastdelivery
rename date0 date
gen sofr_real = (cum1 - cum0)/todelivery /*missing when delivery lies beyond the SOFR series*/
gen irr = (implied_repo - sofr)*100 /*basis points*/
gen irr_real = (implied_repo - sofr_real)*100

* the implied repo is annualized, so a few 32nds of net basis over a few days become hundreds of basis points, the table shows it by days to delivery
gen dbin = cond(todelivery < 30, 1, cond(todelivery < 45, 2, cond(todelivery < 60, 3, cond(todelivery < 90, 4, 5))))
label define dbinlab 1 "under 30 days" 2 "30 to 45" 3 "45 to 60" 4 "60 to 90" 5 "90 and more"
label values dbin dbinlab
table dbin root, stat(median irr) stat(count irr) nformat(%6.0f)
keep if todelivery >= 45

* check one, the level by year and root under both benchmarks
gen year = year(date)
table year root, stat(median irr) nformat(%6.0f)
table year root, stat(median irr_real) nformat(%6.0f)

* check two, the implied repo against the net basis of the same field set, net basis in 32nds annualized over the days to delivery on a price near par
* if the field is what we think, the annualized net basis and the shortfall of the implied repo move together
gen nb_bp = net_basis/32*360/todelivery*100 /*32nds of a point, as an annualized rate in basis points on a price of 100*/
table year root, stat(median nb_bp) nformat(%6.0f)
corr irr nb_bp
keep date root irr irr_real
reshape wide irr irr_real, i(date) j(root) string
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

* time series, the six implied repo spreads and the funding spread, once against spot SOFR and once against the SOFR realized to delivery
foreach b in spot real {
	local sfx = cond("`b'" == "real", "_real", "")
	local lab = cond("`b'" == "real", "SOFR realized to delivery", "spot SOFR")
	tw (line irr`sfx'TU date, lw(thin))(line irr`sfx'FV date, lw(thin))(line irr`sfx'TY date, lw(thin))(line irr`sfx'UXY date, lw(thin))(line irr`sfx'US date, lw(thin))(line irr`sfx'WN date, lw(thin)) ///
		(line spread date, lc(black) lw(medthick)), ///
		legend(order(1 "TU" 2 "FV" 3 "TY" 4 "UXY" 5 "US" 6 "WN" 7 "Repo spread paid by funds") pos(6) rows(2) size(small) symxsize(6)) ///
		ytitle("Rate minus `lab', bp") xtitle("") yline(0) name(ts_`b', replace)
}

* net carry per contract against the realized benchmark, implied repo minus the funding rate, means with Newey West standard errors over 20 trading days
local k = 0
foreach r in TU FV TY UXY US WN {
	local ++k
	gen carry`r' = irr_real`r' - spread
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
graph combine ts_real bar, cols(2) name(real, replace)
graph display ts_spot
