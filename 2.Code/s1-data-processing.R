# title: "IT and Future of Working from Home"
# stage: Stage 1
# author: "LetingZhang"
# date: "04/22/2021"
# input: Raw data
# output: Panel data
# status: NEXT: CI Winsorize
   




####### Preperation ########
  
library(tidyverse)
library(here)
library(data.table)
library(R.utils)
library(lubridate)
library(robustHD)

raw_data_path <- here("1.Data","1.raw_data")
out_data_path <- here("1.Data","1.output_data")

############# IMPORT & CLEAN ###############

####### Import Economic Indicator - EconomicTracker ########

#source: https://github.com/OpportunityInsights/EconomicTracker

# Employment 

employment_county <- read.csv(here(raw_data_path, "/EconomicTracker-main/data/Employment Combined - County - Daily.csv"))
employment_state <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Employment Combined - State - Daily.csv"))

employment_county <- employment_county%>% mutate_if(is.character,as.numeric)
employment_state <- employment_state%>% mutate_if(is.character,as.numeric)


# Unemployment Insurance Claim
ui_county <- read.csv(here(raw_data_path, "/EconomicTracker-main/data/UI Claims - County - Weekly.csv"), stringsAsFactors = F)
ui_state <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/UI Claims - State - Weekly.csv"), stringsAsFactors = F)

ui_county <- ui_county%>% mutate_if(is.character,as.numeric)
ui_state <- ui_state%>% mutate_if(is.character,as.numeric)


# Other indicators
affinity_county <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Affinity - County - Daily.csv"))
affinity_state <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Affinity - State - Daily.csv"))

jobpost_state_week <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Burning Glass - state - Weekly.csv"))

gogmobility_county <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Google Mobility - County - Daily.csv"))
gogmobility_state <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Google Mobility - State - Daily.csv"))

smallbus_county <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Womply Merchants - County - Daily.csv"))
smallbus_state <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Womply Merchants - State - Daily.csv"))

smallrev_county <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Womply Revenue - County - Daily.csv"))
smallrev_state <- read.csv(here(raw_data_path,"/EconomicTracker-main/data/Womply Revenue - State - Daily.csv"))

## Merge
econ_county <- Reduce(function(x, y) merge(x, y, all=TRUE), list(affinity_county,  gogmobility_county,   
                                                                 smallbus_county,smallrev_county ))
econ_county[, 8:14] <- sapply(econ_county[, 8:14], as.numeric )


econ_state <- Reduce(function(x, y) merge(x, y, all=TRUE), list(affinity_state,jobpost_state_week, gogmobility_state, smallbus_state ,smallrev_state ))
econ_state <- econ_state%>% mutate_if(is.character,as.numeric)

####### Import States  Stay at Home - EconomicTracker ########

# source:  https://github.com/OpportunityInsights/EconomicTracker

state_policy  <- read.csv(here(raw_data_path,"EconomicTracker-main/data/Policy Milestones - State.csv"), stringsAsFactors = F)
colnames(state_policy)[1] <- "state"

shelterdate <- read.csv(here(raw_data_path, "shelter-in-place.csv"))
shelterdate$State <- str_replace_all(shelterdate$State, "[*]", "") #Remove * in state names


state_info<-data.frame(abb = state.abb, state = state.name)
state_info[] <- lapply(state_info, as.character)

state_info[nrow(state_info) + 1,] = c( "DC", "District of Columbia")
state_info[nrow(state_info) + 1,] = c("PR", "Puerto Rico")


shelterdate <- merge(shelterdate,state_info, by.x = "State", by.y = "state", all.x = TRUE )
shelterdate$Order.Date <- str_replace_all(shelterdate$Order.Date, "/2020", "") #Remove * in state names
shelterdate$Order.Date1 <- shelterdate$Order.Date

shelterdate <- shelterdate %>% separate("Order.Date1", c("OrderMonth", "OrderDay"))

shelterdate$OrderMonth <- as.integer(shelterdate$OrderMonth)
shelterdate$OrderDay <- as.integer(shelterdate$OrderDay)

