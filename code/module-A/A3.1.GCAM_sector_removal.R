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
log_msg <- "xx" 
script_name <- ""

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

# this script is for GCAM emissions only 
if ( iam != 'GCAM4' ) { stop( 'This script is for GCAM SO2 emissions only! ' ) }

# read in master config file 
master_config <- readData( 'MAPPINGS', 'master_config', column_names = F )
# select iam configuration line from the mapping and read the iam information as a list 
iam_info_list <- iamInfoExtract( master_config, iam )

x_baseyear <- paste0( 'X', base_year )

# ------------------------------------------------------------------------------
# 2. Read in 
iam_em <- readData( domain = 'MED_OUT', file_name = paste0( 'A.', iam_name, '_emissions_aggregated' ) )
ref_em <- readData( domain = 'MED_OUT', file_name = 'A.CEDS_emissions_aggregated' )

# extra step to convert iam_em into numeric 
iam_em_xyear <- colnames( iam_em )[ grep( '^X', colnames( iam_em ) ) ]
iam_em_header_cols <- colnames( iam_em )[ grep( '^X', colnames( iam_em ), invert = T ) ]
iam_em_xyear_data <- data.frame( as.matrix( sapply( iam_em[ , iam_em_xyear ], as.numeric ) ) )  
iam_em <- cbind( iam_em[ , iam_em_header_cols ], iam_em_xyear_data )

# ------------------------------------------------------------------------------
# 3. GCAM emission sector removal 
# GCAM does not report emissions for some IAMC CEDS16 sectors so remove those sectors 
# from GCAM emission complete layout. 
# The process contains two parts: (1) sector removal for non-CO2 emissions (section 3.1);
#                                 (2) sector removal for CO2 emissions (see section 3.2 for details). 
# 3.1 GCAM sector removal for non-CO2 emissions 
sectors_to_remove <- c( 'Peat Burning', 'Other Fugitive/Flaring', 'International Shipping - Tanker Loading' )
iam_em <- iam_em[ iam_em$CEDS16 %!in% sectors_to_remove, ]

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
  if ( iam_em[ each_row,  'CEDS16' ] %in% sectors_to_remove & iam_em[ each_row,  'em' ] == 'CO2' ) { 
    removal_row_index <- c( removal_row_index, each_row ) }
  }
iam_em$row_index <- 1 : nrow( iam_em )
iam_em <- iam_em[ iam_em$row_index %!in% removal_row_index, ]
iam_em$row_index <- NULL 

# 3.2.2 CO2 transportation treatment
iam_em$CEDS16 <- ifelse( ( iam_em$CEDS16 == 'Road Transportation' & iam_em$em == 'CO2' ), 'Transportation Sector', iam_em$CEDS16 )

# divide ref_em into 3 parts: non-CO2, CO2-non-transportation, CO2-transportation 
ref_em_part1 <- ref_em[ ref_em$em != 'CO2', ]
ref_em_part2 <- ref_em[ ref_em$em == 'CO2' & ref_em$CEDS16 %!in% c( "Non-Road Transportation", "Road Transportation" ), ]
ref_em_part3 <- ref_em[ ref_em$em == 'CO2' & ref_em$CEDS16 %in% c( "Non-Road Transportation", "Road Transportation" ), ] 
ref_em_part3_colnames <- colnames( ref_em_part3 )
ref_em_part3_xyears <- grep( 'X', ref_em_part3_colnames, fixed = T, value = T )
ref_em_part3_headers <- grep( 'X', ref_em_part3_colnames, fixed = T, value = T, invert = T  )
ref_em_part3 <- aggregate( ref_em_part3[ ref_em_part3_xyears ], by = list( ref_em_part3$ref_em, ref_em_part3$em, ref_em_part3$region, ref_em_part3$unit ), FUN = sum ) 
colnames( ref_em_part3 ) <- c( c( 'ref_em', 'em', 'region', 'unit' ), ref_em_part3_xyears )
ref_em_part3$CEDS16 <- 'Transportation Sector'
ref_em_part3 <- ref_em_part3[ , ref_em_part3_colnames ]

ref_em <- rbind( ref_em_part1, ref_em_part2, ref_em_part3 )

# ------------------------------------------------------------------------------
# 6. Output
# write the interpolated IAM data into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_emissions_filled' )
writeData( iam_em, 'MED_OUT', out_filname, meta = F )  
                                                
out_filname <- paste0( 'A.', ref_name, '_emissions_aggregated' )
writeData( ref_em, 'MED_OUT', out_filname, meta = F  )  
