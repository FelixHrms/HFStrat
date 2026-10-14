clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. A complete US bond day panel from 2021 with the hedge fund borrowing and lending and their rates, the CTD flag and the price, saved as one file
* every US Treasury on every day it is outstanding in the price panel, January 2021 to September 2025
* borrowing and lending from the SFTDS summed over funds, in billions as in sftds.dta, the rates in percent weighted by the volume of the trades that report one, empty where no fund traded the bond that day

* hedge fund borrowing and lending by bond and day
use "$int/sftds.dta", clear
keep date isin borrowing_volume borrowing_rate lending_volume lending_rate
foreach s in borrowing lending {
	preserve
		keep if `s'_volume > 0 & !missing(`s'_rate)
		collapse (mean) hf_`s'_rate = `s'_rate [aw = `s'_volume], by(date isin)
		tempfile `s'rate
		save ``s'rate'
	restore
}
collapse (sum) hf_borrowing = borrowing_volume hf_lending = lending_volume, by(date isin)
merge 1:1 date isin using `borrowingrate', nogen
merge 1:1 date isin using `lendingrate', nogen
replace hf_borrowing = . if hf_borrowing == 0
replace hf_lending = . if hf_lending == 0
tempfile hf
save `hf'

* the bond day panel with the price and the CTD flag, then the borrowing
use "$key/bond_day.dta", clear
keep if country == "US" & inrange(date, td(04jan2021), td(30sep2025))
keep date isin cusip8 refprice
gen cusip = cusip8
merge 1:1 date cusip using "$key/day_bond_deliverable_ctd.dta", keep(1 3) keepusing(ctd1 ctd2) nogen
drop cusip
gen isctd = ctd1 != "" | ctd2 != ""
drop ctd1 ctd2
merge 1:1 date isin using `hf', keep(1 3) nogen

label var refprice "Price from the bond day panel"
label var isctd "Cheapest to deliver of a front contract, Bloomberg"
label var hf_borrowing "Hedge fund repo borrowing against the bond, billions, empty if none"
label var hf_borrowing_rate "Volume weighted repo rate paid by hedge funds, percent"
label var hf_lending "Hedge fund repo lending against the bond, billions, empty if none"
label var hf_lending_rate "Volume weighted repo rate received by hedge funds, percent"
sort isin date
order date isin cusip8 refprice isctd hf_borrowing hf_borrowing_rate hf_lending hf_lending_rate
count
count if !missing(hf_borrowing)
count if isctd
save "$int/bond_day_hf.dta", replace
