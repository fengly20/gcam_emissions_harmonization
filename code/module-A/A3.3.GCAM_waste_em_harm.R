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
log_msg <- "Fill GCAM waste emissions" 
script_name <- "A3.3.GCAM_waste_em_harm.R"

initialize( script_name, log_msg )

# ------------------------------------------------------------------------------
# 0.5 Define IAM variable
MODULE_A <- "../code/module-A/"

# ------------------------------------------------------------------------------
# 1. Read mapping files and axtract iam info

# this script is for GCAM emissions only 
if ( iam != 'GCAM4' ) { stop( 'This script is for GCAM emissions only! ' ) }

# read in master config file 
master_config <- readData( 'MAPPINGS', 'master_config', column_names = F )
# select iam configuration line from the mapping and read the iam information as a list 
iam_info_list <- iamInfoExtract( master_config, iam )

x_baseyear <- paste0( 'X', base_year )

# read in ref sector mapping file 
region_mapping <- readData( domain = 'MAPPINGS', file_name = ref_region_mapping ) 

# high income region cut-off mapping by species
hi_mapping <- data.frame( em = c( 'BC', 'CO', 'VOC', 'NOx', 'OC', 'Sulfur', 'NH3', 'CO2', 'CH4' ), 
                          gdp_per_cap_cut = c( 18, 18, 18, 18, 18, 18, 18, 18, 18 ), 
                          em_per_cap_cut = c( 6, 500, 1000, 100, 20, 20, 400, 1000, 2000 ) ) 

# set center point GDP and tau
gdp_center_point <- 16 
tau <- 8 

# ------------------------------------------------------------------------------
# 2. Read in GDP, POP and reference emissions 
# read in IIASA GDP and population data 
gdp_data <- readData( domain = 'SSP_IN', file_name = 'iiasa_gdp' )
pop_data <- readData( domain = 'SSP_IN', file_name = 'iiasa_population' )

# read in IAm emissions 
iam_em <- readData( 'MED_OUT', paste0( 'A.', iam_name, '_emissions_filled', '_', RUNSUFFIX ) )

iam_em_xyear <- colnames( iam_em )[ grep( '^X', colnames( iam_em ) ) ]
iam_em_header_cols <- colnames( iam_em )[ grep( '^X', colnames( iam_em ), invert = T ) ]

iam_em_list <- sort( unique( iam_em$em ) )

# read in reference emissions 
ref_em <- readData( domain = 'MED_OUT', file_name = paste0( 'A.CEDS_emissions_aggregated', '_', RUNSUFFIX ) ) 

pop_gdp_xyears <- paste0( "X", 2015 : 2100 )

# ------------------------------------------------------------------------------
# 3. construct waste emission temporary data frame for base year 
# pick out reference waste emissions 
ref_waste <- ref_em[ ( ref_em$sector == 'Waste' & ref_em$em %in% iam_em_list ), c( 'em', 'sector', 'region', x_baseyear ) ]
colnames( ref_waste ) <- c( 'em', 'sector', 'region', paste0( 'em_', x_baseyear, '_mt' ) ) 

# aggregate pop_data to regional level 
pop_reg <- merge( pop_data[ c( 'iso', 'scenario', x_baseyear ) ], 
                  region_mapping[ ,c( 'iso', 'region' ) ], 
                  by = 'iso' )
pop_reg <- aggregate( pop_reg[, x_baseyear ], 
                      by = list( pop_reg$scenario, pop_reg$region ),
                      FUN = sum )
colnames( pop_reg ) <- c( 'scenario', 'region', paste0( 'pop_', x_baseyear, '_million' ) )
# aggregate gdp_data to regional level 
gdp_reg <- merge( gdp_data[ c( 'iso', 'scenario', x_baseyear ) ], 
                  region_mapping[ ,c( 'iso', 'region' ) ], 
                  by = 'iso' )
gdp_reg <- aggregate( gdp_reg[, x_baseyear ], 
                      by = list( gdp_reg$scenario, gdp_reg$region ),
                      FUN = sum )
colnames( gdp_reg ) <- c( 'scenario', 'region', paste0( 'gdp_', x_baseyear, '_billion' ) )

pop_gdp <- merge( pop_reg[ , c( 'scenario', 'region', paste0( 'pop_', x_baseyear, '_million' ) ) ], 
                  gdp_reg[ , c( 'scenario', 'region', paste0( 'gdp_', x_baseyear, '_billion' ) ) ], 
                  by = c( 'scenario', 'region' )  )
