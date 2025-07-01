library(tidyverse)
library(gt)
library(sf)

theme_set(theme_bw())

# Speaker table -----------------------------------------------------------

old_data <- read_csv('extract/AssNat_speech_breakdown.csv') %>% 
  rename(old_data = duration) %>% 
  filter(speaker != '010') # Non-native speaker with < 2s of data, none of which was successfully aligned

new_data <- read_csv('extract/exp_speech_breakdown.csv') %>% 
  rename(new_data = duration) %>% 
  mutate(speaker = speaker %>% as.character())

ids <- read_csv('meta/id.csv') %>% 
  mutate(id_original = id_original %>% { if_else(is.na(.), NA, sprintf('%03d', .)) } )

bios <- read_csv('meta/bios.csv') %>% 
  mutate(id = id %>% as.character())

old_data <- old_data %>% 
  left_join(ids, by = c('speaker' = 'id_original')) %>% 
  summarize(old_data = sum(old_data),
            .by = id) %>% 
  mutate(id = id %>% as.character())

data_duration <- old_data %>% 
  full_join(new_data,
            by = c('id' = 'speaker'))

data_duration <- data_duration %>% 
  left_join(bios, by = 'id') %>% 
  select(-c(`prénom`:nom_complet))

data_duration <- data_duration %>% 
  relocate(old_data:new_data, .after = everything())

data_duration <- data_duration %>% 
  arrange(is.na(old_data), annee_naissance, genre)

speaker_table <- data_duration %>% 
  select(-région) %>% 
  gt(rowname_col = 'id') %>% 
  tab_stubhead(label = 'Locutaire (code)') %>% 
  cols_label(genre = 'Genre',
             annee_naissance = 'Année de naissance',
             municipalité = 'Lieu de naissance',
             old_data = 'Corpus original',
             new_data = 'Expansion') %>% 
  tab_spanner(label = 'Quantité de données', columns = c(old_data, new_data)) %>% 
  fmt(columns = genre, fns = toupper) %>% 
  fmt_duration(columns = c(old_data, new_data), input_units = 'seconds', output_units = c('hours', 'minutes')) %>% 
  grand_summary_rows(columns = c(old_data, new_data),
                     fns = Total ~ sum(., na.rm = TRUE),
                     missing_text = '',
                     fmt = ~ fmt_duration(., input_units = 'seconds', output_units = c('hours', 'minutes'))) %>% 
  cols_merge(columns = c(municipalité, lieu),
             pattern = '{1} ({2})') %>% 
  sub_missing(columns = c(annee_naissance, municipalité), missing_text = '?') %>% 
  sub_missing(columns = c(old_data, new_data), missing_text = '—') %>% 
  cols_align(columns = c(id, genre, annee_naissance), align = 'center')

speaker_table %>% 
  gtsave('./etc/figs/speakers.docx')


# Map ---------------------------------------------------------------------

qc_land <- readRDS('./etc/geo/qc_land.RDS')
waters_trimmed <- readRDS('./etc/geo/waters.RDS')
qc_boundaries <- readRDS('./etc/geo/qc_land.RDS')

locales <- read_csv('meta/locales.csv')

data_locales <- data_duration %>% 
  filter(!(is.na(municipalité) | is.na(région))) %>% 
  left_join(locales) %>% 
  count(municipalité, lat, long) %>% 
  mutate(n.fct = n %>% cut(breaks = c(0, 1, 6, 11, 16, 35),
                           labels = c('1', '2 à 5', '6 à 10', '11 à 15', '> 15'))) %>% 
  arrange(n.fct) %>% 
  st_as_sf(coords = c('long', 'lat'),
           crs = 'EPSG:4326',
           na.fail = FALSE)

map_xlims <- c(min(st_coordinates(data_locales$geometry)[,1]),
               max(st_coordinates(data_locales$geometry)[,1]))

map_ylims <- c(min(st_coordinates(data_locales$geometry)[,2]),
               max(st_coordinates(data_locales$geometry)[,2]))

