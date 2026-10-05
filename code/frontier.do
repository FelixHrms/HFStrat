clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Carry against duration for all US treasuries on one day, with the frontier of portfolios and the CTDs marked

local day = td(15jan2025)

* upper hull of a point cloud. Duration and carry are linear in weights, so the hull is the portfolio frontier
mata:
real matrix upperhull(real colvector x, real colvector y)
{
	real matrix P, H
	real scalar i, k, turn
	P = sort((x, y), (1, -2))
	H = J(rows(P), 2, .)
	k = 0
	for (i = 1; i <= rows(P); i++) {
		while (k >= 2) {
			turn = (H[k,1]-H[k-1,1])*(P[i,2]-H[k-1,2]) - (H[k,2]-H[k-1,2])*(P[i,1]-H[k-1,1])
			if (turn >= 0) {
				k = k - 1
			}
			else {
				break
			}
		}
		k = k + 1
		H[k,.] = P[i,.]
	}
	return(H[|1,1 \ k,2|])
}
end

* the CTD of every contract on that day
use "$key/basis_stacked.dta", clear
keep if date == `day'
keep cusip contract
duplicates drop
rename cusip cusip8
gen series = regexr(contract, "[FGHJKMNQUVXZ][0-9]+$", "")
keep cusip8 series
duplicates drop
tempfile ctd
save `ctd'

* repo rate per bond, market wide average over all trades on that day
import delimited "$key/bond_day_rate.csv", varnames(1) clear
gen date = date(business_date, "YMD")
keep if date == `day'
rename security_isin isin
keep isin market_rate
count
assert r(N) > 0
tempfile repo
save `repo'

* bonds on that day without TIPS, carry is the yield minus the repo rate, general collateral proxy where the bond has no repo trade
use "$key/bond_day.dta", clear
keep if date == `day' & country == "US"
drop if inlist(bondtype, "11", "12")
gen ttm = (maturitydate - date) / 365
drop if ttm < 0.25
merge m:1 cusip8 using `ctd', keep(1 3)
gen ctd = _merge == 3
drop _merge
merge 1:1 isin using `repo', keep(1 3) nogen
count if missing(market_rate)
sum market_rate, detail
replace market_rate = r(p50) if missing(market_rate)
gen carry = yield_check - market_rate
count if missing(yield_check)
drop if missing(duration, carry)
assert _N > 0
keep cusip8 isin series ctd duration carry ttm bondtype
sum duration carry
list series cusip8 duration carry if ctd, noobs
tempfile bonds
save `bonds'

* the frontier
mata: st_matrix("hull", upperhull(st_data(., "duration"), st_data(., "carry")))
clear
svmat double hull
rename (hull1 hull2) (duration carry)
gen frontier = 1
append using `bonds'

tw (line carry duration if frontier == 1, sort lcolor(black)) ///
   (scatter carry duration if frontier != 1 & ctd == 0, mcolor(gs10) msize(small)) ///
   (scatter carry duration if frontier != 1 & ctd == 1, mcolor(red) msymbol(D) mlabel(series) mlabcolor(red)) , ///
   legend(order(1 "Portfolio frontier" 2 "Treasuries" 3 "CTD") position(6) cols(3) region(lstyle(none))) ///
   ytitle("Yield minus repo rate, pp") xtitle("Duration") yline(0, lcolor(black))
graph export "$fig/frontier_US.png", replace width(3220)
