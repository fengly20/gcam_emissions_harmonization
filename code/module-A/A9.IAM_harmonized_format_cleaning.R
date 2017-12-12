# ------------------------------------------------------------------------------
# Program Name: 
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
log_msg <- "Apply extended offset over interpolated IAM emissions" 
script_name <- "A5.1.IAM_em_harmonazed.R"

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

# extract target IAM info from master mapping 
print( paste0( 'IAM to be processed: ', iam_name ) )  

# -----------------------------------------------------------------------------
# 2. Read in harmonized IAm emissions and reference emissions

iam_em <- readData( 'MED_OUT', paste0( 'A.', iam_name, '_harmonized' ) )

ref_em <- readData( 'MED_OUT', paste0( 'A.', ref_name, '_emissions_aggregated' ) )
ref_em_airshp <- readData( 'MED_OUT', paste0( 'A.', ref_name, '_emissions_airshp_global' ) )

# read in IAMC variable name mapping 
var_mapping <- readData( 'MAPPINGS', 'IAMC_sector_mapping_CEDS16' )


# -----------------------------------------------------------------------------
# 3. Cleaning the format
# consolidate reference emissions
ref_em_all <- rbind( ref_em, ref_em_airshp )
ref_x_years <- paste0( 'X', 2005 : ( as.numeric( base_year ) - 1 ) ) 
ref_em_hist <- ref_em_all[ , c( 'em', 'CEDS16', 'region', ref_x_years ) ]

output_header_cols <- c( 'model', 'scenario', 'region', 'variable', 'unit' )
x_years <- paste0( 'X', base_year : 2100 )
output_x_year <- paste0( 'X', 2005 : 2100 )

iam_em <- iam_em[ , c( 'model', 'scenario', 'em', 'CEDS16', 'region', 'unit', x_years ) ]
iam_em <- merge( iam_em, ref_em_hist, by = c( 'em', 'CEDS16', 'region' ) )

iam_em_iamc <- merge( iam_em, var_mapping, by.x = 'CEDS16', by.y = 'sector', all.x = T )
colnames( iam_em_iamc )[ which( colnames( iam_em_iamc ) == 'IAMC' ) ] <- 'variable'
iam_em_iamc$variable <- unname( mapply( function( var, em ) {
  if ( em == 'SO2' ) { em <- 'Sulfur' }
  if ( em == 'NMVOC' ) { em <- 'VOC' }
  out_var <- gsub( '|XXX|', paste0( '|', em, '|' ), var, fixed = T  )
  return( out_var ) 
  }, iam_em_iamc$variable, iam_em_iamc$em  ) )

iam_em_iamc$unit <- paste0( 'Mt ', iam_em_iamc$em, '/yr' )
iam_em_iamc$unit <- gsub( 'NMVOC', 'VOC', iam_em_iamc$unit, fixed = T )

final_out <- iam_em_iamc[ , c( output_header_cols, output_x_year ) ]
final_out_year <- paste0( 'X', c( 2005, 2010, 2015, 2020, 2030, 2040, 2050, 2060, 2070, 2080, 2090, 2100 ) )
final_out <- final_out[ , c( output_header_cols, final_out_year ) ]
colnames( final_out ) <- gsub( 'X', '', colnames( final_out ) )

# ----------------------------------------------------------------------------
# 4. Output
# write out single file for each scenario
sce_list <- unique( final_out$scenario )

invisible( lapply( sce_list, function( sce ) { 
  temp_df <- final_out[ final_out$scenario == sce, ]
  out_name <- sce
  writeData( temp_df, 'FIN_OUT', domain_extension = "module-A/", out_name, meta = F ) 
  } ) )


# END
