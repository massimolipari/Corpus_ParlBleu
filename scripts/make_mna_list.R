library(tidyverse)
library(readxl)
library(tidygeocoder)

# Make MNA list from legislatures.xlsx ------------------------------------

# Set the path for the legislatures.xlsx file
legislatures_path <- './meta/legislatures.xlsx'

# Get the list of sheets
legislatures <- excel_sheets(legislatures_path)

# Create an empty dataframe, loop over sheets and add their contents 
mna <- data.frame()

for (legislature in legislatures){
  temp_data <- read_excel(legislatures_path, sheet = legislature)
  
  mna <- rbind(mna, temp_data)
}

# Save as a CSV
mna %>% 
  write_csv('./meta/legislatures.csv', na = '')

# Create unique, anonymous speaker IDs ------------------------------------

# This algorithm is designed to be infinitely extensible as new MNAs enter 
# parliament. It assumes, however, that names are unique: this currently holds,
# but might break down in the future: in that case, the first part (getting the
# list of unique MNAs) will have to be rewritten. The second part works by
# sorting MNAs first by date of entry into parliament (or beginning of the 36th
# legislature, whichever is later) and second by last name (with accents
# removed and case standardized). Then, we set the seed and sample without
# replacement from the set of 5 digit numbers as many times as there are
# speakers. This way, new MNAs will always be added to the end of the list, and 
# re-doing the ID draw with new MNAs won't affect already assigned IDs. The 
# samifying is also important, so the order won't change if any accents are
# changed later.

# 2024-04-02 Addition: Replace 'Saint'(e) at the beginning of a string with
# 'St'(e). Currently not very safe, but tested and OK for existing names. 

# 2025-09-02 Change: Made algorithm produce same results on macOS as on Windows:
# macOS adds characters for accents rather than just removing them. Apostrophes
# need special handling, since these can appear in names.

# Define a function to get rid of accents and make everything the same case
sameify <- function(string) {
  string %>% 
    str_replace_all("'", '0') %>% # temporary, will be restored later
    iconv(from = 'UTF-8', to = 'ASCII//TRANSLIT') %>% 
    str_replace('^Saint', 'St') %>% 
    str_remove_all("['`^]") %>% 
    str_replace_all('0', "'") %>% 
    str_to_lower()
}

# Read MNA list
mna <- read_csv('./meta/legislatures.csv')

# Get unique MNA list, assuming no homonyms
mna_unique <- mna %>% 
  summarize(du = min(du), .by = c(prénom, nom, nom_complet)) %>% 
  arrange(du,
          nom %>% sameify(),
          prénom %>% sameify(),
          nom,
          prénom)

# Generate a list of IDS
set.seed(76)
id <- sample(seq(10000, 99999), nrow(mna_unique), replace = FALSE)

# Combine the dfs, drop the date column
mna_unique_id <- cbind(mna_unique, id) %>% 
  select(-du) %>% 
  relocate(id)

# Merge in original IDs
original_ids <- read_csv('./meta/original/SpeakerList_fixed.csv', col_names = c('first', 'last', 'id_original')) %>% 
  mutate(name = paste(first, last), .after = last)

mna_original_id <- mna_unique_id %>%
  left_join(original_ids %>% select(name, id_original), by = c('nom_complet' = 'name'))%>% 
  arrange(nom %>% sameify(), prénom %>% sameify(), nom, prénom)

# Save as CSV
mna_original_id %>% write_csv('./meta/id.csv', na = '')


# Create a template biographies CSV ---------------------------------------

# Add columns, remove `du` column
mna_temp <- mna_unique_id %>% 
  arrange(nom %>% sameify(), prénom %>% sameify(), nom, prénom) %>% 
  mutate(genre = NA,
         année_naissance = NA,
         municipalité = NA,
         lieu = NA,
         code = NA)

# Save this list, into which biogrpahical data will be manually entered
mna_temp %>% write_csv('./meta/bios_temp.csv', na = '')


# Add geographic information ----------------------------------------------

# Read in bios file
bios <- read_csv('./meta/bios_man.csv')

# Get list of unique locations
locales <- bios %>% 
  filter(lieu == 'Québec',
         !is.na(municipalité)) %>% 
  select(municipalité, région, lieu) %>% 
  unique() %>% 
  arrange(région %>% sameify(), municipalité %>% sameify())

# Call Nominatim twice first with `county` specified and second without
# Needed because while the administrative region is usually what's coded as 
# `county`, sometimes it's the MRC instead. Also deals with a few exceptions
# Note that the coordinates returned by Nominatim may not be super stable, so
# manual checking of the results is a must (hence the list of exceptions)

locales_osm <- locales %>% 
  geocode(city = municipalité,
          county = région,
          state = lieu) %>% 
  geocode(city = municipalité,
          state = lieu,
          lat = 'lat_fallback',
          long = 'long_fallback')

use_fallback <- c('Jonquière',
                  'Laterrière',
                  'Buckingham',
                  'Quyon',
                  'Duparquet',
                  'Évain',
                  'Taschereau',
                  'La Sarre')

locales_osm_cleaned <- locales_osm %>% 
  mutate(lat = case_when(
    lat %>% is.na() ~ lat_fallback,
    municipalité %in% use_fallback ~ lat_fallback,
    .default = lat
  ),
  long = case_when(
    long %>% is.na() ~ long_fallback,
    municipalité %in% use_fallback ~ long_fallback,
    .default = long
  )) %>% 
  select(-c(lat_fallback, long_fallback))

# Write locales to a file
locales_osm_cleaned %>% write_csv('./meta/locales.csv', na = '')


# Merge biographical data with IDs and geographic info --------------------

mna_bios <- mna_unique_id %>% 
  left_join(bios, by = c('prénom', 'nom', 'nom_complet')) %>% 
  arrange(nom %>% sameify(),
          prénom %>% sameify(),
          nom,
          prénom)

mna_bios %>% write_csv('./meta/bios.csv', na = '')


mna_bios_locales <- mna_bios %>% 
  left_join(locales_osm_cleaned, by = c('municipalité', 'région', 'lieu'))

mna_bios_locales %>% write_csv('./meta/bios_loc.csv', na = '')


# Create a version compatible with PGDB for current corpus version --------

mna_bios_pgdb <- mna_bios %>% 
  relocate(ID_column = id)
  
mna_bios_pgdb %>% write_csv('./meta/bios_pgdb.csv', na = '')


# Sanity checks -----------------------------------------------------------

# For manual inspection of MNA list, check that there are no homonyms
mna_list_check <- mna %>% 
  arrange(nom %>% sameify())

# Check that no ridings are spelled in two different ways
riding_check <- mna$circonscription %>%
  unique() %>% 
  sort()

# Check that each legislature begins with the correct number of people (125,
# unless particular circumstances prevent it)
legislature_check <- mna %>% 
  count(du)

# Check for disagreement between Nominatim calls
locales_check <- locales_osm %>% 
  filter(lat != lat_fallback | long != long_fallback | is.na(lat) | is.na(long))

# Plot all locales with names
locales_osm_cleaned %>% 
  ggplot(aes(x = long, y = lat, label = municipalité)) +
  geom_label(size = 2)
