clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. A complete bond day panel from 2021 with the hedge fund repo activity, the CTD flag and the price, saved as one file
* every bond on every day it is outstanding in the price panel, US and euro area, January 2021 to September 2025
* the repo activity from the SFTDS by bond and day, summed over funds, with the volume weighted rates, empty where no fund touched the bond that day
* volumes in billions as in sftds.dta, rates in percent, the CTD flag and the contract names from the Bloomberg CTD file, the price from the bond day panel

* hedge fund borrowing and lending by bond and day, the rate weighted by the volume of the trades that carry a rate
use "$int/sftds.dta", clear
keep date isin borrowing_volume borrowing_rate lending_volume lending_rate
preserve
	keep if borrowing_volume > 0 & !missing(borrowing_rate)
	collapse (mean) hf_borrowing_rate = borrowing_rate [aw = borrowing_volume], by(date isin)
	tempfile brate
	save `brate'
restore
preserve
	keep if lending_volume > 0 & !missing(lending_rate)
	collapse (mean) hf_lending_rate = lending_rate [aw = lending_volume], by(date isin)
	tempfile lrate
	save `lrate'
restore
gen nb = borrowing_volume > 0
gen nl = lending_volume > 0
collapse (sum) hf_borrowing = borrowing_volume hf_lending = lending_volume hf_funds_borrowing = nb hf_funds_lending = nl, by(date isin)
merge 1:1 date isin using `brate', nogen
merge 1:1 date isin using `lrate', nogen
foreach v in hf_borrowing hf_lending hf_funds_borrowing hf_funds_lending {
	replace `v' = . if `v' == 0
}
tempfile hf
save `hf'

* the bond day panel with the CTD flag, then the hedge fund activity
use "$key/bond_day.dta", clear
keep if inrange(date, td(04jan2021), td(30sep2025))
keep date isin cusip8 country bondtype issuedate maturitydate couponrate refprice refyield duration amt_tot amt_pub otr_number
gen cusip = cusip8
merge 1:1 date cusip using "$key/day_bond_deliverable_ctd.dta", keep(1 3) keepusing(ctd1 ctd2 deliverable_contract1 deliverable_contract2) nogen
drop cusip
gen isctd = ctd1 != "" | ctd2 != ""
gen isdeliverable = deliverable_contract1 != "" | deliverable_contract2 != ""
merge 1:1 date isin using `hf', keep(1 3) nogen

label var refprice "Price from the bond day panel"
label var refyield "Yield from the bond day panel"
label var amt_tot "Amount outstanding, CRSP, millions, US only"
label var amt_pub "Public amount outstanding, CRSP, millions, US only"
label var otr_number "On the run number within country, bond type and tenor group, 1 is the newest"
label var isctd "Cheapest to deliver of a front contract, Bloomberg"
label var ctd1 "Contract the bond is the most frequent CTD of"
label var ctd2 "Contract the bond is the second most frequent CTD of"
label var isdeliverable "Deliverable into a front contract"
label var hf_borrowing "Hedge fund repo borrowing against the bond, billions, empty if none"
label var hf_borrowing_rate "Volume weighted repo rate paid by hedge funds, percent"
label var hf_lending "Hedge fund repo lending against the bond, billions, empty if none"
label var hf_lending_rate "Volume weighted repo rate received by hedge funds, percent"
label var hf_funds_borrowing "Number of funds borrowing against the bond"
label var hf_funds_lending "Number of funds lending against the bond"
sort isin date
order date isin cusip8 country bondtype issuedate maturitydate couponrate refprice refyield duration amt_tot amt_pub otr_number isctd ctd1 ctd2 isdeliverable deliverable_contract1 deliverable_contract2 hf_*
count
count if !missing(hf_borrowing)
count if isctd
save "$int/bond_day_hf.dta", replace
