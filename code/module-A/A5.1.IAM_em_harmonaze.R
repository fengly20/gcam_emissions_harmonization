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
log_msg <- "Apply extended offset over interpolated IAM emissions" 
script_name <- "A5.1.IAM_em_harmonazed.R"

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
print( paste0( 'Reference emission dataset: ', ref_name ) )
print( paste0( 'The harmonization base year is: ', base_year ) )

if ( exists( 'harmonization_method_specific_flag' ) ) { 
  harm_method_mapping <- readData( 'MAPPINGS', harm_method_specific_mapping )
  }

# -----------------------------------------------------------------------------
# 2. Read IAM emissions and extended offset 

iam_em <- readData( 'MED_OUT', paste0( 'A.', iam_name, '_emissions_filled' ) )
iam_em_airshp <- readData( 'MED_OUT', paste0( 'A.', iam_name, '_emissions_global_air_shp' ) )

iam_em_full <- rbind( iam_em, iam_em_airshp )

offset <- readData( 'MED_OUT', paste0( 'A.', ref_name, '_', iam_name, '_extended_offset' ) )

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
out_filname <- paste0( 'A.', iam_name, '_harmonized' )
writeData( iam_em_harmonized, 'MED_OUT', out_filname, meta = F  )  


# END