pop_gdp_em <- merge( pop_gdp, ref_waste, by = c( 'region' ) ) 
waste_pro_df <- pop_gdp_em[ , c( 'em', 'sector', 'scenario', 'region', 
                                 paste0( 'em_', x_baseyear, '_mt' ), 
                                 paste0( 'pop_', x_baseyear, '_million' ),
                                 paste0( 'gdp_', x_baseyear, '_billion' ) ) ]
                            
# ----------------------------------------------------------------------------
# 4. waste processing 
# calculation of starting EF
waste_pro_df$em_per_cap <- waste_pro_df[ , paste0( 'em_', x_baseyear, '_mt' ) ] / 
  waste_pro_df[ , paste0( 'pop_', x_baseyear, '_million' ) ] * 
  1000000 # note: the 1000000 means convert the unit from mt into kt 
waste_pro_df$gdp_per_cap <- waste_pro_df[ , paste0( 'gdp_', x_baseyear, '_billion' ) ] / 
  waste_pro_df[ , paste0( 'pop_', x_baseyear, '_million' ) ]
waste_pro_df$gdp_cutoff <- unlist( lapply( waste_pro_df$em, function( em ) { 
  cut_off <- hi_mapping[ hi_mapping$em == em, 'gdp_per_cap_cut' ] 
  } ) )
waste_pro_df$em_cutoff <- unlist( lapply( waste_pro_df$em, function( em ) { 
  cut_off <- hi_mapping[ hi_mapping$em == em, 'em_per_cap_cut' ] 
  } ) )
waste_pro_df$HI_em <- ifelse( ( waste_pro_df$gdp_per_cap > waste_pro_df$gdp_cutoff & waste_pro_df$em_per_cap < waste_pro_df$em_cutoff ),
                              waste_pro_df$em_per_cap, NA )
waste_pro_df$HI_em_indicator <- ifelse( ( waste_pro_df$gdp_per_cap > waste_pro_df$gdp_cutoff & waste_pro_df$em_per_cap < waste_pro_df$em_cutoff ), 
                                        1, NA )
waste_pro_df$starting_EF <- waste_pro_df$em_per_cap 

# calculation of final EF
sce_list <- sort( unique( waste_pro_df$scenario ) ) 
em_list <- sort( unique( waste_pro_df$em ) ) 
calcFinalEF <- function( ) { 
  storage_df <- data.frame( scenario = NA, em = NA, final_EF = NA )
  for ( each_sce in sce_list ) { 
    for ( each_em in em_list ) { 
      temp_df <- waste_pro_df[ ( waste_pro_df$em == each_em & waste_pro_df$scenario == each_sce ),  ]
      temp_df_ex_usa <- temp_df[ temp_df$region != 'USA', ]
      temp_final_EF <- sum( ( temp_df_ex_usa[ , paste0( 'pop_', x_baseyear, '_million' ) ] * temp_df_ex_usa$HI_em ), na.rm = T ) / 
        sum( ( temp_df_ex_usa[ , paste0( 'pop_', x_baseyear, '_million' ) ] * temp_df_ex_usa$HI_em_indicator ), na.rm = T ) 
      temp_final_EF_df <- data.frame( scenario = each_sce, em = each_em, final_EF = temp_final_EF )
      storage_df <- rbind( storage_df, temp_final_EF_df )
      }
    }
  storage_df <- storage_df[ 2 : nrow( storage_df ), ] 
  return( storage_df )
  }
final_EF_df <- calcFinalEF( )

waste_pro_df <- merge( waste_pro_df, final_EF_df, by = c( 'em', 'scenario' ) )  

# starting EF and final EF check 
waste_pro_df$final_EF <- ifelse( waste_pro_df$starting_EF < waste_pro_df$final_EF, 
                                 waste_pro_df$starting_EF,
                                 waste_pro_df$final_EF )
waste_pro_df$final_EF <- ifelse( waste_pro_df$gdp_per_cap > ( gdp_center_point + tau ), 
                                 waste_pro_df$starting_EF,
                                 waste_pro_df$final_EF )

# calculate harmonized waste emissions 
pop_reg_all <- merge( pop_data[ c( 'iso', 'scenario', pop_gdp_xyears ) ], 
                  region_mapping[ ,c( 'iso', 'region' ) ], 
                  by = 'iso' )
pop_reg_all <- aggregate( pop_reg_all[, pop_gdp_xyears ], 
                      by = list( pop_reg_all$scenario, pop_reg_all$region ),
                      FUN = sum )
