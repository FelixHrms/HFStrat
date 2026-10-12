clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Bid ask spread, repo spread and haircut along the original maturity of the bond, US only, the continuous version of age at issuance
* original maturity is the maturity date minus the issue date in years, computed here from the two dates and never from the SAS maturity groups

use "$int/sftds_agg.dta", clear
keep if country == "US"
gen ormat = (maturitydate - issuedate)/365
count if missing(ormat)
sum ormat, detail

* check against the SAS maturity groups
tabstat ormat, by(matgroup) stat(n min p50 max)

keep date isin ormat isctd
tempfile ormat
save `ormat'

* bid ask spread in basis points from the cleaned Bloomberg quotes
use "$key/bond_bidask.dta", clear
gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
keep date isin bidask
tempfile bidask
save `bidask'

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

* borrowing side, the spread and the haircut on overnight positions only as in the CTD charts, the spread without the days around FOMC decisions
use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume borrowing_rate borrowing_haircut borrowing_term
rename borrowing_* *
merge m:1 date using `sofr', keep(1 3) nogen
gen spread = (rate - sofr)*100 if term <= 1
replace haircut = . if term > 1
gen fomc = 0
foreach d in 16mar2022 4may2022 15jun2022 27jul2022 21sep2022 2nov2022 14dec2022 1feb2023 22mar2023 3may2023 26jul2023 18sep2024 7nov2024 18dec2024 17sep2025 29oct2025 10dec2025 {
	replace fomc = 1 if inrange(date, td(`d'), td(`d') + 3)
}
replace spread = . if fomc == 1

* trim the spreads at the first and last percentile within year as in the CTD charts
gen year = year(date)
bysort year: egen p1 = pctile(spread), p(1)
bysort year: egen p99 = pctile(spread), p(99)
replace spread = . if spread < p1 | spread > p99

merge m:1 date isin using `ormat', keep(match) nogen
merge m:1 date isin using `bidask', keep(1 3) nogen

* original maturity rounded to the year, the issues cluster at the benchmark tenors so one point per tenor reads better than equal count bins
gen ormat_r = round(ormat)
label define ctdlab 0 "Not CTD" 1 "CTD"
label values isctd ctdlab

* where the positions sit along the original maturity, volume in billions summed over the sample
preserve
	collapse (sum) volume, by(ormat_r isctd)
	tw (bar volume ormat_r if isctd == 0, barwidth(0.8))(bar volume ormat_r if isctd == 1, barwidth(0.8)), ///
		legend(order(1 "Not CTD" 2 "CTD") pos(6) rows(1)) xtitle("Original maturity, years") ytitle("Borrowing positions, bn")
restore

* the three outcomes against original maturity, position weighted means pooled over days, CTD and other bonds as separate series
local lab_bidask  "Yield bid ask spread, bp"
local lab_spread  "Borrowing repo rate minus SOFR, bp"
local lab_haircut "Haircut, percent"
foreach y in bidask spread haircut {
	binscatter `y' ormat_r [aw = volume], by(isctd) discrete line(none) ///
		legend(order(1 "Not CTD" 2 "CTD") pos(6) rows(1)) xtitle("Original maturity, years") ytitle("`lab_`y''") name(`y', replace)
}
