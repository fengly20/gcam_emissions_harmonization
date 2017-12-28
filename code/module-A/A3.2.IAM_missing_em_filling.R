# ------------------------------------------------------------------------------
# Program Name: 
# Author(s): Leyang Feng
# Date Last Updated: Nov 22, 2016 
# Program Purpose: 
# Input Files: 
# Output Files: 
# Notes: 
# TODO: 
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 0. Read in global settings and headers

# Call standard script header function to read in universal header files - 
# provides logging, file support, and system functions - and start the script log.
log_msg <- "Fill GCAM missing emissions" 
script_name <- "A3.2.IAM_missing_em_filling.R"

initialize( script_name, log_msg )

# ------------------------------------------------------------------------------
# 0.5 Define IAM variable
MODULE_A <- "../code/module-A/"

# ------------------------------------------------------------------------------
# 1. Read mapping files and axtract iam info
# read in master config file 
master_config <- readData( 'MAPPINGS', 'master_config', column_names = F )
# select iam configuration line from the mapping and read the iam information as a list 
iam_info_list <- iamInfoExtract( master_config, iam )

# extract target IAM info from master mapping 
printLog( paste0( 'IAM to be processed: ', iam_name ) )  
printLog( paste0( 'IAM to CEDS16 sector mapping file: ', iam_sector_mapping ) )  
printLog( paste0( 'Reference emission dataset: ', ref_name ) )
printLog( paste0( 'The harmonization base year is: ', base_year ) )


filling_start_year <- harm_start_year
filling_end_year <- harm_end_year
x_baseyear <- paste0( 'X', base_year )

# ------------------------------------------------------------------------------
# 2. Read in IAM emissions and proxy data, and reference emissions

iam_em <- readData( domain = 'MED_OUT', file_name = paste0( 'A.', iam_name, '_emissions_aggregated', '_', RUNSUFFIX ) )
iam_em_proxy <- readData( domain = 'MED_OUT', file_name = paste0( 'A.', iam_name, '_emissions_proxy', '_', RUNSUFFIX ) )
ref_em <- readData( domain = 'MED_OUT', file_name = paste0( 'A.CEDS_emissions_aggregated', '_', RUNSUFFIX ) )

iam_em_xyear <- colnames( iam_em )[ grep( '^X', colnames( iam_em ) ) ]
iam_em_header_cols <- colnames( iam_em )[ grep( '^X', colnames( iam_em ), invert = T ) ]


# -----------------------------------------------------------------------------
# 3. fill in the gcam emissions using reference emissions and proxy 
# Basic logic: emissions for some sector needs to be filled using proxy data depending on emission species
# below is a table indicating the sector missing situation for each species 
# sector|BC|CH4|CO|CO2|NH3|NOx|OC|Sulfur|VOC
# ---|---|---|---|---|---|---|---|---|---
# Fossil Fuel Fires|missing|missing|missing|missing|missing|missing|missing|missing|missing
# Fuel Production and Transformation|missing|missing|missing|**nonmissing**|missing|missing|missing|missing|missing
# Oil and Gas Fugitive/Flaring|missing|missing|missing|missing|missing|missing|missing|missing|missing
# Residential Commercial Other - Other|missing|missing|missing|missing|missing|missing|missing|missing|missing

# note only CO2 does not need filling for Fuel Production and Transformation 

# the section 3 will be divided into 4 parts for filling of each sector 
filling_sectors <- c( "Fossil Fuel Fires", 
                      "Fuel Production and Transformation", 
                      "Oil and Gas Fugitive/Flaring", 
                      "Residential Commercial Other - Other" )
 
iam_em_to_be_filled <- iam_em[ iam_em$sector %in% filling_sectors, ]
iam_em_remain_untouched <- iam_em[ !( iam_em$sector %in% filling_sectors ), ]
iam_em_remain_untouched <- rbind( iam_em_remain_untouched, 
                                  iam_em_to_be_filled[ iam_em_to_be_filled$em == 'CO2' & iam_em_to_be_filled$sector == "Fuel Production and Transformation", ] )
iam_em_to_be_filled <- iam_em_to_be_filled[ !( iam_em_to_be_filled$em == 'CO2' & iam_em_to_be_filled$sector == "Fuel Production and Transformation" ), ]

filling_x_years <- paste0( 'X', filling_start_year : filling_end_year )

# -----------------------------------------------------------------------------
# 3.1 fill in emissions for sector Fossil Fuel Fires using global total fossil energy consumption
target_df <- iam_em_to_be_filled[ iam_em_to_be_filled$sector == 'Fossil Fuel Fires', ]
ref_df <- ref_em[ ref_em$sector == 'Fossil Fuel Fires', ]
proxy_df <- iam_em_proxy[ ( iam_em_proxy$variable == 'Primary Energy|Fossil' & iam_em_proxy$region == 'World' ),  ]

# filling process 
temp_wide_df <- merge( target_df, proxy_df, 
                       by.x = c( 'scenario' ), 
                       by.y = c( 'scenario' ) )
