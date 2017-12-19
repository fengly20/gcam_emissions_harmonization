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
log_msg <- "Aggregate IAM data" 
script_name <- "A1.2.IAM_em_aggregation.R"

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

# master sector list 
msl <- readData( domain = 'MAPPINGS', file_name = 'IAMC_sector_mapping_CEDS16' )
  
# ------------------------------------------------------------------------------
# 2. Read in IAM data 
iam_data <- readData( 'MED_OUT', paste0( 'A.', iam, '_data_interpolated', '_', RUNSUFFIX ) )

# -----------------------------------------------------------------------------
# 3. pick out only emission variables and clean the layout

iam_em <- iam_data[ iam_data$variable %in% variable_list[ variable_list$type == 'emission', 'variable' ],  ]

iam_em[ , 'unit' ] <- unlist( lapply( strsplit( iam_em[ , 'unit' ], split = ' ' ), '[[', 1 ) ) 

iam_xyears <- grep( 'X', colnames( iam_em ), value = T )

# -----------------------------------------------------------------------------
# 4 aggregate IAM emissions to CEDS16 sectors

# merge iam_em with the sector mapping file 
iam_em_merge <- merge( iam_em, sector_mapping, by.x = c( 'variable' ), by.y = c( 'variable' )  )

# extract cols that desired 
iam_em_agg <- iam_em_merge[ , c( "model", "scenario", "variable", "region", "unit", "em", "CEDS16", iam_xyears ) ]

# aggregate the iam_em to CEDS16 sectors 
iam_em_agg <- iam_em_agg[ !is.na( iam_em_agg$CEDS16 ), ]
iam_em_CEDS16 <- aggregate( iam_em_agg[ , iam_xyears ], 
                            by = list( iam_em_agg$model, iam_em_agg$scenario, 
                                       iam_em_agg$region, iam_em_agg$em, iam_em_agg$CEDS16, iam_em_agg$unit ),
                            FUN = sum )
# clean up the layout
colnames( iam_em_CEDS16 ) <- c( 'model', 'scenario', 'region', 'em', 'CEDS16', 'unit', iam_xyears ) 

# ------------------------------------------------------------------------------
# 5. layout check - for each region per emission species per scenario, there should be 14 sectors( AIR and SHP are processed seperately). 
#    Fille non-existing emissions with NA
native_reg_list <- native_reg_list 
sector_list <- sort( unique( ds_sector_mapping$sector ) )
scenario_list <- sort( unique( iam_data$scenario ) ) 
em_list <- sort( unique( iam_data$em ) )






num_model <- unique( iam_em_CEDS16$model )
num_unit <- unique( iam_em_CEDS16$unit )
num_regions <- unique( iam_em_CEDS16$region )
num_scenarios <- unique( iam_em_CEDS16$scenario ) 
num_em <- unique( iam_em_CEDS16$em )
num_sectors <- unique( msl$sector ) 
#num_sectors <- num_sectors[ !is.na( num_sectors ) ]
num_sectors <- num_sectors[ !( num_sectors %in% c( 'Aircraft', 'International Shipping' ) ) ]

iam_em_complete_layout <- completeLayoutNA( iam_em_CEDS16, num_regions, num_sectors, num_scenarios, num_em, num_model, num_unit, iam_x_years ) 

native_reg_list <- native_reg_list 
sector_list <- sort( unique( ds_sector_mapping$sector ) )
scenario_list <- sort( unique( iam_data$scenario ) ) 
em_list <- sort( unique( iam_data$em ) )

genCompleteLayout <- function( ) { 
  sector_list <- sector_list[ sector_list != "International Shipping" ]
  sector_list <- sector_list[ sector_list != "Aircraft" ]
  sce_res_list <- lapply( scenario_list, function( sce ) { 
    em_res_list <- lapply( em_list, function( em ) { 
      sec_res_list <- lapply( sector_list, function( sec ) { 
        reg_res_list <- lapply( native_reg_list, function( reg ) {
          
          out_df <- data.frame( scenario = sce, 
                                em = em, 
                                region = reg,
                                sector = sec,
                                stringsAsFactors = F )
          
        } ) 
        reg_res <- do.call( 'rbind', reg_res_list )
      } )
      sec_res <- do.call( 'rbind', sec_res_list )
      
      if ( iam == 'GCAM4' ) model_world <- 'World'
      if ( iam == 'REMIND-MAGPIE' ) model_world <- 'World'
      if ( iam == 'MESSAGE-GLOBIOM' ) model_world <- 'World'
      if ( iam == 'AIM' ) model_world <- 'World'
      if ( iam == 'IMAGE' ) model_world <- 'World'
      
      air_res <- data.frame( scenario = sce, 
                             em = em, 
                             region = model_world,
                             sector = "Aircraft", 
                             stringsAsFactors = F )
      shp_res <- data.frame( scenario = sce, 
                             em = em, 
                             region = model_world,
                             sector = "International Shipping", 
                             stringsAsFactors = F )
      sec_res <- rbind( sec_res, air_res, shp_res )
    } )
    em_res <- do.call( 'rbind', em_res_list )
  } )
  sce_res <- do.call( 'rbind', sce_res_list )
  sce_res$model <- unique( iam_data$model )
  sce_res$harm_status <- unique( iam_data$harm_status )
  sce_res$unit <- unique( iam_data$unit )
  
  return( sce_res )
}
complete_layout <- genCompleteLayout( )  

iam_data <- merge( iam_data, 
                   complete_layout, 
                   by = c( 'model', 'scenario', 'region', 'em', 'sector', 'harm_status', 'unit' ), 
                   all.y = T )
iam_data[ is.na( iam_data ) ] <- 0 










# -----------------------------------------------------------------------------
# 6. Remove region World from iam_em_complete_layout.

iam_em_complete_layout <- iam_em_complete_layout[ iam_em_complete_layout$region != 'World', ] 

# ------------------------------------------------------------------------------
# 7. Output
# write the IAM emissions into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_emissions_aggregated' )
writeData( iam_em_complete_layout, 'MED_OUT', out_filname, meta = F  )  

# END
