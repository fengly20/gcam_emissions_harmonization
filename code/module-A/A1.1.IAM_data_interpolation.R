# ------------------------------------------------------------------------------
# Program Name: A1.1.IAM_data_interpolation.R
# Author(s): Leyang Feng
# Date Last Updated: Nov 16, 2016 
# Program Purpose: Read in IAM data according to variable list file and interpolate IAM values. 
# Input Files:
# Output Files: 
# Notes: 
# TODO: 
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 0. Read in global settings and headers

# Call standard script header function to read in universal header files - 
# provides logging, file support, and system functions - and start the script log.
log_msg <- "Read in and interpolate IAM values" 
script_name <- "A1.1.IAM_data_interpolation.R"

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
printLog( paste0( 'Method for IAM data interpolation: ', iam_interpolation_method ) ) 

# read in variable list 
variable_list <- readData( domain = 'MAPPINGS', file_name = iam_variable_list ) 
if ( exists( 'harm_method_specific_mapping' ) ) { 
  harm_method_mapping <- readData( domain = 'MAPPINGS', file_name = harm_method_specific_mapping ) 
  }

# ------------------------------------------------------------------------------
# 2. Read in IAM data 
raw_df <- read_excel( input_file )
colnames( raw_df ) <- tolower( colnames( raw_df ) )
# keep only desired variables from variable_list
raw_df <- raw_df[ raw_df$variable %in% variable_list$variable, ]  

year_list <- c( 2015, 2020, 2030, 2040, 2050, 2060, 2070, 2080, 2090, 2100 )
xyear_list <- paste0( 'X', year_list )

data_df <- raw_df[ , c( 'model', 'scenario', 'region', 'variable', 'unit', as.character( year_list ) ) ]
names( data_df ) <- c( 'model', 'scenario', 'region', 'variable', 'unit', xyear_list )

# -----------------------------------------------------------------------------
# 3. interpolate iam_data 
all_xyears <- paste0( 'X', year_list[ 1 ] : year_list[ length( year_list ) ] )
int_xyear <- all_xyears[ which( !( all_xyears %in% xyear_list ) ) ]
data_int <- data_df
data_int[ , int_xyear ] <- NA
data_int <- data_int[ , c( 'model', 'scenario', 'region', 'variable', 'unit', all_xyears ) ]
data_int <- interpolateXyears( data_int, int_method = iam_interpolation_method )

# ------------------------------------------------------------------------------
# 4. Output
# write the interpolated IAM data into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_data_interpolated', '_', RUNSUFFIX )
writeData( iam_data_int, 'MED_OUT', out_filname, meta = F )  

# END
logStop( )