#National Emergency Concerning: March 13 
#Reference: https://www.whitehouse.gov/presidential-actions/proclamation-declaring-national-emergency-concerning-novel-coronavirus-disease-covid-19-outbreak/
#Other Source: https://www.finra.org/rules-guidance/key-topics/covid-19/shelter-in-place
#Reference: https://www.nytimes.com/interactive/2020/us/coronavirus-stay-at-home-order.html


######## Import County Stay at Home - Other source ########

#source: https://github.com/JieYingWu/COVID-19_US_County-level_Summaries
#After converting date format in python 

county_policy <- read.csv(here( "1.Data", "2.intermediate_data", "county_shutdown.csv"))


######## Import Covid19 from Eonomic Tracker ########

covid_county <- read.csv(here(raw_data_path, "EconomicTracker-main/data/COVID - County - Daily.csv"), stringsAsFactors = F)
covid_state <- read.csv(here(raw_data_path, "EconomicTracker-main/data/COVID - State - Daily.csv"), stringsAsFactors = F)
covid_county <- covid_county%>% mutate_if(is.character,as.numeric)
covid_state<- covid_state%>% mutate_if(is.character,as.numeric)


######## Import & Clean: IT Workforce Data from QWI  ########

# Import 
# read each csv - for loop

qwifiles <- list.files(path = here(raw_data_path, "QWI-DATA"))
col <- c("geo_level", "geography", "industry","ownercode", "sex", "agegrp", "education", "firmage", "firmsize", "year", "quarter", "Emp", "EmpS",
         "EmpTotal", "HirA", "FrmJbGn", "FrmJbLs", "FrmJbC", "EarnS", "Payroll")
f <- list()

for (i in 1:length(qwifiles)) {
  f[[i]] <- fread( here(raw_data_path, "QWI-DATA", qwifiles[i]), select = col)
}

allqwidata <- rbindlist(f)
#rm(f)


# Choose IT related industry
# extract state level and county level IT employment at 2019 Q4

## industry code
its_industry = c(5112, 5191, 5182, 5415)
computer_industry = c(3341, 3342, 3344, 3345, 5179)


## State_level
state_qwi_emp <- allqwidata  %>% 
  filter(geo_level=="S" ) %>% 
  select ( geography, year, quarter, industry, sex, education, Emp, EmpS,EmpTotal, EarnS, Payroll) 

## Reshape
state_qwi_emp_wide <- dcast(setDT(state_qwi_emp), geography+year+quarter+industry ~ paste0("sex", sex) + paste("education", education), value.var = c("EmpS", "EmpTotal","EarnS"), na.rm = TRUE, sep = "", sum)

colnames(state_qwi_emp_wide)  <- gsub(" ","",colnames(state_qwi_emp_wide))

