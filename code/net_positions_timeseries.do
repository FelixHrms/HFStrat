clear all
snapshot erase _all

**# Net repo positions of hedge funds in sovereign bonds, US and euro area
* Rebuilds the two panels of the net position figure (net_long.pdf and
* eu_pos.pdf in HF_TEMP_US.do and HF_TEMP.do) as pngs for the slides.
* Same inputs and same cleaning as the original do-files, only the paths,
* the missing titles and the export lines differ.

global data "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Data"
global fig  "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Figures" /*figures for the slides, the Figures folder of the repository*/
capture mkdir "$fig"

**# US: net position in Treasuries, one series for the whole market
* input is hf_positions_US_svensson.csv, the file HF_TEMP_US.do reads from $dir

import delimited "$data\\hf_positions_US_svensson.csv", clear
	drop date
	gen date = date(business_date, "YMD")
	format date %td
	drop if itype > 4 /*keep bonds, notes and bills*/
	gen dyield = yield - yield_curve
	gen net_long = (borrowing_volume - lending_volume)/10^9 /*net long position in bn*/
	drop if ttm < 0.25 /*eliminates short term bonds*/
	drop if abs(dyield) > 0.5 /*drop if the bond clearly does not fit the curve*/

collapse (sum) net_long, by(date)
tw (scatter net_long date), ///
	ytitle("Billions") xtitle("") ///
	yline(0, lcolor(black))
graph export "$fig\\net_repo_US.png", replace width(3220)

**# Euro area: net position in DE, IT, FR and ES sovereign bonds
* input is hf_positions.csv, the file HF_TEMP.do reads from D:/mts

import delimited "$data\\hf_positions.csv", clear
	drop date
	gen date = date(business_date, "YMD")
	format date %td
	replace yield = "" if substr(yield, 1, 3) == "inf"
	destring yield, replace
	replace amt_out = amt_out/10^9
	drop if strip != ""
	drop if !inlist(coupontype, 0, 1)
	gen diff_y  = yield - refyield
	gen diff_y2 = yield - yield_curve
	bysort date country: egen absmse = median(abs(diff_y2))
	drop if absmse > 0.2
	drop if yield > 7 | yield < -2 | refyield > 7 | refyield < -2
	drop if ttm < 0.25
	drop if abs(diff_y) > 0.25
	drop if abs(diff_y2) > 1
	gen net_long = (borrowing_volume - lending_volume)/10^9 /*net long position in bn*/

collapse (sum) net_long, by(date country)
tw (scatter net_long date if country == "DE") ///
   (scatter net_long date if country == "IT") ///
   (scatter net_long date if country == "FR") ///
   (scatter net_long date if country == "ES"), ///
	legend(order(1 "DE" 2 "IT" 3 "FR" 4 "ES") position(6) cols(4) region(lstyle(none))) ///
	ytitle("Billions") xtitle("") ///
	yline(0, lcolor(black))
graph export "$fig\\net_repo_EA.png", replace width(3220)
