library(tidyverse)

vocab <- read_tsv('./etc/vocabulary.tsv')

vocab_distinct <- vocab %>% 
  distinct()


vocab_distinct <- vocab_distinct %>% 
  arrange(word) %>% 
  filter(transcription %>% str_detect('spn', negate = TRUE),
         transcription %>% str_detect('sil', negate = TRUE),
         transcription %>% str_detect('cg', negate = TRUE),
         transcription %>% str_detect('ns', negate = TRUE),
         transcription %>% str_detect('sp', negate = TRUE))


# un ----------------------------------------------------------------------

un <- vocab_distinct %>% 
  filter(transcription %>% 
           str_detect('ɛ\U0303')) %>% 
  mutate(index = transcription %>% 
           str_locate_all('ɛ\U0303') %>% 
           map(~ .x[,1] %>% as.character())) %>% 
  unnest_wider(index, names_sep = '.') %>% 
  mutate(across(c(index.1, index.2),
                ~ str_sub(transcription, 1, .x) %>% str_count('\\.') + 1)) %>% 
  pivot_longer(cols = c('index.1', 'index.2'),
               names_to = c(),
               values_to = 'index',
               values_drop_na = TRUE) %>% 
  mutate(round = NA)

un %>% 
  write_csv('./etc/un_template.csv', na = "")


# ɜ -----------------------------------------------------------------------

long_E <- vocab_distinct %>% 
  filter(transcription %>% str_detect('ɛ([^\U0303]+|$)')) %>% 
  mutate(index = transcription %>% 
           str_locate_all('ɛ') %>% 
           map(~ .x[,1] %>% as.character())) %>% 
  unnest_wider(index, names_sep = '.') %>% 
  mutate(across(c(index.1, index.2, index.3, index.4),
                ~ str_sub(transcription, 1, .x) %>% str_count('\\.') + 1)) %>% 
  pivot_longer(cols = c('index.1', 'index.2', 'index.3', 'index.4'),
               names_to = c(),
               values_to = 'index',
               values_drop_na = TRUE) %>% 
  mutate(long = NA)

long_E %>% 
  write_csv('./etc/E_template.csv', na = "")


# Scripted ɑ --------------------------------------------------------------

long_a <- vocab_distinct %>% 
  filter(transcription %>% str_detect('a')) %>% 
  mutate(index = transcription %>% 
           str_locate_all('a') %>% 
           map(~ .x[,1] %>% as.character())) %>% 
  unnest_wider(index, names_sep = '.') %>% 
  mutate(across(c(index.1, index.2, index.3),
                ~ str_sub(transcription, 1, .x) %>% str_count('\\.') + 1)) %>% 
  pivot_longer(cols = c('index.1', 'index.2', 'index.3'),
               names_to = c(),
               values_to = 'index',
               values_drop_na = TRUE) %>% 
  mutate(index = NA)

long_a %>% 
  write_csv('./etc/a_template.csv', na = '')