state_qwi_agg <- state_qwi_emp_wide %>% 
  filter(year == 2019) %>% 
  group_by(geography, year,quarter) %>% 
  select(geography, year,quarter, industry, contains("E0")) %>%
  summarise(
    # EMPS
    its_emps_all = sum(EmpSsex0educationE0[industry %in% its_industry], na.rm=T),
    its_emps_male = sum(EmpSsex1educationE0[industry %in% its_industry], na.rm=T),
    its_emps_female = sum(EmpSsex2educationE0[industry %in% its_industry], na.rm=T),
    
    com_emps_all = sum(EmpSsex0educationE0[industry %in% computer_industry],na.rm=T),
    com_emps_male = sum(EmpSsex1educationE0[industry %in% computer_industry], na.rm=T),
    com_emps_female = sum(EmpSsex2educationE0[industry %in% computer_industry], na.rm=T),
    
    
    all_emps_all = sum(EmpSsex0educationE0,na.rm=T),
    all_emps_male = sum(EmpSsex1educationE0, na.rm=T),
    all_emps_female = sum(EmpSsex2educationE0, na.rm=T),
    
    # EmpTotal
    
    its_empstotal_all = sum(EmpTotalsex0educationE0[industry %in% its_industry], na.rm=T),
    its_empstotal_male = sum(EmpTotalsex1educationE0[industry %in% its_industry], na.rm=T),
    its_empstotal_female = sum(EmpTotalsex2educationE0[industry %in% its_industry], na.rm=T),
    
    com_empstotal_all = sum(EmpTotalsex0educationE0[industry %in% computer_industry],na.rm=T),
    com_empstotal_male = sum(EmpTotalsex1educationE0[industry %in% computer_industry], na.rm=T),
    com_empstotal_female = sum(EmpTotalsex2educationE0[industry %in% computer_industry], na.rm=T),
    
    all_empstotal_all = sum(EmpTotalsex0educationE0,na.rm=T),
    all_empstotal_male = sum(EmpTotalsex1educationE0, na.rm=T),
    all_empstotal_female = sum(EmpTotalsex2educationE0, na.rm=T),
    
    # Earn
    
    its_earn_all = sum(EarnSsex0educationE0[industry %in% its_industry], na.rm=T),
    its_earn_male = sum(EarnSsex1educationE0[industry %in% its_industry], na.rm=T),
    its_earn_female = sum(EarnSsex2educationE0[industry %in% its_industry], na.rm=T),
    
    com_earn_all = sum(EarnSsex0educationE0[industry %in% computer_industry],na.rm=T),
    com_earn_male = sum(EarnSsex1educationE0[industry %in% computer_industry], na.rm=T),
    com_earn_female = sum(EarnSsex2educationE0[industry %in% computer_industry], na.rm=T),
    
    all_earn_all = sum(EarnSsex0educationE0,na.rm=T),
    all_earn_male = sum(EarnSsex1educationE0, na.rm=T),
    all_earn_female = sum(EarnSsex2educationE0, na.rm=T),
    
  ) %>% 
  ungroup()



#County level 

county_qwi_emp <- allqwidata  %>% 
  filter(geo_level=="C" ) %>% 
  select ( geography, year,quarter, industry, sex, education, EmpS, EmpTotal, EarnS, Payroll)
## Reshape
county_qwi_emp_wide<- dcast(setDT(county_qwi_emp), geography+year+quarter+industry ~ paste0("sex", sex) + paste("education", education), value.var = c("EmpS", "EmpTotal", "EarnS"), na.rm = TRUE, sep = "", sum)

colnames(county_qwi_emp_wide)  <- gsub(" ","",colnames(county_qwi_emp_wide))

county_qwi_agg <- county_qwi_emp_wide %>% 
  filter(year == 2019) %>% 
  group_by(geography, year,quarter) %>% 
  select(geography, year,quarter, industry, contains("E0")) %>%
  summarise(
    # EMPS
    its_emps_all = sum(EmpSsex0educationE0[industry %in% its_industry], na.rm=T),
    its_emps_male = sum(EmpSsex1educationE0[industry %in% its_industry], na.rm=T),
    its_emps_female = sum(EmpSsex2educationE0[industry %in% its_industry], na.rm=T),
    
    com_emps_all = sum(EmpSsex0educationE0[industry %in% computer_industry],na.rm=T),
    com_emps_male = sum(EmpSsex1educationE0[industry %in% computer_industry], na.rm=T),
    com_emps_female = sum(EmpSsex2educationE0[industry %in% computer_industry], na.rm=T),
    
    
    all_emps_all = sum(EmpSsex0educationE0,na.rm=T),
    all_emps_male = sum(EmpSsex1educationE0, na.rm=T),
    all_emps_female = sum(EmpSsex2educationE0, na.rm=T),
    
    # EmpTotal
    
    its_empstotal_all = sum(EmpTotalsex0educationE0[industry %in% its_industry], na.rm=T),
    its_empstotal_male = sum(EmpTotalsex1educationE0[industry %in% its_industry], na.rm=T),
    its_empstotal_female = sum(EmpTotalsex2educationE0[industry %in% its_industry], na.rm=T),
    
    com_empstotal_all = sum(EmpTotalsex0educationE0[industry %in% computer_industry],na.rm=T),
    com_empstotal_male = sum(EmpTotalsex1educationE0[industry %in% computer_industry], na.rm=T),
    com_empstotal_female = sum(EmpTotalsex2educationE0[industry %in% computer_industry], na.rm=T),
    
    all_empstotal_all = sum(EmpTotalsex0educationE0,na.rm=T),
    all_empstotal_male = sum(EmpTotalsex1educationE0, na.rm=T),
    all_empstotal_female = sum(EmpTotalsex2educationE0, na.rm=T),
    
    # Earn
    
    its_earn_all = sum(EarnSsex0educationE0[industry %in% its_industry], na.rm=T),
    its_earn_male = sum(EarnSsex1educationE0[industry %in% its_industry], na.rm=T),
    its_earn_female = sum(EarnSsex2educationE0[industry %in% its_industry], na.rm=T),
    
    com_earn_all = sum(EarnSsex0educationE0[industry %in% computer_industry],na.rm=T),
    com_earn_male = sum(EarnSsex1educationE0[industry %in% computer_industry], na.rm=T),
    com_earn_female = sum(EarnSsex2educationE0[industry %in% computer_industry], na.rm=T),
    
    all_earn_all = sum(EarnSsex0educationE0,na.rm=T),
    all_earn_male = sum(EarnSsex1educationE0, na.rm=T),
    all_earn_female = sum(EarnSsex2educationE0, na.rm=T),
    
  ) %>% 
  ungroup()

