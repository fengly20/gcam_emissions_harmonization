# ------------------------------------------------------------------------------
# Program Name: 
# Author(s): Leyang Feng
# Date Last Updated: Nov 28, 2016 
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
log_msg <- "Extend offset." 
script_name <- "A4.2.IAM_ref_em_offset_ext.R"

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
# 2. Read in offset 

offset_filename <- paste0( 'A.', ref_name, '_', iam_name, '_baseyear_offset', '_', RUNSUFFIX )

offset_df <- readData( 'MED_OUT', offset_filename )

# -----------------------------------------------------------------------------
# 3. Extend the offset 

offset_extended <- extendOffset( offset_df, 
                                 baseyear = base_year,
                                 harmonization_method = harmonization_method,
                                 harm_method_specific_flag = harmonization_method_specific_flag, 
                                 harm_method_specific_mapping = harm_method_mapping, 
                                 harm_start_year = harm_start_year, 
                                 harm_end_year = harm_end_year, 
                                 offset_reduce_year = offset_reduce_year, 
                                 offset_reduce_value = offset_reduce_value, 
                                 ratio_reduce_year = ratio_reduce_year, 
                                 ratio_reduce_value = ratio_reduce_value )


  
# ----------------------------------------------------------------------------
# 4. Output
# write the aggregated reference emissions into the intermediate-output folder 
out_filname <- paste0( 'A.', ref_name, '_', iam_name, '_extended_offset', '_', RUNSUFFIX )
writeData( offset_extended, 'MED_OUT', out_filname, meta = F )  

# END
logStop( )

