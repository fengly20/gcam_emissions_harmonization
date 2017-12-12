# ------------------------------------------------------------------------------
# Program Name: 
# Author(s): Leyang Feng
# Date Last Updated: Nov 16, 2016 
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
log_msg <- "Reference historical emissions aggregation to CEDS16 sector setting" 
script_name <- ""

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

# read in variable list 
variable_list <- readData( domain = 'MAPPINGS', file_name = iam_variable_list ) 

# ------------------------------------------------------------------------------
# 2. Read in IAM data 
iam_data <- readData( 'MED_OUT', paste0( 'A.', iam, '_data_interpolated' ) )

# -----------------------------------------------------------------------------
# 3. pick out only iam downscaling variables for usage in module-B 

iam_downscaling <- iam_data[ iam_data$variable %in% variable_list[ variable_list$type == 'downscaling_data', 'variable' ],  ]

# ------------------------------------------------------------------------------
# 4. Output
# write the IAM emissions into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_downscaling_var' )
writeData( iam_downscaling, 'MED_OUT', out_filname, meta = F )

# END
