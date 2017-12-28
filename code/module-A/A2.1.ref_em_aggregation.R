# ------------------------------------------------------------------------------
# Program Name: A1.2.ref_em_aggregation.R
# Author(s): Leyang Feng
# Date Last Updated: Oct 21, 2016 
# Program Purpose: Process reference emissions into same sector-region setting as 
#                  IAM interpplated emissions 
# Input Files: reference emission files under /input/reference_emissions/[datasets name]
# Output Files: A.[REF]_emissions_aggregated.csv
# Notes: 
# TODO: 
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 0. Read in global settings and headers

# Call standard script header function to read in universal header files - 
# provides logging, file support, and system functions - and start the script log.
log_msg <- "Prepare reference emissions" 
script_name <- "A2.1.ref_em_aggregation.R"

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
printLog( paste0( 'The version of reference dataset is: ', ref_version ) )

# read in ref sector mapping file 
sector_mapping <- readData( domain = 'MAPPINGS', file_name = ref_sector_mapping ) 
region_mapping <- readData( domain = 'MAPPINGS', file_name = ref_region_mapping ) 

# -----------------------------------------------------------------------------
# 2. Read reference emission data 
ref_em <- readData( domain = 'REF_EM', file_name = 'CEDS_by_country_by_CEDS_sector_with_luc_all_em',
                    domain_extension = ref_domain_extension )

# extrac x years in ref_em 
ref_em_xyear <- colnames( ref_em )[ grep( '^X', colnames( ref_em ) )  ]

# ----------------------------------------------------------------------------
# 3. Pick out reference emissions air and shp sector before aggregate 
sector_list_airshp <- c( 'Aircraft', "International Shipping" )

ref_em_airshp <- ref_em[ ref_em$sector %in% sector_list_airshp, ]
ref_em_airshp$region <- 'World'
ref_em_airshp$iso <- NULL

# ----------------------------------------------------------------------------
# 4. Pick out none-air/shipping sectors and aggregate ref_em into IAM regions
ref_em <- ref_em[ ref_em$sector %!in% sector_list_airshp, ]

# add IAM regions to ref_em
ref_em$region <- region_mapping[ match( ref_em$iso, region_mapping$iso ), 'region' ]
ref_em <- ref_em[ !is.na( ref_em$region ), ]

ref_em_reg_agg <- aggregate( ref_em[ , ref_em_xyear ], 
                             by = list( ref_em$em, ref_em$sector,
                                        ref_em$region, ref_em$unit ), 
                             FUN = sum ) 

colnames( ref_em_reg_agg ) <- c( 'em', 'sector', 'region', 'unit', ref_em_xyear )

# ----------------------------------------------------------------------------
# 6. Output
# write the aggregated reference emissions into the intermediate-output folder 
out_filname <- paste0( 'A.', ref_name, '_emissions_aggregated', '_', RUNSUFFIX )
writeData( ref_em_reg_agg, 'MED_OUT', out_filname, meta = F  )  

# write the reference emissions for air and shp sector into the intermediate-output folder 
out_filname <- paste0( 'A.', ref_name, '_emissions_airshp_global', '_', RUNSUFFIX )
writeData( ref_em_airshp, 'MED_OUT', out_filname, meta = F  )  

# END
logStop( )
