# ------------------------------------------------------------------------------
# Program Name: 
# Author(s): Leyang Feng
# Date Last Updated: Sep 16, 2016 
# Program Purpose: A
# Input Files: 
# Output Files: 
# Notes: 
# TODO: 
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 0. Read in global settings and headers

# Call standard script header function to read in universal header files - 
# provides logging, file support, and system functions - and start the script log.
log_msg <- "Harmonize GCAM emissions" 
script_name <- "A5.1.IAM_em_harmonaze.R"

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
printLog( paste0( 'Reference emission dataset: ', ref_name ) )
printLog( paste0( 'The harmonization base year is: ', base_year ) )

if ( exists( 'harmonization_method_specific_flag' ) ) { 
  harm_method_mapping <- readData( 'MAPPINGS', harm_method_specific_mapping )
  }

# -----------------------------------------------------------------------------
# 2. Read IAM emissions and extended offset 

iam_em <- readData( 'MED_OUT', paste0( 'A.', iam_name, '_emissions_filled', '_', RUNSUFFIX ) )
iam_em_airshp <- readData( 'MED_OUT', paste0( 'A.', iam_name, '_emissions_global_air_shp', '_', RUNSUFFIX ) )

iam_em_full <- rbind( iam_em, iam_em_airshp )

offset <- readData( 'MED_OUT', paste0( 'A.', ref_name, '_', iam_name, '_extended_offset', '_', RUNSUFFIX ) )

# -----------------------------------------------------------------------------
# 3. Apply offsets over IAM emissions

iam_em_harmonized <- applyOffset( iam_em_full, 
                                  offset, 
                                  harm_start_year = harm_start_year,
                                  harm_end_year = harm_end_year, 
                                  harmonization_type = harm_type,
                                  harmonization_method_specific_flag = harmonization_method_specific_flag,
                                  harmonization_method_specific_mapping = harm_method_mapping )

# ----------------------------------------------------------------------------
# 4. Output
# write the aggregated reference emissions into the intermediate-output folder 
out_filname <- paste0( 'A.', iam_name, '_harmonized', '_', RUNSUFFIX )
writeData( iam_em_harmonized, 'MED_OUT', out_filname, meta = F  )  

# END
logStop( )