#output
write.csv(county_qwi_agg,here(out_data_path , "county_qwi_agg.csv"))
write.csv(state_qwi_agg,here(out_data_path , "state_qwi_agg.csv"))



######## Import & Clean: IT budget data from CIDatabase  ########

# read CI cyber data
ci_cyber <- read.csv(here("1.Data/2.intermediate_data", "CI_cyber_use.csv"))
ci_cyber <- subset(ci_cyber, select = c('SITEID','cyber_sum', 'IT_STAFF','PCS'))

# read CI site description data
ci_path <- readWindowsShortcut(here(raw_data_path,"USA_2019.lnk"))
ci_path <- gsub("\\\\", "/", ci_path$pathname)
path <- paste(ci_path, '/SiteDescription.TXT', sep = '')
col <-  c('SITEID', 'PRIMARY_DUNS_NUMBER', 'COMPANY', 'CITY','STATE','ZIPCODE', 'MSA','EMPLE','REVEN','SALESFORCE','MOBILE_WORKERS','MOBILE_INTL', 'SICGRP', 'SICSUBGROUP')
ci_site <- fread(path, select = col)

# read CI app install presence data
path <- paste(ci_path, '/PresenceInstall.TXT', sep = '')
col <-  c('SITEID', 'VPN_PRES', 'IDACCESS_SW_PRES', 'DBMS_PRES', 'DATAWAREHOUSE_SW_PRES', 'SECURITY_SW_PRES')
ci_presence <- fread(path, select = col)

ci_presence[ci_presence == "Yes"] <- 1
ci_presence[ci_presence == ""] <- 0
ci_presence <- as.data.frame(ci_presence)
ci_presence[, 2:6] <- sapply(ci_presence[, 2:6], as.numeric )

# read CI IT spend data
path <- paste(ci_path, '/ITSpend.TXT', sep = '')
ci_itspend <- fread(path)
ci_itspend<- as.data.frame(ci_itspend)


####### Import Geo data & Geo crosswalk file #######

#source: census website PS: USE THE NEW ONE 
#industry_code <- read.csv("cps_monthly_data/2017-census-industry-classification-titles-and-code-list.csv")
#occupation_code<-read.csv("cps_monthly_data/2018-census-occupation-classification-titles-and-code-list.csv")
geo_code <- read.csv(here(raw_data_path,"geocorr2018 -crosswalk.csv"))

#source: https://www.huduser.gov/portal/datasets/usps_crosswalk.html
zip_county <- read.csv(here(raw_data_path, "ZIP_COUNTY_122019.csv"))

