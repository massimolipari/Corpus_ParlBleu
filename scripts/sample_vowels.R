library(tidyverse)
set.seed(76)

# Load the datasets
vowels <- read_csv('extract/AssNat_vowels.csv')
bios <- read_csv('meta/bios.csv')

# Drop tokens that are too short for good measures, from English borrowings
vowels_sub <- vowels %>% 
  filter(phone_duration >= 0.05,
         !phone %in% c('ɪ', 'ʊ'))

vowels_sub <- vowels_sub %>% 
  left_join(bios, by = c('speaker' = 'id')) %>% 
  relocate(prénom:lieu, .after = speaker)

# Future proofing, in case a larger sample is desired later
vowels_sample_full <- vowels_sub %>% 
  slice_sample(n = 500,
               by = c(genre, phone))

# Get the actual sample for prototypes
vowels_sample <- vowels_sample_full %>% 
  slice_head(n = 75,
             by = c(genre, phone))
  
# Drop the speaker info
vowels_sample <- vowels_sample %>% 
  select(-c(prénom:lieu))

# Save the sample
vowels_sample %>% 
  write_csv('proto/vowels_sample.csv')
