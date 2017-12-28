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
log_msg <- "Aggregate IAM data" 
script_name <- "A1.2.IAM_em_aggregation.R"

initialize( script_name, log_msg )

# ------------------------------------------------------------------------------
# 0.5 Define IAM variable
MODULE_A <- "../code/module-A/"

# ------------------------------------------------------------------------------
# 1. Read mapping files and axtract iam info

# this script is for GCAM emissions only 
if ( iam != 'GCAM4' ) { stop( 'This script is for GCAM SO2 emissions only! ' ) }

# read in master config file 
master_config <- readData( 'MAPPINGS', 'master_config', column_names = F )
# select iam configuration line from the mapping and read the iam information as a list 
iam_info_list <- iamInfoExtract( master_config, iam )

x_baseyear <- paste0( 'X', base_year )

# ------------------------------------------------------------------------------
# 2. Read in 
iam_em <- readData( domain = 'MED_OUT', file_name = paste0( 'A.', iam_name, '_emissions_aggregated', '_', RUNSUFFIX ) )

# ------------------------------------------------------------------------------
# 3. GCAM emission sector removal 
# GCAM does not report emissions for some IAMC CEDS16 sectors so remove those sectors 
# from GCAM emission complete layout. 
# The process contains two parts: (1) sector removal for non-CO2 emissions (section 3.1);
#                                 (2) sector removal for CO2 emissions (see section 3.2 for details). 
# 3.1 GCAM sector removal for non-CO2 emissions 
sectors_to_remove <- c( 'Peat Burning', 'Other Fugitive/Flaring', 'International Shipping - Tanker Loading' )
iam_em <- iam_em[ iam_em$sector %!in% sectors_to_remove, ]

# 3.2 GCAM sector removal for CO2 emissions
# Not only CO2 needs removal for above sectors, it also needs to remove 
# four additional sectors because GCAM just does not report in that way. 
# Those four sectors are: Agriculture, Forest Burning, 
#                         Grassland Burning, Solvents Production and Application
# In additon, the treatment for CO2 Transportation sector is also different: 
# In the GCAM-CEDS16 mapping file the CEDS16 'Road Transportation' mapped to 
# GCAM 'Transportation' for convenience since GCAM only report combined transportation emissions. 
# Here the script renames CO2 Road Transportation into Transportation as in CEDS9 and also 
# combine Road/non-road transportation in reference emissions into transportation. 
# 3.2.1 CO2 sector removal 
sectors_to_remove <- c( 'Agriculture', 'Forest Burning', 'Grassland Burning', 
                        'Solvents Production and Application', 'Non-Road Transportation' )
removal_row_index <- c( )
for ( each_row in 1 : nrow( iam_em ) ) { 
  if ( iam_em[ each_row,  'sector' ] %in% sectors_to_remove & iam_em[ each_row,  'em' ] == 'CO2' ) { 
    removal_row_index <- c( removal_row_index, each_row ) }
  }
iam_em$row_index <- 1 : nrow( iam_em )
iam_em <- iam_em[ iam_em$row_index %!in% removal_row_index, ]
iam_em$row_index <- NULL 

# ------------------------------------------------------------------------------
# 6. Output
# write the interpolated IAM data into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_emissions_filled', '_', RUNSUFFIX )
writeData( iam_em, 'MED_OUT', out_filname, meta = F )  

logStop( )
