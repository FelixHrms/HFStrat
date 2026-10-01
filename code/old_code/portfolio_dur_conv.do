* ============================================================
* BOND PORTFOLIO
* ============================================================

import delimited "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\sftds_dataframe.csv", clear
count

* convert business_date (string) to a proper Stata daily date called 'date'
gen date = date(business_date, "YMD")
format date %td
drop business_date

rename security_isin isin

preserve
import delimited "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\fund_countries.csv", ///
    varnames(1) clear
keep entity_id fund_country
duplicates drop
tempfile fund_countries
save `fund_countries'
restore

merge m:1 entity_id using `fund_countries', ///
    keep(master match) nogen

merge m:1 isin date using "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\bond_day.dta", ///
    keepusing(duration convexity refprice CUSIP) keep(master match) nogen
count

rename CUSIP cusip
count

keep if bank_indicator == 1 | fund_country == "KY"
count

drop if missing(cusip)


gen country = substr(isin, 1, 2)
keep if inlist(country, "US", "DE")

gen net_pos = borrowing_volume - lending_volume

gen abs_pos = abs(net_pos)
gen dur_contrib = abs_pos * duration
gen cvx_contrib = abs_pos * convexity
collapse (sum) abs_pos dur_contrib cvx_contrib (sum) net_pos, by(date country)
drop if abs(net_pos) < 1e10
gen port_duration  = dur_contrib / abs_pos
gen port_convexity = cvx_contrib / abs_pos


keep date country port_duration port_convexity
reshape wide port_duration port_convexity, i(date) j(country) string

rename port_durationUS us_duration
rename port_convexityUS us_convexity
rename port_durationDE de_duration
rename port_convexityDE de_convexity

save "C:\Users\hermesf\Projects\HF_Strategies\Data\bond_portfolio_dur_conv.dta", replace


twoway line us_duration date, ///
    ytitle("Duration") xtitle("") title("US portfolio duration") ///
    name(us_dur, replace)

twoway line us_convexity date, ///
    ytitle("Convexity") xtitle("") title("US portfolio convexity") ///
    name(us_cvx, replace)

twoway line de_duration date, ///
    ytitle("Duration") xtitle("") title("DE portfolio duration") ///
    name(de_dur, replace)

twoway line de_convexity date, ///
    ytitle("Convexity") xtitle("") title("DE portfolio convexity") ///
    name(de_cvx, replace)
	
	
	
	
* ============================================================
* FUTURES PORTFOLIO
* ============================================================

import delimited "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\emir_dataframe.csv", clear
count

* convert business_date (string) to a proper Stata daily date called 'date'
gen date = date(business_date, "YMD")
format date %td
drop business_date

keep if is_bond_future == 1

gen prefix = lower(substr(futures_contract, 1, 3))
keep if inlist(prefix, "sch", "bob", "bun", "bux")
drop prefix

preserve
use "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\basis_stacked.dta", clear

* normalize contract codes: 4-char codes (e.g. TYH6) → 5-char (e.g. TYH26)
gen contract_fixed = contract
replace contract_fixed = substr(contract, 1, 3) + "2" + substr(contract, 4, 1) ///
    if length(contract) == 4

keep Date contract_fixed cusip
duplicates drop
rename contract_fixed futures_identifier
rename Date date
tempfile basis_unique
save `basis_unique'
restore

merge m:1 futures_identifier date using `basis_unique', ///
    keep(master match) generate(_m_ctd)

*stacked basis file doesn't have values for ALL dates	(5% of observations)
drop if missing(cusip)


* pull duration and convexity for the CTD from bond_day
preserve
use "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\bond_day.dta", clear
keep date CUSIP duration convexity
duplicates drop
gen cusip = substr(CUSIP, 1, 8)
drop CUSIP
drop if missing(cusip)
duplicates drop
tempfile bond_day_short
save `bond_day_short'
restore

merge m:1 cusip date using `bond_day_short', ///
    keep(master match) keepusing(duration convexity) generate(_m_bd)


gen net_pos = long_futures - short_futures
gen abs_pos = abs(net_pos)
gen dur_contrib = abs_pos * duration
gen cvx_contrib = abs_pos * convexity
collapse (sum) abs_pos dur_contrib cvx_contrib (sum) net_pos, by(date)
drop if abs(net_pos) < 1e10
gen port_duration  = dur_contrib / abs_pos
gen port_convexity = cvx_contrib / abs_pos



