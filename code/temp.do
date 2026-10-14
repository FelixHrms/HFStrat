clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Four weightings of the bid ask spread of CTD against non CTD bonds, all US Treasuries
* 1 equal weights over all bonds outstanding, 2 weights by total amount outstanding, 3 weights by public amount outstanding, 4 weights by fund borrowing positions
* the amounts come from the Monthly Statement of the Public Debt through CRSP, in millions, so they are monthly numbers on a daily file

**# Amounts outstanding, simple data quality checks
* the yield spread divides the price spread by duration, so bills carry large yield spreads although they are the most liquid issues in price terms
use "$key/bond_day.dta", clear
keep if country == "US" /*all Treasuries, bills and inflation linked bonds included, the same universe as the fund weighted chart*/
keep if inrange(date, td(04jan2021), td(30sep2025))
keep date isin cusip8 bondtype amt_tot amt_pub
gen year = year(date)
gen miss_tot = missing(amt_tot)
gen miss_pub = missing(amt_pub)
sort isin date
by isin: gen eom = (_n == _N) | (month(date) != month(date[_n+1])) /*last observed day of the month within the bond*/
tab year miss_tot, row nofreq
tab year miss_pub, row nofreq
tabstat miss_tot miss_pub, by(eom) stat(mean n)
by isin: egen nvals_tot = nvals(amt_tot)
by isin: egen nvals_pub = nvals(amt_pub)
tabstat nvals_tot nvals_pub, stat(mean p50 max)
list isin date amt_tot amt_pub if isin == isin[1] & eom, noobs

* carry the last amount forward within each bond, amounts change only at auctions, reopenings and buybacks
by isin: replace amt_tot = amt_tot[_n-1] if missing(amt_tot)
by isin: replace amt_pub = amt_pub[_n-1] if missing(amt_pub)
tab year miss_tot if !missing(amt_tot), row nofreq
drop miss_tot miss_pub eom nvals_tot nvals_pub year

**# The bond day universe with the CTD flag, the bid ask spread and the four weights
gen cusip = cusip8
merge 1:1 date cusip using "$key/day_bond_deliverable_ctd.dta", keep(1 3) keepusing(ctd1 ctd2) nogen
gen isctd = ctd1 != "" | ctd2 != ""
label define ctdlab 0 "Not CTD" 1 "CTD"
label values isctd ctdlab

* yield bid ask spread in basis points from the cleaned Bloomberg quotes, bonds without a quote on the day drop
preserve
	use "$key/bond_bidask.dta", clear
	gen bidask = (ask_price - bid_price)/(duration*(ask_price + bid_price)/2)*10000
	keep date isin bidask
	tempfile bidask
	save `bidask'
restore
merge 1:1 date isin using `bidask', keep(1 3) gen(mergebidask)
tab mergebidask isctd
drop if missing(bidask)
drop mergebidask

* fund borrowing positions summed over funds, zero for bonds no fund finances
preserve
	use "$int/sftds.dta", clear
	keep if country == "US" & borrowing_volume > 0
	collapse (sum) borrowing_volume, by(date isin)
	tempfile funds
	save `funds'
restore
merge 1:1 date isin using `funds', keep(1 3) nogen
replace borrowing_volume = 0 if missing(borrowing_volume)

gen w1 = 1
gen w2 = amt_tot
gen w3 = amt_pub
gen w4 = borrowing_volume
tempfile universe
save `universe'

**# Bid ask spread, CTD bonds on the left and all other bonds on the right, four weightings in each panel
foreach k in 1 2 3 4 {
	use `universe', clear
	keep if !missing(w`k') & w`k' > 0
	collapse (mean) bidask`k' = bidask [aw = w`k'], by(date isctd)
	tempfile m`k'
	save `m`k''
}
use `m1', clear
forvalues k = 2/4 {
	merge 1:1 date isctd using `m`k'', nogen
}
bysort date: drop if _N < 2 /*keep days with both groups*/
tw (line bidask1 date)(line bidask2 date)(line bidask3 date)(line bidask4 date), by(isctd, rows(1) note("") legend(pos(6))) ///
	legend(order(1 "Equal weights" 2 "Amount outstanding" 3 "Public amount outstanding" 4 "Fund positions") rows(2)) ///
	xlabel(#5, format(%tdCY)) ytitle("Yield bid ask spread, bp") xtitle("")