# Colourblind-friendly colours from Paul Tol
qc_map <- ggplot() +
  geom_sf(data = waters_trimmed, colour = NA, fill = '#CCEEFF') +
  geom_sf(data = qc_land, fill = '#EEEEBB', colour = NA) +
  geom_sf(data = qc_boundaries, fill = NA, alpha = 0.2) +
  geom_sf(data = data_locales, aes(fill = n.fct, size = n.fct), alpha = 0.7, shape = 21) +
  scale_fill_discrete(type = c('#0077BB', '#009988', '#EE3377', '#EE7733', '#CC3311')) +
  coord_sf(xlim = map_xlims,
           ylim = map_ylims) +
  labs(fill = 'Nombre de parlementaires',
       size = 'Nombre de parlementaires') +
  theme_void() +
  theme(panel.background = element_rect(fill = '#DDDDDD', colour = '#DDDDDD'),
        legend.position = 'bottom',
        legend.key = element_blank(),
        legend.box = 'vertical')

# c('#EE7733', '#0077BB', '#EE3377', '#CC3311', '#009988') c('#009988', '#CC3311', '#EE3377', '#0077BB', '#EE7733')

qc_map %>% 
  ggsave('fig/map.png', ., device = 'png', width = 15.59, height = 8, units = 'cm')


# Histogram of birth years ------------------------------------------------

native <- data_duration %>% 
  filter(lieu == 'Québec')

yob_hist <- native %>% 
  ggplot(aes(x = annee_naissance, fill = genre)) +
  geom_histogram(binwidth = 1, colour = 'black', linewidth = 0.25) +
  scale_fill_discrete(labels = c('Femmes', 'Hommes'), type = c('#EE3377', '#0077BB')) +
  geom_vline(xintercept = median(native$annee_naissance, na.rm = TRUE), lty = 3) +
  labs(x = 'Année de naissance',
       y = 'Nombre de\nparlementaires',
       fill = 'Genre')

yob_hist %>% 
  ggsave('fig/yob_hist.png', ., device = 'png', width = 15.59, height = 5, units = 'cm')


# Acoustics table ---------------------------------------------------------

vowelset <- c('i', 'e', 'ɛ', 'ɛ\U0303', 'ɜ', 'a', 'y', 'ø', 'ə', 'œ', 'œ\U0303', 'u', 'o', 'ɔ', 'ɔ\U0303', 'ɑ', 'ɑ\U0303')

all_vowels <- read_csv('extract/ParlBleu_vowels.csv')

vowels <- all_vowels %>% 
  filter(phone %in% vowelset,
         phone_duration >= 0.05,
         phone_duration <= 0.5) %>% 
  mutate(phone = phone %>% fct_relevel(vowelset),
         speaker = speaker %>% as.character)

vowels <- vowels %>% 
  left_join(bios,
            by = c('speaker' = 'id')) %>% 
  filter(lieu == 'Québec')

vowels_for_dur <- all_vowels %>%
  filter(phone %in% vowelset) %>% 
  mutate(phone = phone %>% fct_relevel(vowelset),
         speaker = speaker %>% as.character) %>% 
  left_join(bios,
            by = c('speaker' = 'id')) %>% 
  filter(lieu == 'Québec')


# Create datasets with mean and sd calculations
speaker_means <- vowels %>% 
  summarize(across(F1:F3,
                   ~ mean(.x, na.rm = TRUE)),
            .by = c(time, phone, word, speaker, genre)) %>% 
  summarize(across(F1:F3,
                   ~ mean(.x, na.rm = TRUE)),
            .by = c(time, phone, speaker, genre))

gender_means <- speaker_means %>% 
  summarize(across(F1:F3,
                   c('mean' = ~ mean(.x, na.rm = TRUE),
                     'sd' = ~ sd(.x, na.rm = TRUE))),
            .by = c(time, phone, genre))

# pop_means <- speaker_means %>% 
#   summarize(across(F1:F3,
#                    c('mean' = ~ mean(.x, na.rm = TRUE),
#                      'sd' = ~ sd(.x, na.rm = TRUE))),
#             .by = c(time, phone))

