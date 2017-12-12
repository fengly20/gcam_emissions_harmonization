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

# Set working directory to the CEDS input directory and define PARAM_DIR as the
# location of the CEDS parameters directory, relative to the new working directory.
dirs <- paste0( unlist( strsplit( getwd(), c( '/', '\\' ), fixed = T ) ), '/' )
for ( i in 1:length( dirs ) ) {
  setwd( paste( dirs[ 1:( length( dirs ) + 1 - i ) ], collapse = '' ) )
  wd <- grep( 'IAM_pilot/input', list.dirs(), value = T )
  if ( length( wd ) > 0 ) {
    setwd( wd[ 1 ] )
    break
  }
}
PARAM_DIR <- "../code/parameters/"

# Call standard script header function to read in universal header files - 
# provides logging, file support, and system functions - and start the script log.
headers <- c( 'common_data.R', 'data_functions.R', 'module-A_functions.R', 'all_module_functions.R' ) 
log_msg <- "xx" 
script_name <- "A1.1.IAM_data_interpolation.R"

source( paste0( PARAM_DIR, "header.R" ) )
initialize( script_name, log_msg, headers )

# ------------------------------------------------------------------------------
# 0.5 Define IAM variable
args_from_makefile <- commandArgs( TRUE )
iam <- args_from_makefile[ 1 ]
if ( is.na( iam ) ) iam <- "GCAM4"

MODULE_A <- "../code/module-A/"

# ------------------------------------------------------------------------------
# 1. Read mapping files and axtract iam info
# read in master config file 
master_config <- readData( 'MAPPINGS', 'master_config', column_names = F )
# select iam configuration line from the mapping and read the iam information as a list 
iam_info_list <- iamInfoExtract( master_config, iam )

# extract target IAM info from master mapping 
print( paste0( 'IAM to be processed: ', iam_name ) )  
print( paste0( 'IAM to CEDS16 sector mapping file: ', iam_sector_mapping ) )  
print( paste0( 'Reference emission dataset: ', ref_name ) )
print( paste0( 'The harmonization base year is: ', base_year ) )


filling_start_year <- harm_start_year
filling_end_year <- harm_end_year
x_baseyear <- paste0( 'X', base_year )

# ------------------------------------------------------------------------------
# 2. Read in IAM emissions and proxy data, and reference emissions

iam_em <- readData( domain = 'MED_OUT', file_name = paste0( 'A.', iam_name, '_emissions_filled' ) )
iam_em_proxy <- readData( domain = 'MED_OUT', file_name = paste0( 'A.', iam_name, '_emissions_proxy' ) )
ref_em <- readData( domain = 'MED_OUT', file_name = 'A.CEDS_emissions_aggregated' )

# extra step to convert iam_em into numeric 
iam_em_xyear <- colnames( iam_em )[ grep( '^X', colnames( iam_em ) ) ]
iam_em_header_cols <- colnames( iam_em )[ grep( '^X', colnames( iam_em ), invert = T ) ]
iam_em_xyear_data <- data.frame( as.matrix( sapply( iam_em[ , iam_em_xyear ], as.numeric ) ) )  
iam_em <- cbind( iam_em[ , iam_em_header_cols ], iam_em_xyear_data )

# ------------------------------------------------------------------------------
# 3. Pick out sectors need to be filled using proxy data 
iam_em_to_be_filled <- iam_em[ is.na( iam_em[ , iam_em_xyear[ 1 ] ] ), ]
iam_em_remain_untouched <- iam_em[ !is.na( iam_em[ , iam_em_xyear[ 1 ] ] ), ]

# -----------------------------------------------------------------------------
# 4. fill in the gcam emissions using reference emissions and proxy 
# Basic logics: 7 species in total need to be processed. All 7 speceis are missing sector
#               Fossil Fuel Fires, Fuel Production and Transformation, Oil and Gas Fugitive/Flaring 
#               and Residential Commercial Other - Other.
#               The section 4 thus will be divided into 1 parts: 4.1 fills in emissions missing by all species;

filling_x_years <- paste0( 'X', filling_start_year : filling_end_year )

# -----------------------------------------------------------------------------
# 4.1 fill in emissions for sector: Fossil Fuel Fires
#                                   Fuel Production and Transformation 
#                                   Oil and Gas Fugitive/Flaring 
#                                   Residential Commercial Other - Other
# -----------------------------------------------------------------------------
# 4.1.1 fill in emissions for sector Fossil Fuel Fires using global total fossil energy consumption
target_df <- iam_em_to_be_filled[ iam_em_to_be_filled$CEDS16 == 'Fossil Fuel Fires', ]
ref_df <- ref_em[ ref_em$CEDS16 == 'Fossil Fuel Fires', ]
proxy_df <- iam_em_proxy[ ( iam_em_proxy$variable == 'Primary Energy|Fossil' & iam_em_proxy$region == 'World' ),  ]

# filling process 
temp_wide_df <- merge( target_df, proxy_df, 
                       by.x = c( 'scenario' ), 
                       by.y = c( 'scenario' ) )