colnames( pop_reg_all ) <- c( 'scenario', 'region', pop_gdp_xyears )
gdp_reg_all <- merge( gdp_data[ c( 'iso', 'scenario', pop_gdp_xyears ) ], 
                  region_mapping[ ,c( 'iso', 'region' ) ], 
                  by = 'iso' )
gdp_reg_all <- aggregate( gdp_reg_all[, pop_gdp_xyears ], 
                      by = list( gdp_reg_all$scenario, gdp_reg_all$region ),
                      FUN = sum )
colnames( gdp_reg_all ) <- c( 'scenario', 'region', pop_gdp_xyears )

pop_gdp_all <- merge( pop_reg_all, 
                  gdp_reg_all, 
                  by = c( 'scenario', 'region' )  )

waste_calc_df <- merge( waste_pro_df[ , c( 'em', 'scenario', "sector", 'region', 'starting_EF', 'final_EF' ) ],
                        pop_gdp_all, 
                        by = c( 'scenario', 'region' ) ) 
for ( each_year in pop_gdp_xyears ) { 
  waste_calc_df[ , paste0( 'waste_em_', each_year ) ] <- 
    ( waste_calc_df$starting_EF * ( 1 - ( 1 - waste_calc_df$final_EF/waste_calc_df$starting_EF ) /
                                    ( 1 + exp( -4.4*( waste_calc_df[ , paste0( each_year, '.y' ) ] / waste_calc_df[ , paste0( each_year, '.x' ) ] - gdp_center_point )/ tau ) ) ) ) *
    waste_calc_df[ , paste0( each_year, '.x' ) ]
  waste_calc_df[ , paste0( 'waste_em_', each_year ) ] <- ifelse( is.na( waste_calc_df[ , paste0( 'waste_em_', each_year ) ] ),
                                                                 0, 
                                                                 waste_calc_df[ , paste0( 'waste_em_', each_year ) ] ) 
  }

final_waste_em <- waste_calc_df[ , c( "scenario", "region", "em", "sector", paste0( 'waste_em_', pop_gdp_xyears ) ) ]
colnames( final_waste_em ) <- c( "scenario", "region", "em", "sector", pop_gdp_xyears )
# convert the unit from kt into mt 
final_waste_em[ , pop_gdp_xyears ] <- final_waste_em[ , pop_gdp_xyears ] / 1000000

# -----------------------------------------------------------------------------------
# 5. replace iam_em waste emissions using final_waste_em
replaceFunction <- function( ) { 
  iam_em$ssp_label <- unlist( lapply( strsplit( iam_em$scenario, '-', fixed = T ), '[[', 1 ) )
  iam_em_merge <- merge( iam_em, final_waste_em, 
                       by.x = c( "region", "em", 'ssp_label','sector' ),
                       by.y = c( "region", "em", "scenario", 'sector' ),
                       all.x = T )
  rep_mat <- as.matrix( iam_em_merge[ , paste0( pop_gdp_xyears, '.y' ) ] ) 
  log_mat <- ifelse( is.na( rep_mat ), 0, 1  )
  log_mat_invert <- ifelse( log_mat == 1, 0, 1  )
  rep_mat <- ifelse( is.na( rep_mat ), 0, rep_mat  )
  
  # convert NA into 0 in case there are NAs 
  iam_em_merge[ , paste0( pop_gdp_xyears, '.x' ) ][ is.na( iam_em_merge[ , paste0( pop_gdp_xyears, '.x' ) ] ) ] <- 0
  
  iam_em_merge[ , paste0( pop_gdp_xyears, '.x' ) ] <- iam_em_merge[ , paste0( pop_gdp_xyears, '.x' ) ] * log_mat_invert + rep_mat
  iam_em_final <- iam_em_merge 
  colnames( iam_em_final ) <- gsub( '.x', '', colnames( iam_em_final ), fixed = T ) 
  iam_em_final <- iam_em_final[ , grep( '.y', colnames( iam_em_final ), fixed = T, invert = T, value = T ) ]
  iam_em_final$ssp_label <- NULL
  iam_em_xyears <- grep( 'X', colnames( iam_em_final ), fixed = T, value = T ) 
  iam_em_final <- iam_em_final[ , c( 'model', 'scenario', 'region', 'em', 'sector', 'unit', iam_em_xyears ) ]
  
  return( iam_em_final )
  }

iam_em <- replaceFunction() 

# ------------------------------------------------------------------------------
# 6. Output
# write the interpolated IAM data into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_emissions_filled', '_', RUNSUFFIX )
writeData( iam_em, 'MED_OUT', out_filname, meta = F )  

logStop( )                                                
