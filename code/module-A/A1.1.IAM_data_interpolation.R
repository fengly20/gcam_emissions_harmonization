# ------------------------------------------------------------------------------
# Program Name: A1.1.IAM_data_interpolation.R
# Author(s): Leyang Feng
# Date Last Updated: Nov 16, 2016 
# Program Purpose: Read in IAM data according to variable list file and interpolate IAM values. 
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
log_msg <- "Read in and interpolate IAM values" 
script_name <- "A1.1.IAM_data_interpolation.R"

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
print( paste0( 'Method for IAM data interpolation: ', iam_interpolation_method ) ) 

# read in variable list 
variable_list <- readData( domain = 'MAPPINGS', file_name = iam_variable_list ) 
if ( exists( 'harm_method_specific_mapping' ) ) { 
  harm_method_mapping <- readData( domain = 'MAPPINGS', file_name = harm_method_specific_mapping ) 
  }

# ------------------------------------------------------------------------------
# 2. Read in IAM data 
# list IAM data files 
iam_file_list <- list.files( iam_path )
iam_file_ext <- getFileExt( iam_file_list )
iam_file_list <- file_path_sans_ext( iam_file_list )

# de-select metadata
if ( length( grep( pattern = "metadata", iam_file_list ) ) > 0 )
      iam_file_list <- iam_file_list[ -grep( pattern = "metadata", iam_file_list ) ]

# read in iam data 
if ( iam_file_ext == 'csv' ) { 
  
  data_list <- lapply( iam_file_list, function( iam_file ) { 
    # read in the data for each single file 
    df <- readData( domain = 'IAM_EM', 
                    file_name = iam_file, 
                    domain_extension = iam_domain_extension )
    # keep only desired variables from variable_list
    df <- df[ df$Variable %in% variable_list$variable, ]
    return( df )
    } )
  iam_data <- do.call( "rbind.fill", data_list ) 
  colnames( iam_data ) <- tolower( colnames( iam_data )  )
}

if ( iam_file_ext == 'xlsx' ) { 
  data_list <- lapply( iam_file_list, function( iam_file ) { 
    # read in the data for each single file 
    df <- readData( domain = 'IAM_EM', 
                    file_name = iam_file, 
                    domain_extension = iam_domain_extension,
                    extension = '.xlsx', 
                    sheet_selection = iam_sheet_name )
    # keep only desired variables from variable_list
    df <- df[ df$Variable %in% variable_list$variable, ]
    return( df )
    } )
iam_data <- do.call( "rbind.fill", data_list ) 
colnames( iam_data ) <- tolower( colnames( iam_data )  )
colnames( iam_data )[ 6 : 17 ] <- paste0( 'x', colnames( iam_data )[ 6 : 17 ] )
}

# -----------------------------------------------------------------------------
# 3. interpolate iam_data 

# extract the begining year and end year of IAM data 
iam_col_names <- colnames( iam_data )
iam_x_years <- grep( 'x', iam_col_names, value = T )
iam_year_start <- as.numeric( substr( ( iam_x_years[ 1 ] ), 2, 5 ) )
iam_year_end <- as.numeric( substr( iam_x_years[ length( iam_x_years ) ], 2, 5 ) )

# add X_years that need a interpolated value into the data frame
X_iam_years_int <- paste0( 'x', iam_year_start : iam_year_end )
X_iam_years_int_fill <- X_iam_years_int[ which( !( X_iam_years_int %in% iam_x_years ) ) ] 
iam_data_int <- iam_data
iam_data_int[ X_iam_years_int_fill ] <- NA
iam_data_int <- iam_data_int[ , c(  'model', 'scenario', 'region', 'variable', 'unit', X_iam_years_int ) ]
colnames( iam_data_int ) <- c(  'model', 'scenario', 'region', 'variable', 'unit', toupper( X_iam_years_int ) )

# do the interpolation on the X_years 
iam_data_int <- interpolateXyears( iam_data_int, int_method = iam_interpolation_method )


# ------------------------------------------------------------------------------
# 4. Output
# write the interpolated IAM data into the intermediate-output folder 
out_filname <- paste0( 'A.', iam, '_data_interpolated' )
writeData( iam_data_int, 'MED_OUT', out_filname, meta = F )  



# END