#source: https://data.nber.org/cbsa-msa-fips-ssa-county-crosswalk/2019/
msa_county <- read.csv(here(raw_data_path, "COUNTY_METRO2019.CSV"))

# EconomicTrack
geoid <- read.csv(here(raw_data_path, "GeoIDs - County.csv"), stringsAsFactors = F)




####### Import ACS (American Community Survey) file #######

source("asc_api.R")



####### Import CPS data from IPUMS #######

#source: ipums
library(ipumsr)
# Change these filepaths to the filepaths of your downloaded extract
cps_ddi <- read_ipums_ddi(here(raw_data_path,"cps_00003.xml")) # Contains metadata, nice to have as separate object
cps_data <- read_ipums_micro(cps_ddi, data_file = here(raw_data_path, "cps_00003.dat" ))



####### Import COVIDcast data from API  #######
#source: https://cmu-delphi.github.io/delphi-epidata/api/covidcast-signals/safegraph.html
devtools::install_github("cmu-delphi/covidcast", ref = "main",
                         subdir = "R-packages/covidcast")

library(covidcast)





home_prop_7day <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "completely_home_prop_7dav",
                   start_day = "2020-01-01", end_day = "2020-11-10",
                   geo_type = "county"))



work_prop_7day <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "full_time_work_prop_7dav",
                   start_day = "2020-01-01", end_day = "2020-11-10",
                   geo_type = "county")
)



part_prop_7day <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "part_time_work_prop_7dav",
                   start_day = "2020-01-01", end_day = "2020-11-10",
                   geo_type = "county")
)




median_home_time_7dav <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "median_home_dwell_time_7dav",
                   start_day = "2020-01-01", end_day = "2020-11-10",
                   geo_type = "county")
)


bar_visit_num <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "bars_visit_num",
                   start_day = "2020-01-01", end_day = "2020-11-10",
                   geo_type = "county")
)




bars_visit_prop <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "bars_visit_prop",
                   start_day = "2020-01-01", end_day = "2020-11-10",
                   geo_type = "county")
)



restaurants_visit_num <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "restaurants_visit_num",
                   start_day = "2020-01-01", end_day = "2020-11-10",
                   geo_type = "county")
)



restaurants_visit_prop <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "restaurants_visit_prop",
                   start_day = "2020-01-01", end_day = "2020-11-10",
                   geo_type = "county")
)






############# AGGREGATE & CONSTRUCT ###############


############# Aggregate CI data  #######

# add county fips
ci_data_key <- ci_site[, c("SITEID","ZIPCODE")]
ci_data_key$ZIPCODE <- substr(ci_site[, c("SITEID","ZIPCODE")]$ZIPCODE,1,5)
ci_data_key$ZIPCODE <- sub("^0+", "", ci_data_key$ZIPCODE)
ci_data_key$ZIPCODE <- as.integer(ci_data_key$ZIPCODE)

ci_data_key <- merge(ci_data_key, zip_county[, c("ZIP", "COUNTY")], by.x = "ZIPCODE", by.y = "ZIP", all.x = TRUE, allow.cartesian=TRUE)
ci_data_key <- merge(ci_data_key, msa_county, by.x = "COUNTY", by.y = "FIPS.County.Code",all.x = TRUE, allow.cartesian=TRUE )

# merge

ci_data_use <- ci_data_key %>% select(-ZIPCODE) %>% 
  full_join(ci_cyber) %>% 
  full_join(ci_presence) %>% 
  full_join(ci_itspend) %>% 
  full_join(ci_site)

ci_data_use <- ci_data_use %>% 

ci_sum_county_winsorize<- ci_data_use %>% select(SITEID, STATE, COUNTY,CBSA.Name, EMPLE, REVEN, MOBILE_WORKERS 
                                                 ,cyber_sum,VPN_PRES,IDACCESS_SW_PRES,
                                                 DBMS_PRES, DATAWAREHOUSE_SW_PRES, SECURITY_SW_PRES, PCS, IT_BUDGET, HARDWARE_BUDGET, 
                                                 SOFTWARE_BUDGET,SERVICES_BUDGET) %>% 
  mutate(emple_win = winsorize(EMPLE), 
         reven_win = winsorize(REVEN), 
         it_budget_win = winsorize(IT_BUDGET) )




