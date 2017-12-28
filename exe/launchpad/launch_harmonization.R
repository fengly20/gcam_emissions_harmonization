# ------------------------------------------------------------------------------
# Program Name: luanch_harmonization.R
# Author(s): Leyang Feng
# Date Last Updated: 
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
#for ( i in 1:length( dirs ) ) {
#  setwd( paste( dirs[ 1:( length( dirs ) + 1 - i ) ], collapse = '' ) )
#  wd <- grep( 'gcam_emissions_harmonization/input', list.dirs(), value = T )
#  if ( length( wd ) > 0 ) {
#    setwd( wd[ 1 ] )
#    break
#  }
#}

setwd( 'C:/Users/feng999/Documents/gcam_emissions_harmonization/input' )
PARAM_DIR <- "../code/parameters/"

# Call standard script header function to read in universal header files - 
# provides logging, file support, and system functions - and start the script log.
headers <- c( 'global_settings.R', 'common_data.R', 'data_functions.R', 'module-A_functions.R', 'all_module_functions.R' ) 
launchpad_log_msg <- "Initiate harmonization routines." 
launchpad_name <- "launch_harmonization.R"

source( paste0( PARAM_DIR, "header.R" ) )
initialize_launchpad( launchpad_name, launchpad_log_msg, headers )

# -----------------------------------------------------------------------------
# 1. Set up desired IAM to be processing

# debug
args_from_makefile <- c( 'C:/Users/feng999/Documents/gcam_emissions_harmonization/input/GCAM/SSP4-Ref_V19.xlsx' )

# the flag for intermediate file cleaning
MED_OUT_CLEAN <- F

# getting target IAM from command line arguement
if ( !exists( 'args_from_makefile' ) ) args_from_makefile <- commandArgs( TRUE )
input_file <- args_from_makefile[ 1 ]   
RUNSUFFIX <- substr( sha1( input_file ), 1, 6 ) 
iam <- 'GCAM4'

printLog( paste0( 'input: ', input_file ) )
printLog( paste0( 'the current suffix is: ', RUNSUFFIX ) )

# update domainmapping for current run 
domainmapping <- read.csv( DOMAINPATHMAP, stringsAsFactors = F )

# create unique directory for intermediate files 
med_out <- paste0( '../intermediate-output', '/', RUNSUFFIX )
dir.create( med_out )

domainmapping[ domainmapping$Domain == 'MED_OUT', "PathToDomain" ] <- med_out

# -----------------------------------------------------------------------------
# 2. Source module-B script in order
source( '../code/module-A/A1.1.IAM_data_interpolation.R' )
source( '../code/module-A/A1.2.IAM_em_aggregation.R' )
source( '../code/module-A/A1.3.IAM_em_aviation_shipping_separation.R' )
source( '../code/module-A/A1.4.IAM_harm_proxy_separation.R' )
#source( '../code/module-A/A1.5.IAM_downscale_data_separation.R' )
source( '../code/module-A/A2.1.ref_em_aggregation.R' )
#source( '../code/module-A/A3.1.GCAM_sector_removal.R' )
source( '../code/module-A/A3.2.IAM_missing_em_filling.R' )
source( '../code/module-A/A3.3.GCAM_waste_em_harm.R' )
source( '../code/module-A/A4.1.IAM_ref_em_offset_calc.R' )
source( '../code/module-A/A4.2.IAM_ref_em_offset_ext.R' )
source( '../code/module-A/A5.1.IAM_em_harmonaze.R' )
source( '../code/module-A/A9.IAM_harmonized_format_cleaning.R' )

# -----------------------------------------------------------------------------
# 3. clean the intermediate files
if ( MED_OUT_CLEAN ) { 
  invisible( unlink( med_out, recursive = T ) )
  invisible( file.remove( paste0( '../documentation/IO_documentation_', RUNSUFFIX, '.csv' ) ) )
}

logStop( )