temp_wide_df <- merge( temp_wide_df, ref_df, 
                       by.x  = c( 'region.x', 'em', 'sector' ),
                       by.y = c( 'region', 'em', 'sector' ) )
# note: in the temp_wide_df, column 'Xyear.x' is from target_df, 
#                                   'Xyear.y' is from proxy_df,
#                                   'Xyear' is from ref_df,
temp_wide_df$frac_baseyear <- temp_wide_df[ , x_baseyear ] / temp_wide_df[ , paste0( x_baseyear, '.y' ) ]
temp_wide_df$frac_baseyear <- ifelse( is.infinite( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df$frac_baseyear <- ifelse( is.nan( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df[ , paste0( iam_em_xyear, '.x' ) ] <- 
  temp_wide_df[ , paste0( iam_em_xyear, '.y' ) ] * temp_wide_df$frac_baseyear
emission_df <- temp_wide_df[ , c(  "region.x", "em", "sector", "scenario", "model.x", "unit.x", paste0( iam_em_xyear, '.x' ) ) ]
colnames( emission_df ) <- gsub( '.x', '', colnames( emission_df ), fixed = T )

# update iam_em_to_be_filled using values in emission_df 
iam_em_to_be_filled <- merge( iam_em_to_be_filled, emission_df, by = c(  "model", "scenario", "region", "em", "sector", "unit" ), all.x = T  )
temp_line_indexes <- which( !is.na( iam_em_to_be_filled[ , paste0( x_baseyear, '.y' ) ] ) )
iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.x' ) ] <- iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.y' ) ]
iam_em_to_be_filled <- iam_em_to_be_filled[ , c( iam_em_header_cols, paste0( iam_em_xyear, '.x' ) ) ]
colnames( iam_em_to_be_filled ) <- gsub( '.x', '', colnames( iam_em_to_be_filled ) )

# -----------------------------------------------------------------------------
# 3.2 fill in emissions for Fuel Production and Transformation using regional primary oil consumption 

target_df <- iam_em_to_be_filled[ iam_em_to_be_filled$sector == 'Fuel Production and Transformation', ]
ref_df <- ref_em[ ref_em$sector == 'Fuel Production and Transformation', ]
proxy_df <- iam_em_proxy[ iam_em_proxy$variable == 'Primary Energy|Oil',  ]
proxy_df <- proxy_df[ proxy_df$region != 'World', ]

# filling process 
temp_wide_df <- merge( target_df, proxy_df, 
                       by.x = c( 'scenario', 'region' ), 
                       by.y = c( 'scenario', 'region' ) )
temp_wide_df <- merge( temp_wide_df, ref_df, 
                       by.x  = c( 'region', 'em', 'sector' ),
                       by.y = c( 'region', 'em', 'sector' ) )
# note: in the temp_wide_df, column 'Xyear.x' is from target_df, 
#                                   'Xyear.y' is from proxy_df,
#                                   'Xyear' is from ref_df,
temp_wide_df$frac_baseyear <- temp_wide_df[ , x_baseyear ] / temp_wide_df[ , paste0( x_baseyear, '.y' ) ]
temp_wide_df$frac_baseyear <- ifelse( is.infinite( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df$frac_baseyear <- ifelse( is.nan( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df[ , paste0( iam_em_xyear, '.x' ) ] <- 
  temp_wide_df[ , paste0( iam_em_xyear, '.y' ) ] * temp_wide_df$frac_baseyear
emission_df <- temp_wide_df[ , c(  "region", "em", "sector", "scenario", "model.x", "unit.x", paste0( iam_em_xyear, '.x' ) ) ]
colnames( emission_df ) <- gsub( '.x', '', colnames( emission_df ), fixed = T )

# update iam_em_to_be_filled using values in emission_df 
iam_em_to_be_filled <- merge( iam_em_to_be_filled, emission_df, by = c(  "model", "scenario", "region", "em", "sector", "unit" ), all.x = T  )
temp_line_indexes <- which( !is.na( iam_em_to_be_filled[ , paste0( x_baseyear, '.y' ) ] ) )
iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.x' ) ] <- iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.y' ) ]
iam_em_to_be_filled <- iam_em_to_be_filled[ , c( iam_em_header_cols, paste0( iam_em_xyear, '.x' ) ) ]
colnames( iam_em_to_be_filled ) <- gsub( '.x', '', colnames( iam_em_to_be_filled ) )

# -----------------------------------------------------------------------------
# 3.3 fill in emissions for Oil and Gas Fugitive/Flaring using global primary oil consumption

target_df <- iam_em_to_be_filled[ iam_em_to_be_filled$sector == 'Oil and Gas Fugitive/Flaring', ]
ref_df <- ref_em[ ref_em$sector == 'Oil and Gas Fugitive/Flaring', ]
proxy_df <- iam_em_proxy[ ( iam_em_proxy$variable == 'Primary Energy|Oil' & iam_em_proxy$region == 'World' ),  ]

# filling process 
temp_wide_df <- merge( target_df, proxy_df, 
                       by.x = c( 'scenario' ), 
                       by.y = c( 'scenario' ) )
temp_wide_df <- merge( temp_wide_df, ref_df, 
                       by.x  = c( 'region.x', 'em', 'sector' ),
                       by.y = c( 'region', 'em', 'sector' ) )
# note: in the temp_wide_df, column 'Xyear.x' is from target_df, 
#                                   'Xyear.y' is from proxy_df,
#                                   'Xyear' is from ref_df,
temp_wide_df$frac_baseyear <- temp_wide_df[ , x_baseyear ] / temp_wide_df[ , paste0( x_baseyear, '.y' ) ]
temp_wide_df$frac_baseyear <- ifelse( is.infinite( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df$frac_baseyear <- ifelse( is.nan( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df[ , paste0( iam_em_xyear, '.x' ) ] <- 
  temp_wide_df[ , paste0( iam_em_xyear, '.y' ) ] * temp_wide_df$frac_baseyear
emission_df <- temp_wide_df[ , c(  "region.x", "em", "sector", "scenario", "model.x", "unit.x", paste0( iam_em_xyear, '.x' ) ) ]
colnames( emission_df ) <- gsub( '.x', '', colnames( emission_df ), fixed = T )

# update iam_em_to_be_filled using values in emission_df 
iam_em_to_be_filled <- merge( iam_em_to_be_filled, emission_df, by = c(  "model", "scenario", "region", "em", "sector", "unit" ), all.x = T  )
temp_line_indexes <- which( !is.na( iam_em_to_be_filled[ , paste0( x_baseyear, '.y' ) ] ) )
iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.x' ) ] <- iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.y' ) ]
iam_em_to_be_filled <- iam_em_to_be_filled[ , c( iam_em_header_cols, paste0( iam_em_xyear, '.x' ) ) ]
colnames( iam_em_to_be_filled ) <- gsub( '.x', '', colnames( iam_em_to_be_filled ) )

# -----------------------------------------------------------------------------
# 3.4 fill in emissions for Residential Commercial Other - Other using regional Building fossil energy consumption

target_df <- iam_em_to_be_filled[ iam_em_to_be_filled$sector == 'Residential Commercial Other - Other', ]
ref_df <- ref_em[ ref_em$sector == 'Residential Commercial Other - Other', ]
proxy_df <- iam_em_proxy[ iam_em_proxy$variable == 'Final Energy|Residential and Commercial|Solids',  ]
proxy_df <- proxy_df[ proxy_df$region != 'World', ]

# filling process 
temp_wide_df <- merge( target_df, proxy_df, 
                       by.x = c( 'scenario', 'region' ), 
                       by.y = c( 'scenario', 'region' ) )
temp_wide_df <- merge( temp_wide_df, ref_df, 
                       by.x  = c( 'region', 'em', 'sector' ),
                       by.y = c( 'region', 'em', 'sector' ) )
# note: in the temp_wide_df, column 'Xyear.x' is from target_df, 
#                                   'Xyear.y' is from proxy_df,
#                                   'Xyear' is from ref_df,
temp_wide_df$frac_baseyear <- temp_wide_df[ , x_baseyear ] / temp_wide_df[ , paste0( x_baseyear, '.y' ) ]
temp_wide_df$frac_baseyear <- ifelse( is.infinite( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df$frac_baseyear <- ifelse( is.nan( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df[ , paste0( iam_em_xyear, '.x' ) ] <- 
  temp_wide_df[ , paste0( iam_em_xyear, '.y' ) ] * temp_wide_df$frac_baseyear
emission_df <- temp_wide_df[ , c(  "region", "em", "sector", "scenario", "model.x", "unit.x", paste0( iam_em_xyear, '.x' ) ) ]
colnames( emission_df ) <- gsub( '.x', '', colnames( emission_df ), fixed = T )

# update iam_em_to_be_filled using values in emission_df 
iam_em_to_be_filled <- merge( iam_em_to_be_filled, emission_df, by = c(  "model", "scenario", "region", "em", "sector", "unit" ), all.x = T  )
temp_line_indexes <- which( !is.na( iam_em_to_be_filled[ , paste0( x_baseyear, '.y' ) ] ) )
iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.x' ) ] <- iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.y' ) ]
iam_em_to_be_filled <- iam_em_to_be_filled[ , c( iam_em_header_cols, paste0( iam_em_xyear, '.x' ) ) ]
colnames( iam_em_to_be_filled ) <- gsub( '.x', '', colnames( iam_em_to_be_filled ) )

# -----------------------------------------------------------------------------
# 5. Combine filled and untouched emissions together

iam_em <- rbind( iam_em_to_be_filled, iam_em_remain_untouched )

# ------------------------------------------------------------------------------
# 6. Output
# write the interpolated IAM data into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_emissions_filled', '_', RUNSUFFIX )
writeData( iam_em, 'MED_OUT', out_filname, meta = F )

logStop( )