############# Aggregate and contruct county, weekly data #######

# Unemployement insurance:  county, week

ui_county_week <- ui_county %>% 
  mutate(date = ISOdate(year,month, day_endofweek),
         week =  week(as.Date(date, "%Y-%m-%d"))) 


# Employment rate: county, day -> county, week
employ_county_week <- employment_county %>% 
  mutate(date = ISOdate(year,month, day),
         week =  week(as.Date(date, "%Y-%m-%d")))


# Econ: county, day -> county, month

econ_county_week <- econ_county %>% 
  mutate(date = ISOdate(year,month, day),
         week =  week(as.Date(date, "%Y-%m-%d")))


# Covid: county, day -> county,week

covid_county_week <-  covid_county %>% 
  mutate(date = ISOdate(year,month, day),
         week =  week(as.Date(date, "%Y-%m-%d"))) %>% 
  group_by(countyfips,week,year) %>% 
  summarise(case_count = max(case_count, na.rm = T),
            death_count = max(death_count, na.rm = T),
            case_rate = max(case_rate, na.rm = T),
            death_rate = max(death_rate, na.rm = T),
            avg_new_case_count = mean(new_case_count, na.rm = T),
            avg_new_death_rate = mean(new_death_count, nna.rm = T),
            avg_new_case_rate = mean(new_case_count, na.rm = T),
            avg_new_death_rate = mean(new_death_count, na.rm =T),
            
  ) %>% ungroup()


#Safegraph: county daily - weekly

home_prop_7day_use <- home_prop_7day %>% select(geo_value, time_value, value) %>% 
  mutate(week =  week(as.Date(time_value, "%Y-%m-%d"))) %>% 
  group_by(week, geo_value) %>% 
  summarise(avg_home_prop = mean(value, na.rm = TRUE)) %>% ungroup()


work_prop_7day_use <- work_prop_7day %>% select(geo_value, time_value, value) %>% 
  mutate(week =  week(as.Date(time_value, "%Y-%m-%d"))) %>% 
  group_by(week, geo_value) %>% 
  summarise(avg_work_prop = mean(value, na.rm = TRUE)) %>% ungroup()

part_prop_7day_use <- part_prop_7day %>% select(geo_value, time_value, value) %>% 
  mutate(week =  week(as.Date(time_value, "%Y-%m-%d"))) %>% 
  group_by(week, geo_value) %>% 
  summarise(avg_part_prop = mean(value, na.rm = TRUE)) %>% ungroup()

median_home_7day_use <- median_home_time_7dav %>% select(geo_value, time_value, value) %>% 
  mutate(week =  week(as.Date(time_value, "%Y-%m-%d"))) %>% 
  group_by(week, geo_value) %>% 
  summarise(avg_median_home = mean(value, na.rm = TRUE)) %>% ungroup()

bar_visit_num_use <- bar_visit_num %>% select(geo_value, time_value, value) %>% 
  mutate(week =  week(as.Date(time_value, "%Y-%m-%d"))) %>% 
  group_by(week, geo_value) %>% 
  summarise(avg_bar_visitnum = mean(value, na.rm = TRUE)) %>% ungroup()


bar_visit_prop_use <- bars_visit_prop %>% select(geo_value, time_value, value) %>% 
  mutate(week =  week(as.Date(time_value, "%Y-%m-%d"))) %>% 
  group_by(week, geo_value) %>% 
  summarise(avg_bar_visitprop = mean(value, na.rm = TRUE)) %>% ungroup()


res_visit_num_use <- restaurants_visit_num %>% select(geo_value, time_value, value) %>% 
  mutate(week =  week(as.Date(time_value, "%Y-%m-%d"))) %>% 
  group_by(week, geo_value) %>% 
  summarise(avg_res_visitnum = mean(value, na.rm = TRUE)) %>% ungroup()


