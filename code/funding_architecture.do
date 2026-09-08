clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"
global fig "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Figures" /*figures for the slides, the Figures folder of the repository*/
global tab "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Tables" /*table fragments for the slides, the Tables folder of the repository*/
capture mkdir "$fig"
capture mkdir "$tab"

cap log close
log using "$key\\funding_architecture.log", replace text

**# The funding architecture, repo terms by fund dealer pair and relationship stability
* descriptives for the funding architecture section, one table with the terms
* and the relationship measures and one figure with the dispersion of rates
* across the dealers of the same fund, inputs from dealer_fragility_data.ipynb,
* the cleaning of the two funds is repeated from dealer_fragility_qe.do

local bp = 100 /*repo_rate is in percent, spreads are reported in basis points*/
local min_other = 3 /*minimum number of trades by others on a bond day for the benchmark*/
local week = 7 /*tenor up to this many days counts as short*/
local gap_max = 100 /*gaps above this many basis points are left out of the histogram*/

**# Step 1: rate spread to the bond day benchmark, leaving the fund out
* benchmark = average rate over all other trades on the same bond and day,
* rebuilt from the averages and the trade counts, spread = pair rate minus
* benchmark, averaged over the pair's trades of the day

import delimited "$key\\bond_day_rate.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
gen ratesum_all = market_rate*market_trades
keep date security_isin ratesum_all market_trades
tempfile market
save `market'

import delimited "$key\\fund_dealer_bond_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
* two funds report borrowing and lending the wrong way round at the beginning
* of the sample, swap the two sides for them before 24 April 2021 as in DT.do
gen flip = inlist(fund_id, "P5XEQYFJP74DYQX88M80", "O1XNTICYRCAHEAMEQI31") & date < td(24apr2021)
foreach s in volume rate trades {
	gen tmp = borrowing_`s'
	replace borrowing_`s' = lending_`s' if flip
	replace lending_`s' = tmp if flip
	drop tmp
}
drop flip
foreach v in borrowing_volume lending_volume borrowing_trades lending_trades {
	replace `v' = 0 if missing(`v')
}
gen ratesum_pair = cond(borrowing_trades > 0, borrowing_rate*borrowing_trades, 0) + cond(lending_trades > 0, lending_rate*lending_trades, 0)
gen trades_pair = borrowing_trades + lending_trades
bysort fund_id security_isin date: egen ratesum_fund = total(ratesum_pair) /*the fund's own trades, all its dealers and both sides*/
bysort fund_id security_isin date: egen trades_fund = total(trades_pair)
merge m:1 date security_isin using `market', keep(master match) nogen
gen trades_other = market_trades - trades_fund
gen bench = (ratesum_all - ratesum_fund)/trades_other if trades_other >= `min_other'
gen spread_borrowing = (borrowing_rate - bench)*`bp'
gen spread_lending = (lending_rate - bench)*`bp'
label var spread_borrowing "Rate minus bond day benchmark, fund borrows cash, bp"
label var spread_lending "Rate minus bond day benchmark, fund lends cash, bp"

* for the log only, the gap across dealers on the very same bond, no benchmark needed
foreach l in borrowing lending {
	bysort fund_id security_isin date: egen max_`l' = max(`l'_rate)
	bysort fund_id security_isin date: egen min_`l' = min(`l'_rate)
	bysort fund_id security_isin date: egen n_`l' = count(`l'_rate)
	gen gap_samebond_`l' = (max_`l' - min_`l')*`bp' if n_`l' >= 2
}
sum gap_samebond_borrowing gap_samebond_lending, detail
drop max_* min_* n_* gap_samebond_*

