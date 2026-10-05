clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Scratch file. Positions on one day. Do hedge funds hold bills, and how large is the biggest bond weight

local day = td(15jan2025)

use "$int/sftds.dta", clear
keep if date == `day'
merge m:1 isin using "$int/bond_info.dta", keep(1 3) keepusing(bondtype) nogen
gen bill = inlist(bondtype, "4", "GTC", "LET", "FTB", "BOT")
gen absnet = abs(net)

* bills versus everything else, number of positions and gross and net volume in bn
preserve
	collapse (count) positions = net (sum) absnet net, by(bill)
	list, noobs
restore
tab country bill if absnet > 0

* largest weight in the aggregate hedge fund portfolio, gross positions
preserve
	collapse (sum) absnet net (first) bondtype country, by(isin)
	egen total = sum(absnet)
	gen weight = absnet / total
	gsort -weight
	list isin country bondtype net weight in 1/10, noobs
restore

* largest weight inside each fund's own portfolio
preserve
	collapse (sum) absnet, by(entity_id isin)
	bysort entity_id: egen total = sum(absnet)
	gen weight = absnet / total
	collapse (max) weight (count) nbonds = isin, by(entity_id)
	sum weight nbonds, detail
	hist weight
restore
