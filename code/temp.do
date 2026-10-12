clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Bid ask spread, repo spread and haircut along the original maturity of the bond, the continuous version of age at issuance
* original maturity is the maturity date minus the issue date in years, computed here from the two dates and never from the SAS maturity groups

use "$int/sftds_agg.dta", clear
gen ormat = (maturitydate - issuedate)/365
count if missing(ormat)
bysort newcountry: sum ormat, detail

* check against the SAS maturity groups, the German branches above twelve years test matgroup instead of ormat, so the 30 year group should be empty there
tabstat ormat if country == "DE", by(matgroup) stat(n min p50 max)
tabstat ormat if country == "US", by(matgroup) stat(n min p50 max)

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

* ESTR, day month year dates
import delimited "$data/ESTR.csv", varnames(1) clear
gen date2 = date(date, "DMY")
drop date
rename date2 date
format date %td
keep date estr
tempfile estr
save `estr'

* US, borrowing side, the spread and the haircut on overnight positions only as in the CTD charts, the spread without the days around FOMC decisions
use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume borrowing_rate borrowing_haircut borrowing_term
rename borrowing_* *
merge m:1 date using `sofr', keep(1 3) nogen
gen spread = (rate - sofr)*100 if term <= 1
replace haircut = . if term > 1
gen cbday = 0
foreach d in 16mar2022 4may2022 15jun2022 27jul2022 21sep2022 2nov2022 14dec2022 1feb2023 22mar2023 3may2023 26jul2023 18sep2024 7nov2024 18dec2024 17sep2025 29oct2025 10dec2025 {
	replace cbday = 1 if inrange(date, td(`d'), td(`d') + 3)
}
gen region = "US"
tempfile us
save `us'

* euro area, lending side, the spread over ESTR without the days around ECB decisions
use "$int/sftds.dta", clear
keep if country != "US" & lending_volume > 0
keep date isin lending_volume lending_rate lending_haircut lending_term
rename lending_* *
merge m:1 date using `estr', keep(1 3) nogen
gen spread = (rate - estr)*100 if term <= 1
replace haircut = . if term > 1
gen cbday = 0
foreach d in 21jul2022 8sep2022 27oct2022 15dec2022 2feb2023 16mar2023 4may2023 15jun2023 27jul2023 14sep2023 6jun2024 12sep2024 17oct2024 12dec2024 30jan2025 6mar2025 17apr2025 5jun2025 {
	replace cbday = 1 if inrange(date, td(`d'), td(`d') + 9)
}
gen region = "EU"
append using `us'
replace spread = . if cbday == 1

* trim the spreads at the first and last percentile within region and year as in the CTD charts
gen year = year(date)
bysort region year: egen p1 = pctile(spread), p(1)
bysort region year: egen p99 = pctile(spread), p(99)
replace spread = . if spread < p1 | spread > p99

merge m:1 date isin using `ormat', keep(match) nogen
merge m:1 date isin using `bidask', keep(1 3) nogen

* original maturity rounded to the year, the issues cluster at the benchmark tenors so one point per tenor reads better than equal count bins
gen ormat_r = round(ormat)
label define ctdlab 0 "Not CTD" 1 "CTD"
label values isctd ctdlab

* where the positions sit along the original maturity, volume in billions summed over the sample
preserve
	collapse (sum) volume, by(region ormat_r isctd)
	tw (bar volume ormat_r if isctd == 0, barwidth(0.8))(bar volume ormat_r if isctd == 1, barwidth(0.8)), by(region, yrescale) ///
		legend(order(1 "Not CTD" 2 "CTD") pos(6) rows(1)) xtitle("Original maturity, years") ytitle("Positions, bn")
restore

* the three outcomes against original maturity, position weighted means pooled over days, CTD and other bonds as separate series
foreach y in bidask spread haircut {
	local lab_bidask  "Yield bid ask spread, bp"
	local lab_spread  "Repo rate minus overnight rate, bp"
	local lab_haircut "Haircut, percent"
	foreach r in US EU {
		binscatter `y' ormat_r if region == "`r'" [aw = volume], by(isctd) discrete line(none) ///
			legend(order(1 "Not CTD" 2 "CTD") pos(6) rows(1)) xtitle("Original maturity, years") ytitle("`lab_`y''") title("`r'") name(`y'_`r', replace)
	}
}