* average over the pair's trades of the day, bonds without a benchmark drop out
foreach l in borrowing lending {
	gen w_`l' = `l'_trades*!missing(spread_`l')
	gen spreadw_`l' = spread_`l'*w_`l'
}
collapse (sum) spreadw_borrowing w_borrowing spreadw_lending w_lending, by(fund_id dealer_id date)
foreach l in borrowing lending {
	gen spread_`l' = spreadw_`l'/w_`l' if w_`l' > 0
}
keep fund_id dealer_id date spread_borrowing spread_lending
tempfile spreads
save `spreads'

**# Step 2: the pair day panel with haircut, tenor and the spreads

import delimited "$key\\fund_dealer_day.csv", varnames(1) clear
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
drop flip
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
merge 1:1 fund_id dealer_id date using `spreads', keep(master match) nogen
tempfile panel
save `panel'

* one observation per pair, day and side of the fund
preserve
	keep fund_id dealer_id date borrowing_volume borrowing_haircut borrowing_tenor spread_borrowing
	rename (borrowing_volume borrowing_haircut borrowing_tenor spread_borrowing) (volume haircut tenor spread)
	gen side = 1
	tempfile borrowing
	save `borrowing'
restore
keep fund_id dealer_id date lending_volume lending_haircut lending_tenor spread_lending
rename (lending_volume lending_haircut lending_tenor spread_lending) (volume haircut tenor spread)
gen side = 2
append using `borrowing'
label define side 1 "fund borrows cash" 2 "fund lends cash"
label values side side
drop if volume <= 0
gen spread_b = spread if side == 1
gen spread_l = spread if side == 2
gen zero_haircut = haircut <= 0 if !missing(haircut)
gen short_tenor = tenor <= `week' if !missing(tenor)
tempfile terms
save `terms'

**# Step 3: relationship measures, one observation per fund and quarter
* dealers per fund, share of the largest dealer and the share of the fund's
* volume with dealers it already used four quarters earlier

use `panel', clear
gen gross = borrowing_volume + lending_volume
gen quarter = qofd(date)
format quarter %tq
collapse (sum) gross, by(fund_id dealer_id quarter)
drop if gross <= 0
gen quarter_lag = quarter - 4
preserve
	keep fund_id dealer_id quarter
	rename quarter quarter_lag
	gen active_lag = 1
	tempfile lagpairs
	save `lagpairs'
restore
preserve
	keep fund_id quarter
	duplicates drop
	rename quarter quarter_lag
	gen fund_active_lag = 1
	tempfile lagfunds
	save `lagfunds'
restore
merge 1:1 fund_id dealer_id quarter_lag using `lagpairs', keep(master match) nogen
merge m:1 fund_id quarter_lag using `lagfunds', keep(master match) nogen
replace active_lag = 0 if missing(active_lag)
gen gross_old = gross*active_lag
collapse (sum) gross gross_old (max) max_gross = gross (count) n_dealers = gross (first) fund_active_lag, by(fund_id quarter)
gen main_share = 100*max_gross/gross
gen persist = 100*gross_old/gross if fund_active_lag == 1 /*only funds that were active a year earlier*/
label var n_dealers "Dealers per fund and quarter"
label var main_share "Share of the largest dealer in the fund's volume, percent"
label var persist "Share of the fund's volume with dealers used four quarters earlier, percent"
tempfile relationships
save `relationships'

**# Step 4: the table, mean, volume weighted mean, percentiles and N per row

capture program drop tabrow
program define tabrow
	syntax varname, label(string) wvar(varname) [indicator]
	qui sum `varlist', detail
	local mean = r(mean)
	local p10 = r(p10)
	local p50 = r(p50)
	local p90 = r(p90)
	local n = r(N)
	local wmean = .
	capture qui sum `varlist' [aw=`wvar'] /*errors when the row has no observations*/
	if _rc == 0 local wmean = r(mean)
	if "`indicator'" == "" {
		file write tab "`label' & " %6.2f (`mean') " & " %6.2f (`wmean') " & " %6.2f (`p10') " & " %6.2f (`p50') " & " %6.2f (`p90') " & " %9.0fc (`n') " \\" _n
	}
	else {
		file write tab "`label' & " %6.1f (100*`mean') " & " %6.1f (100*`wmean') " & & & & " %9.0fc (`n') " \\" _n
	}
end

capture file close tab
file open tab using "$tab\\funding_terms.tex", write replace
file write tab "\begin{tabular}{lrrrrrr}" _n
file write tab "\toprule" _n
file write tab " & Mean & Weighted mean & p10 & p50 & p90 & N \\" _n
file write tab "\midrule" _n
file write tab "\multicolumn{7}{l}{\textit{Panel A. Repo terms, one observation per fund, dealer, day and side}} \\" _n

use `terms', clear
tabrow spread_b, label("Rate spread to the bond day benchmark, fund borrows cash (bp)") wvar(volume)
tabrow spread_l, label("Rate spread to the bond day benchmark, fund lends cash (bp)") wvar(volume)
tabrow haircut, label("Haircut") wvar(volume)
tabrow zero_haircut, label("Zero or negative haircut, share in percent") wvar(volume) indicator
tabrow tenor, label("Tenor (days)") wvar(volume)
tabrow short_tenor, label("Tenor up to one week, share in percent") wvar(volume) indicator

file write tab "\midrule" _n
file write tab "\multicolumn{7}{l}{\textit{Panel B. Relationships, one observation per fund and quarter}} \\" _n

use `relationships', clear
tabrow n_dealers, label("Dealers per fund") wvar(gross)
tabrow main_share, label("Share of the largest dealer (percent)") wvar(gross)
tabrow persist, label("Share of volume with dealers used a year earlier (percent)") wvar(gross)

file write tab "\bottomrule" _n
file write tab "\end{tabular}" _n
file close tab
type "$tab\\funding_terms.tex"

**# Step 5: the figure, dispersion of the spread across the dealers of the same fund
* for each fund, day and side with at least two dealers, the highest minus the
* lowest spread, a fund that faces the same terms everywhere sits at zero

use `terms', clear
keep if !missing(spread)
bysort fund_id date side: egen max_spread = max(spread)
bysort fund_id date side: egen min_spread = min(spread)
bysort fund_id date side: gen n_dealers = _N
keep if n_dealers >= 2
gen gap = max_spread - min_spread
keep fund_id date side gap
duplicates drop
sum gap, detail
count if gap > `gap_max'
histogram gap if gap <= `gap_max', fraction
graph export "$fig\\rate_gap_within_fund.png", replace width(3220)

log close
