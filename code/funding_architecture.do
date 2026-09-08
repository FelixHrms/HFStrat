clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"
global fig "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Figures"
capture mkdir "$fig"

cap log close
log using "$key\\funding_architecture.log", replace text

**# Repo terms by fund dealer pair and relationship stability, descriptives for the funding architecture section

**# Step 1: rate spread, pair rate minus the average over all other trades on the same bond and day, in basis points

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

**# Step 3: relationships per fund and quarter, dealers, share of the largest dealer, share of volume with dealers used a year earlier

gen gross = borrowing_volume + lending_volume
gen quarter = qofd(date)
collapse (sum) gross, by(fund_id dealer_id quarter)
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
graph export "$fig\\rate_gap_within_fund.png", replace width(3220)

log close