temp_wide_df <- merge( temp_wide_df, ref_df, 
                       by.x  = c( 'region.x', 'em', 'CEDS16' ),
                       by.y = c( 'region', 'em', 'CEDS16' ) )
# note: in the temp_wide_df, column 'Xyear.x' is from target_df, 
#                                   'Xyear.y' is from proxy_df,
#                                   'Xyear' is from ref_df,
temp_wide_df$frac_baseyear <- temp_wide_df[ , x_baseyear ] / temp_wide_df[ , paste0( x_baseyear, '.y' ) ]
temp_wide_df$frac_baseyear <- ifelse( is.infinite( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df$frac_baseyear <- ifelse( is.nan( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df[ , paste0( iam_em_xyear, '.x' ) ] <- 
  temp_wide_df[ , paste0( iam_em_xyear, '.y' ) ] * temp_wide_df$frac_baseyear
emission_df <- temp_wide_df[ , c(  "region.x", "em", "CEDS16", "scenario", "model.x", "unit.x", paste0( iam_em_xyear, '.x' ) ) ]
colnames( emission_df ) <- gsub( '.x', '', colnames( emission_df ), fixed = T )

# update iam_em_to_be_filled using values in emission_df 
iam_em_to_be_filled <- merge( iam_em_to_be_filled, emission_df, by = c(  "model", "scenario", "region", "em", "CEDS16", "unit" ), all.x = T  )
temp_line_indexes <- which( !is.na( iam_em_to_be_filled[ , paste0( x_baseyear, '.y' ) ] ) )
iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.x' ) ] <- iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.y' ) ]
iam_em_to_be_filled <- iam_em_to_be_filled[ , c( iam_em_header_cols, paste0( iam_em_xyear, '.x' ) ) ]
colnames( iam_em_to_be_filled ) <- gsub( '.x', '', colnames( iam_em_to_be_filled ) )

# -----------------------------------------------------------------------------
# 4.1.2 fill in emissions for Fuel Production and Transformation using regional primary oil consumption 

target_df <- iam_em_to_be_filled[ iam_em_to_be_filled$CEDS16 == 'Fuel Production and Transformation', ]
ref_df <- ref_em[ ref_em$CEDS16 == 'Fuel Production and Transformation', ]
proxy_df <- iam_em_proxy[ iam_em_proxy$variable == 'Primary Energy|Oil',  ]
proxy_df <- proxy_df[ proxy_df$region != 'World', ]

# filling process 
temp_wide_df <- merge( target_df, proxy_df, 
                       by.x = c( 'scenario', 'region' ), 
                       by.y = c( 'scenario', 'region' ) )
temp_wide_df <- merge( temp_wide_df, ref_df, 
                       by.x  = c( 'region', 'em', 'CEDS16' ),
                       by.y = c( 'region', 'em', 'CEDS16' ) )
# note: in the temp_wide_df, column 'Xyear.x' is from target_df, 
#                                   'Xyear.y' is from proxy_df,
#                                   'Xyear' is from ref_df,
temp_wide_df$frac_baseyear <- temp_wide_df[ , x_baseyear ] / temp_wide_df[ , paste0( x_baseyear, '.y' ) ]
temp_wide_df$frac_baseyear <- ifelse( is.infinite( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df$frac_baseyear <- ifelse( is.nan( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df[ , paste0( iam_em_xyear, '.x' ) ] <- 
  temp_wide_df[ , paste0( iam_em_xyear, '.y' ) ] * temp_wide_df$frac_baseyear
emission_df <- temp_wide_df[ , c(  "region", "em", "CEDS16", "scenario", "model.x", "unit.x", paste0( iam_em_xyear, '.x' ) ) ]
colnames( emission_df ) <- gsub( '.x', '', colnames( emission_df ), fixed = T )

# update iam_em_to_be_filled using values in emission_df 
iam_em_to_be_filled <- merge( iam_em_to_be_filled, emission_df, by = c(  "model", "scenario", "region", "em", "CEDS16", "unit" ), all.x = T  )
temp_line_indexes <- which( !is.na( iam_em_to_be_filled[ , paste0( x_baseyear, '.y' ) ] ) )
iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.x' ) ] <- iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.y' ) ]
iam_em_to_be_filled <- iam_em_to_be_filled[ , c( iam_em_header_cols, paste0( iam_em_xyear, '.x' ) ) ]
colnames( iam_em_to_be_filled ) <- gsub( '.x', '', colnames( iam_em_to_be_filled ) )

# -----------------------------------------------------------------------------
# 4.1.3 fill in emissions for Oil and Gas Fugitive/Flaring using global primary oil consumption

target_df <- iam_em_to_be_filled[ iam_em_to_be_filled$CEDS16 == 'Oil and Gas Fugitive/Flaring', ]
ref_df <- ref_em[ ref_em$CEDS16 == 'Oil and Gas Fugitive/Flaring', ]
proxy_df <- iam_em_proxy[ ( iam_em_proxy$variable == 'Primary Energy|Oil' & iam_em_proxy$region == 'World' ),  ]

# filling process 
temp_wide_df <- merge( target_df, proxy_df, 
                       by.x = c( 'scenario' ), 
                       by.y = c( 'scenario' ) )
temp_wide_df <- merge( temp_wide_df, ref_df, 
                       by.x  = c( 'region.x', 'em', 'CEDS16' ),
                       by.y = c( 'region', 'em', 'CEDS16' ) )
# note: in the temp_wide_df, column 'Xyear.x' is from target_df, 
#                                   'Xyear.y' is from proxy_df,
#                                   'Xyear' is from ref_df,
temp_wide_df$frac_baseyear <- temp_wide_df[ , x_baseyear ] / temp_wide_df[ , paste0( x_baseyear, '.y' ) ]
temp_wide_df$frac_baseyear <- ifelse( is.infinite( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df$frac_baseyear <- ifelse( is.nan( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df[ , paste0( iam_em_xyear, '.x' ) ] <- 
  temp_wide_df[ , paste0( iam_em_xyear, '.y' ) ] * temp_wide_df$frac_baseyear
emission_df <- temp_wide_df[ , c(  "region.x", "em", "CEDS16", "scenario", "model.x", "unit.x", paste0( iam_em_xyear, '.x' ) ) ]
colnames( emission_df ) <- gsub( '.x', '', colnames( emission_df ), fixed = T )

# update iam_em_to_be_filled using values in emission_df 
iam_em_to_be_filled <- merge( iam_em_to_be_filled, emission_df, by = c(  "model", "scenario", "region", "em", "CEDS16", "unit" ), all.x = T  )
temp_line_indexes <- which( !is.na( iam_em_to_be_filled[ , paste0( x_baseyear, '.y' ) ] ) )
iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.x' ) ] <- iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.y' ) ]
iam_em_to_be_filled <- iam_em_to_be_filled[ , c( iam_em_header_cols, paste0( iam_em_xyear, '.x' ) ) ]
colnames( iam_em_to_be_filled ) <- gsub( '.x', '', colnames( iam_em_to_be_filled ) )

# -----------------------------------------------------------------------------
# 4.1.4 fill in emissions for Residential Commercial Other - Other using regional Building fossil energy consumption

target_df <- iam_em_to_be_filled[ iam_em_to_be_filled$CEDS16 == 'Residential Commercial Other - Other', ]
ref_df <- ref_em[ ref_em$CEDS16 == 'Residential Commercial Other - Other', ]
proxy_df <- iam_em_proxy[ iam_em_proxy$variable == 'Final Energy|Residential and Commercial|Solids',  ]
proxy_df <- proxy_df[ proxy_df$region != 'World', ]

# filling process 
temp_wide_df <- merge( target_df, proxy_df, 
                       by.x = c( 'scenario', 'region' ), 
                       by.y = c( 'scenario', 'region' ) )
temp_wide_df <- merge( temp_wide_df, ref_df, 
                       by.x  = c( 'region', 'em', 'CEDS16' ),
                       by.y = c( 'region', 'em', 'CEDS16' ) )
# note: in the temp_wide_df, column 'Xyear.x' is from target_df, 
#                                   'Xyear.y' is from proxy_df,
#                                   'Xyear' is from ref_df,
temp_wide_df$frac_baseyear <- temp_wide_df[ , x_baseyear ] / temp_wide_df[ , paste0( x_baseyear, '.y' ) ]
temp_wide_df$frac_baseyear <- ifelse( is.infinite( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df$frac_baseyear <- ifelse( is.nan( temp_wide_df$frac_baseyear ), 0 , temp_wide_df$frac_baseyear )
temp_wide_df[ , paste0( iam_em_xyear, '.x' ) ] <- 
  temp_wide_df[ , paste0( iam_em_xyear, '.y' ) ] * temp_wide_df$frac_baseyear
emission_df <- temp_wide_df[ , c(  "region", "em", "CEDS16", "scenario", "model.x", "unit.x", paste0( iam_em_xyear, '.x' ) ) ]
colnames( emission_df ) <- gsub( '.x', '', colnames( emission_df ), fixed = T )

# update iam_em_to_be_filled using values in emission_df 
iam_em_to_be_filled <- merge( iam_em_to_be_filled, emission_df, by = c(  "model", "scenario", "region", "em", "CEDS16", "unit" ), all.x = T  )
temp_line_indexes <- which( !is.na( iam_em_to_be_filled[ , paste0( x_baseyear, '.y' ) ] ) )
iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.x' ) ] <- iam_em_to_be_filled[ temp_line_indexes, paste0( iam_em_xyear, '.y' ) ]
iam_em_to_be_filled <- iam_em_to_be_filled[ , c( iam_em_header_cols, paste0( iam_em_xyear, '.x' ) ) ]
colnames( iam_em_to_be_filled ) <- gsub( '.x', '', colnames( iam_em_to_be_filled ) )

# -----------------------------------------------------------------------------
# 4. Combine filled and untouched emissions together

iam_em <- rbind( iam_em_to_be_filled, iam_em_remain_untouched )

# ------------------------------------------------------------------------------
# 6. Output
# write the interpolated IAM data into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_emissions_filled' )
writeData( iam_em, 'MED_OUT', out_filname, meta = F )