# Same, but for duration measures
speaker_dur_means <- vowels_for_dur %>% 
  mutate(duration = phone_duration * 1000) %>% 
  select(-phone_duration) %>% 
  summarize(across(c(duration),
                   ~ mean(.x, na.rm = TRUE)),
            .by = c(phone, word, speaker, genre)) %>% 
  summarize(across(c(duration),
                   ~ mean(.x, na.rm = TRUE)),
            .by = c(phone, speaker, genre))

gender_dur_means <- speaker_dur_means %>% 
  summarize(across(c(duration),
                   c('mean' = ~ mean(.x, na.rm = TRUE),
                     'sd' = ~ sd(.x, na.rm = TRUE))),
            .by = c(phone, genre))

# Create the single table, pivot wider
acoustics_summary <- gender_means %>% 
  filter(time == 0.5) %>% 
  left_join(gender_dur_means, by = c('phone', 'genre')) %>% 
  select(-time) %>% 
  arrange(phone, genre) %>%
  pivot_longer(cols = c(F1_mean:duration_sd),
               names_to = c('.value', 'statistic'),
               names_sep = '_') %>% 
  pivot_wider(names_from = genre,
             values_from = c(F1:duration)) %>% 
  pivot_wider(names_from = statistic,
              values_from = F1_f:duration_m)

acoustics_summary %>% 
  gt() %>% 
  fmt_number(decimals = 0) %>% 
  cols_merge(columns = starts_with('F1_f'),
             pattern = '{1}\n({2})') %>% 
  cols_merge(columns = starts_with('F1_m'),
           pattern = '{1}\n({2})')


# Vowel plots -------------------------------------------------------------
  
# By-gender vowel spaces
mid_f1xf2 <- gender_means %>% 
  filter(time == 0.5) %>% 
  ggplot(aes(x = F2_mean, y = F1_mean, colour = phone)) +
  stat_ellipse(data = speaker_means %>% filter(time == 0.5),
               aes(x = F2, y = F1), level = 0.68, alpha = 0.25) +
  geom_text(aes(label = phone), size = 4) +
  scale_x_reverse() +
  scale_y_reverse() +
  labs(x = 'F2 (Hz)',
       y = 'F1 (Hz)') +
  theme(legend.position = 'none') +
  facet_wrap(~genre,
             scales = 'free',
             labeller = c('f' = 'Femmes', 'm' = 'Hommes') %>% as_labeller())

mid_f1xf2 %>% 
  ggsave('fig/midf1xf2.png', ., device = 'png', width = 15.59, height = 8, units = 'cm')

gender_means %>% 
  filter(time >= 0.25 & time <= 0.75) %>% 
  ggplot(aes(x = F2_mean, y = F1_mean, colour = phone)) +
  geom_path(arrow = arrow(length = unit(0.25, 'cm'), type = 'closed')) +
  scale_x_reverse() +
  scale_y_reverse() +
  labs(x = 'F2 (Hz)',
       y = 'F1 (Hz)') +
  theme(legend.position = 'none') +
  facet_wrap(~genre,
             scales = 'free',
             labeller = c('f' = 'Femmes', 'm' = 'Hommes') %>% as_labeller())

mid_f3 <- gender_means %>% 
  filter(time == 0.5) %>% 
  ggplot(aes(x = phone, y = F3_mean, colour = phone)) +
  geom_pointrange(aes(ymin = F3_mean - F3_sd,
                      ymax = F3_mean + F3_sd)) +
  theme(legend.position = 'none') +
  labs(x = element_blank(),
       y = 'F3 (Hz)') +
  facet_wrap(~genre,
             scales = 'free',
             labeller = c('f' = 'Femmes', 'm' = 'Hommes') %>% as_labeller())

mid_f3 %>% 
  ggsave('fig/midf3.png', ., device = 'png', width = 15.59, height = 8, units = 'cm')
