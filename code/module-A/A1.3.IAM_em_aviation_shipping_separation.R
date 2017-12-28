# ------------------------------------------------------------------------------
# Program Name: A1.2.IAM_em_aggregation.R
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

# Call standard script header function to read in universal header files - 
# provides logging, file support, and system functions - and start the script log.
log_msg <- "Separate aircraft and shipping emissions from IAM data" 
script_name <- "A1.3.IAM_em_aviation_shipping_separation.R"

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

# read in target IAM sector mapping file
sector_mapping <- readData( domain = 'MAPPINGS', file_name = iam_sector_mapping ) 

# read in variable list 
variable_list <- readData( domain = 'MAPPINGS', file_name = iam_variable_list ) 
  
# ------------------------------------------------------------------------------
# 2. Read in IAM data 
iam_data <- readData( 'MED_OUT', paste0( 'A.', iam, '_data_interpolated', '_', RUNSUFFIX ) )

# -----------------------------------------------------------------------------
# 3. pick out only emission variables and clean the layout

iam_airshp <- iam_data[ iam_data$variable %in% variable_list[ variable_list$type == 'air_shp_emissions', 'variable' ],  ]

iam_x_years <- grep( 'X', colnames( iam_airshp ), value = T )

# -----------------------------------------------------------------------------
# 4. pick out only region 'world' in iam_airshp, the harmonization later on will only apply on global values 

iam_airshp <- iam_airshp[ iam_airshp$region == "World", ]


iam_airshp[ , 'unit' ] <- unlist( lapply( strsplit( iam_airshp[ , 'unit' ], split = ' ' ), '[[', 1 ) ) 

# -----------------------------------------------------------------------------
# 5. Map the iam_airshp into CEDS16 sectors 

# merge iam_airshp with the sector mapping file 
iam_airshp_merge <- merge( iam_airshp, sector_mapping, by.x = c( 'variable' ), by.y = c( 'variable' )  )
iam_airshp_merge <- iam_airshp_merge[ !is.na( iam_airshp_merge$CEDS16 ), ]

iam_airshp_final <- iam_airshp_merge[ , c( 'model', 'scenario', 'region', 'em', 'CEDS16', 'unit', iam_x_years ) ]

# ------------------------------------------------------------------------------
# 6. Aggregate aircraft and shipping emissions  
iam_airshp_final_agg <- aggregate( iam_airshp_final[ , iam_x_years ], 
                                   by = list( iam_airshp_final$model, iam_airshp_final$scenario,
                                              iam_airshp_final$region, iam_airshp_final$em, 
                                              iam_airshp_final$CEDS16, iam_airshp_final$unit ), 
                                   FUN = sum )
colnames( iam_airshp_final_agg ) <- c( 'model', 'scenario', 'region', 'em', 'sector', 'unit', iam_x_years ) 

# ------------------------------------------------------------------------------
# 7. Output
# write the IAM air and shp emissions into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_emissions_global_air_shp', '_', RUNSUFFIX )
writeData( iam_airshp_final_agg, 'MED_OUT', out_filname, meta = F )  

logStop( )