res_visit_prop_use <- restaurants_visit_prop %>% select(geo_value, time_value, value) %>% 
  mutate(week =  week(as.Date(time_value, "%Y-%m-%d"))) %>% 
  group_by(week, geo_value) %>% 
  summarise(avg_res_visitprop = mean(value, na.rm = TRUE)) %>% ungroup()


safegraph_week <- home_prop_7day_use %>% 
  full_join(work_prop_7day_use) %>% 
  full_join(part_prop_7day_use) %>% 
  full_join(median_home_7day_use) %>% 
  full_join(bar_visit_num_use) %>% 
  full_join(bar_visit_prop_use) %>% 
  full_join(res_visit_num_use) %>% 
  full_join(res_visit_prop_use)





############# Aggregate and contruct state, weekly data #######

# Unemployement insurance: state, week -> county, month






############# Aggregate and contruct county, monthly data #######

# Unemployement insurance: county, week -> county, month
ui_mean_county <- ui_county %>% 
  group_by(month, countyfips) %>% 
  summarise (avg_initclaims_count = mean(initclaims_count_regular, na.rm = T),
             avg_initclaims_rate = mean(initclaims_rate_regular, na.rm = T)  ) %>% 
  ungroup

# Employment rate: county, day -> county, month
employ_mean_county <- employment_county %>% 
  group_by(month, countyfips) %>% 
  summarise_at(c("emp_combined","emp_combined_inclow", "emp_combined_incmiddle", "emp_combined_inchigh"), mean, na.rm = TRUE) %>% ungroup()

# CI: site -> county (sum)

ci_sum_county<- ci_data_use %>% select(SITEID, STATE, COUNTY,CBSA.Name, EMPLE, REVEN, MOBILE_WORKERS, IT_STAFF 
                                       ,cyber_sum,VPN_PRES,IDACCESS_SW_PRES,
                                       DBMS_PRES, DATAWAREHOUSE_SW_PRES, SECURITY_SW_PRES, PCS, IT_BUDGET, HARDWARE_BUDGET, 
                                       SOFTWARE_BUDGET,SERVICES_BUDGET) %>% 
  group_by(COUNTY) %>% 
  summarise_at(c('EMPLE', 'REVEN', 'MOBILE_WORKERS','cyber_sum','VPN_PRES','IDACCESS_SW_PRES', 'DBMS_PRES', 'DATAWAREHOUSE_SW_PRES', 'SECURITY_SW_PRES', 'PCS', 'IT_BUDGET', 'HARDWARE_BUDGET', 'SOFTWARE_BUDGET','SERVICES_BUDGET'), sum, na.rm = TRUE) %>% ungroup()


# Econ: county, day -> county, month

econ_mean_county <- econ_county %>% 
  group_by(month, countyfips) %>% 
  summarise_at(c('spend_all','gps_retail_and_recreation','gps_grocery_and_pharmacy','gps_parks', 'gps_transit_stations',
                 'gps_workplaces', 'gps_residential', 'gps_away_from_home', 'merchants_all', 'revenue_all'), mean, na.rm = TRUE) %>% ungroup()

# Covid: county, day -> county,month

covid_stat_county <-  covid_county %>% 
  group_by(countyfips,month) %>% 
  summarise(case_count = max(case_count, na.rm = T),
            death_count = max(death_count, na.rm = T),
            case_rate = max(case_rate, na.rm = T),
            death_rate = max(death_rate, na.rm = T),
            avg_new_case_count = mean(new_case_count, na.rm = T),
            avg_new_death_rate = mean(new_death_count, nna.rm = T),
            avg_new_case_rate = mean(new_case_count, na.rm = T),
            avg_new_death_rate = mean(new_death_count, na.rm =T),
            
  ) %>% ungroup()

# Aggregation

