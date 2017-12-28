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
log_msg <- "Separate proxy data for harmonization." 
script_name <- "A1.4.IAM_harm_proxy_separation.R"

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

# read in variable list 
variable_list <- readData( domain = 'MAPPINGS', file_name = iam_variable_list ) 

# ------------------------------------------------------------------------------
# 2. Read in IAM data 
iam_data <- readData( 'MED_OUT', paste0( 'A.', iam, '_data_interpolated', '_', RUNSUFFIX ) )

# -----------------------------------------------------------------------------
# 3. pick out only proxy variables for later use ( in script series A.3.xxx ) 
iam_proxy <- iam_data[ iam_data$variable %in% variable_list[ variable_list$type == 'proxy', 'variable' ],  ]

# ------------------------------------------------------------------------------
# 4. Output
# write the IAM air and shp emissions into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_emissions_proxy', '_', RUNSUFFIX )
writeData( iam_proxy, 'MED_OUT', out_filname, meta = F )

# END
logStop( )


