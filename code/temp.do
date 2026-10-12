clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Original maturity of CTD bonds against all other bonds held by funds, US only, weighted by borrowing positions
* original maturity is the maturity date minus the issue date in years, computed from the two dates and never from the SAS maturity groups

use "$int/sftds_agg.dta", clear
keep if country == "US"
gen ormat = (maturitydate - issuedate)/365
count if missing(ormat)
sum ormat, detail
keep date isin ormat isctd ctd1 ctd2
tempfile ormat
save `ormat'

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
keep date isin borrowing_volume
merge m:1 date isin using `ormat', keep(match) nogen
collapse (mean) ormat [aw = borrowing_volume], by(date isctd)
bysort date: drop if _N < 2 /*keep days with both groups*/

* time series on the left
tw (line ormat date if isctd==1)(line ormat date if isctd==0), legend(order(1 "CTD" 2 "Not CTD") pos(6) rows(1)) ytitle("Original maturity, years") xtitle("") name(ts, replace)

* means and the gap with Newey West standard errors over 20 trading days, the daily series are autocorrelated
reshape wide ormat, i(date) j(isctd)
sort date
gen t = _n
tsset t
foreach g in 0 1 {
	newey ormat`g', lag(20)
	local m`g' = _b[_cons]
	local s`g' = _se[_cons]
}
gen gap = ormat1 - ormat0
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
tw (bar mean x if isctd == 1, barwidth(0.6))(bar mean x if isctd == 0, barwidth(0.6))(rcap lo hi x, lcolor(black)), xlabel(0 "CTD" 1 "Not CTD") xtitle("") yscale(range(0)) ylabel(#5) ytitle("Original maturity, years") legend(off) name(bar, replace)
graph combine ts bar, cols(2)

**# Diagnostic. Which CTD bonds carry positions on each day, their original maturity and the contract behind them
* the flag marks the two CUSIPs that were most often the Bloomberg CTD of each front contract, on every day that contract is the front, so a handful of bonds per day
* ctd1 and ctd2 hold the contract tickers, the root is the letters before the month code

use "$int/sftds.dta", clear
keep if country == "US" & borrowing_volume > 0
collapse (sum) borrowing_volume (count) nfunds = borrowing_volume, by(date isin)
merge m:1 date isin using `ormat', keep(match) nogen
keep if isctd == 1
gen contract = cond(ctd1 != "", ctd1, ctd2)
gen root = ustrregexs(1) if ustrregexm(contract, "^([A-Z]+)[FGHJKMNQUVXZ][0-9]")
tab root, missing
tabstat ormat, by(root) stat(n min p50 max)

* tenor by root, the 2 and 5 year contracts take notes with an original term of at most five years and three months, so 7 year notes under TU or FV are matching or issue date errors
gen ormat_r = round(ormat)
tab root ormat_r
list date isin contract ormat if inlist(root, "TU", "FV") & ormat_r == 7, noobs sepby(isin)

* composition over time, bond days and borrowing volume by root and year
gen year = year(date)
tab year root
table year root, stat(sum borrowing_volume) nformat(%6.1f)

* one point per CTD bond and day, bands at the tenors, gaps on the days a CTD carries no position
sepscatter ormat date, separate(root) msize(vsmall) ytitle("Original maturity, years") xtitle("") name(ctdset, replace)

* how many CTD bonds carry positions per day, and how many funds hold each
bysort date: gen nctd = _N
tw (line nctd date), ytitle("CTD bonds with borrowing positions") xtitle("") name(nctd, replace)
tabstat nfunds, by(root) stat(mean min max)

* the bond level mean against the fund row mean, the latter weights each bond by the number of funds holding it
bysort date: egen ormat_bond = mean(ormat)
gen w = ormat*nfunds
bysort date: egen num = sum(w)
bysort date: egen den = sum(nfunds)
gen ormat_fundrow = num/den
bysort date: gen first = _n == 1
tw (line ormat_bond date if first)(line ormat_fundrow date if first), legend(order(1 "Mean over CTD bonds" 2 "Mean over fund positions") pos(6) rows(1)) ytitle("Original maturity, years") xtitle("") name(means, replace)
