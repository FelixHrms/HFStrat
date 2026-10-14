clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Four weightings of the original maturity of CTD against non CTD bonds, US only, all Treasuries outstanding
* equal weights over the bonds outstanding, weights by the total and by the public amount outstanding from CRSP in millions, and weights by fund borrowing positions
* the amounts are carried forward within a bond where CRSP leaves a day empty, CRSP reports no public amount for bills so the public amount line holds bonds and notes only
* original maturity is the maturity date minus the issue date in years

* fund borrowing positions summed over funds, zero for bonds no fund finances
use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
collapse (sum) borrowing_volume, by(date isin)
tempfile funds
save `funds'

* the bond day universe with the CTD flag, the outcome and the four weights
use "$key/bond_day.dta", clear
keep if country == "US" & inrange(date, td(04jan2021), td(30sep2025))
keep date isin cusip8 issuedate maturitydate amt_tot amt_pub
sort isin date
by isin: replace amt_tot = amt_tot[_n-1] if missing(amt_tot)
by isin: replace amt_pub = amt_pub[_n-1] if missing(amt_pub)
gen cusip = cusip8
merge 1:1 date cusip using "$key/day_bond_deliverable_ctd.dta", keep(1 3) keepusing(ctd1 ctd2) nogen
gen isctd = ctd1 != "" | ctd2 != ""
label define ctdlab 0 "Not CTD" 1 "CTD", replace
label values isctd ctdlab
merge 1:1 date isin using `funds', keep(1 3) nogen
replace borrowing_volume = 0 if missing(borrowing_volume)
gen ormat = (maturitydate - issuedate)/365
gen w1 = 1
gen w2 = amt_tot
gen w3 = amt_pub
gen w4 = borrowing_volume
tempfile universe
save `universe'

* one weighted mean per weighting, group and day
foreach k in 1 2 3 4 {
	use `universe', clear
	keep if !missing(w`k') & w`k' > 0
	collapse (mean) ormat`k' = ormat [aw = w`k'], by(date isctd)
	tempfile m`k'
	save `m`k''
}
use `m1', clear
forvalues k = 2/4 {
	merge 1:1 date isctd using `m`k'', nogen
}
bysort date: drop if _N < 2 /*keep days with both groups*/

* CTD bonds on the left and all other bonds on the right, the four weightings in each panel
tw (line ormat1 date)(line ormat2 date)(line ormat3 date)(line ormat4 date), by(isctd, rows(1) note("") legend(pos(6))) ///
	legend(order(1 "Equal weights" 2 "Amount outstanding" 3 "Public amount outstanding" 4 "Fund positions") rows(2)) ///
	xlabel(#5, format(%tdCY)) ytitle("Original maturity, years") xtitle("")