save "C:\Users\hermesf\Projects\HF_Strategies\Data\de_futures_portfolio_dur_conv.dta", replace


twoway line port_duration date, ///
    ytitle("Duration") xtitle("") title("portfolio duration") ///
    name(us_dur, replace)

twoway line port_convexity date, ///
    ytitle("Convexity") xtitle("") title("portfolio convexity") ///
    name(us_cvx, replace)
	
	

	
************** USD
import delimited "C:\Users\hermesf\Projects\HF_Strategies\Data\OFR_data.csv", clear
count
* convert date (string) to a proper Stata daily date called 'date'
gen date = date(business_date, "DMY")
format date %td
drop business_date
* prefix the six bucket columns with a common stub so reshape can find them
rename (tu fv ty uxy us wn) (pos_TU pos_FV pos_TY pos_UXY pos_US pos_WN)
* reshape wide OFR buckets to long: one row per date x root
reshape long pos_, i(date) j(root) string
rename pos_ net_pos


preserve
use "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\basis_stacked.dta", clear
* normalize contract codes: 4-char codes (e.g. TYH6) → 5-char (e.g. TYH26)
gen contract_fixed = contract
replace contract_fixed = substr(contract, 1, 3) + "2" + substr(contract, 4, 1) ///
    if length(contract) == 4
keep Date contract_fixed cusip root
duplicates drop
rename Date date
tempfile basis_unique
save `basis_unique'
restore

merge m:1 root date using `basis_unique', ///
    keep(master match) generate(_m_ctd)
*stacked basis file doesn't have values for ALL dates	(5% of observations)
drop if missing(cusip)



preserve
use "C:\Users\hermesf\Projects\HF_Strategies\key dataframe\bond_day.dta", clear
keep date CUSIP duration convexity
duplicates drop
gen cusip = substr(CUSIP, 1, 8)
drop CUSIP
drop if missing(cusip)
duplicates drop
tempfile bond_day_short
save `bond_day_short'
restore


merge m:1 cusip date using `bond_day_short', ///
    keep(master match) keepusing(duration convexity) generate(_m_bd)

gen abs_pos = abs(net_pos)
gen dur_contrib = abs_pos * duration
gen cvx_contrib = abs_pos * convexity
collapse (sum) abs_pos dur_contrib cvx_contrib, by(date)

drop if abs_pos < 1e10

gen port_duration = dur_contrib / abs_pos
gen port_convexity = cvx_contrib / abs_pos

drop if port_duration == 0


save "C:\Users\hermesf\Projects\HF_Strategies\Data\us_futures_portfolio_dur_conv.dta", replace


twoway line port_duration date, ///
    ytitle("Duration") xtitle("") title("portfolio duration") ///
    name(us_dur, replace)
twoway line port_convexity date, ///
    ytitle("Convexity") xtitle("") title("portfolio convexity") ///
    name(us_cvx, replace)
	
	
	
	
	
* ============================================================
* SCATTERPLOTS: BOND vs FUTURES DURATION & CONVEXITY
* ============================================================

local path "C:\Users\hermesf\Projects\HF_Strategies\Data"

* --- merge bond portfolio with both futures portfolios, by date ---
use "`path'\bond_portfolio_dur_conv.dta", clear

merge 1:1 date using "`path'\de_futures_portfolio_dur_conv.dta", ///
    keepusing(port_duration port_convexity) keep(match) nogen
rename port_duration  de_fut_duration
rename port_convexity de_fut_convexity

merge 1:1 date using "`path'\us_futures_portfolio_dur_conv.dta", ///
    keepusing(port_duration port_convexity) keep(match) nogen
rename port_duration  us_fut_duration
rename port_convexity us_fut_convexity

* --- DE: bond vs futures ---
twoway scatter de_duration de_fut_duration, ///
    ytitle("Bond duration") xtitle("Futures duration") ///
    title("Germany: duration") name(de_dur_sc, replace)

twoway scatter de_convexity de_fut_convexity, ///
    ytitle("Bond convexity") xtitle("Futures convexity") ///
    title("Germany: convexity") name(de_cvx_sc, replace)

* --- US: bond vs futures ---
twoway scatter us_duration us_fut_duration, ///
    ytitle("Bond duration") xtitle("Futures duration") ///
    title("US: duration") name(us_dur_sc, replace)

twoway scatter us_convexity us_fut_convexity, ///
    ytitle("Bond convexity") xtitle("Futures convexity") ///
    title("US: convexity") name(us_cvx_sc, replace)
	
	
	