data_county <- ui_mean_county %>% 
  full_join(employ_mean_county, c('month', 'countyfips') ) %>% 
  full_join(geoid[, c('countyfips', 'statefips', 'stateabbrev')], 'countyfips' ) %>% 
  full_join(econ_mean_county, c('month', 'countyfips')) %>% 
  full_join(covid_stat_county, c('month', 'countyfips')) %>% 
  full_join(state_policy, c('statefips')) %>% 
  full_join(shelterdate[, c('abb', 'OrderMonth', 'OrderDay')], c('stateabbrev' = 'abb') )

############# Aggregate and contruct state, monthly data #######


# Unemployement insurance: state, week -> state, month
ui_mean_state <- ui_state %>% 
  group_by(month,statefips) %>% 
  summarise_at(c('initclaims_count_regular', 'initclaims_rate_regular', 'contclaims_count_regular', 'contclaims_rate_regular', 'initclaims_count_pua', 'contclaims_count_pua'), mean, na.rm = TRUE)

# Employment rate: county, day -> county, month
employ_mean_state <- employment_state %>% 
  group_by(month, statefips) %>% 
  summarise_at(c("emp_combined","emp_combined_inclow", "emp_combined_incmiddle", "emp_combined_inchigh",  "emp_combined_ss40", "emp_combined_ss60", "emp_combined_ss65", "emp_combined_ss70" ), mean, na.rm = TRUE)



# CI: site -> state (sum)

ci_sum_state<- ci_data_use %>% select(SITEID, STATE, COUNTY,CBSA.Name, EMPLE, REVEN, MOBILE_WORKERS ,cyber_sum,VPN_PRES,IDACCESS_SW_PRES, DBMS_PRES, DATAWAREHOUSE_SW_PRES, SECURITY_SW_PRES, PCS, IT_BUDGET, HARDWARE_BUDGET, SOFTWARE_BUDGET,SERVICES_BUDGET) %>% 
  group_by(STATE) %>% 
  summarise_at(c('EMPLE', 'REVEN', 'MOBILE_WORKERS','cyber_sum','VPN_PRES','IDACCESS_SW_PRES', 'DBMS_PRES', 'DATAWAREHOUSE_SW_PRES', 'SECURITY_SW_PRES', 'PCS', 'IT_BUDGET', 'HARDWARE_BUDGET', 'SOFTWARE_BUDGET','SERVICES_BUDGET'), sum, na.rm = TRUE) %>% 
  ungroup()


# Econ: state, day -> state, month
econ_mean_state <- econ_state%>% 
  group_by(month, statefips) %>% 
  summarise_at(vars(spend_acf:revenue_ss70), mean, na.rm = TRUE)


# Covid: state, day -> state,month

covid_stat_state <-  covid_state %>% 
  group_by(month, statefips) %>% 
  summarise(test_count = max(test_count, na.rm = T),
            test_rate = max(test_rate, na.rm = T),
            case_count = max(case_count, na.rm = T),
            death_count = max(death_count, na.rm = T),
            case_rate = max(case_rate, na.rm = T),
            death_rate = max(death_rate, na.rm = T),
            avg_new_case_count = mean(new_case_count, na.rm = T),
            avg_new_death_rate = mean(new_death_count, nna.rm = T),
            avg_new_case_rate = mean(new_case_count, na.rm = T),
            avg_new_death_rate = mean(new_death_count, na.rm =T),
            
  )

data_state <- ui_mean_state %>% 
  full_join(employ_mean_state, c('month', 'statefips') ) %>% 
  left_join(geoid[, c('statefips', 'stateabbrev')], 'statefips' ) %>% 
  unique() %>% 
  full_join(econ_mean_state, c('month', 'statefips')) %>% 
  full_join(covid_stat_state, c('month', 'statefips')) %>% 
  full_join(state_policy, c('statefips')) %>% 
  full_join(shelterdate[, c('abb', 'OrderMonth', 'OrderDay')], c('stateabbrev' = 'abb') )


############# OUTPUT ###############

summary(data_county)
summary(data_state)

write.csv(data_county, here(out_data_path,"data_county.csv") )
write.csv(data_state, here( out_data_path, "data_state.csv") )

