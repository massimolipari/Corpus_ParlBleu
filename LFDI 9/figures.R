library(tidyverse)
library(gt)
library(sf)
library(patchwork)

theme_set(theme_bw())

all_vowels <- read_csv('./extract/ParlBleu_vowels.csv')

bios <- read_csv('./meta/bios.csv') %>% 
  mutate(id = id %>% as.character())


# Figure 1 ----------------------------------------------------------------

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
  ggsave('./LFDI 9/figures/hist.png', ., device = 'png', width = 15.59, height = 5, units = 'cm')


# Figure 2 ----------------------------------------------------------------

qc_land <- readRDS('./etc/geo/qc_land.RDS')
waters_trimmed <- readRDS('./etc/geo/waters.RDS')
qc_boundaries <- readRDS('./etc/geo/qc_land.RDS')

locales <- read_csv('./meta/locales.csv')

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

qc_map %>% 
  ggsave('./LFDI 9/figures/carte.png', ., device = 'png', width = 15.59, height = 8, units = 'cm')


# Figure 3 ----------------------------------------------------------------

iqr <- function(z, lower = 0.25, upper = 0.75) {
  data.frame(
    y = median(z),
    ymin = quantile(z, lower),
    ymax = quantile(z, upper)
  )
}

manual_measures <- read_csv('proto/formants.csv') %>% 
  filter(time.rel == 0.5) %>% 
  rename_with(.fn = ~ str_to_upper(.x) %>% paste0('_man'), .cols = c(f1, f2, f3))

check_measures <- all_vowels %>% 
  filter(time == 0.5) %>% 
  select(c(discourse, speaker, phone, phone_begin, F1, F2, F3)) %>% 
  rename_with(.fn = ~ str_to_upper(.x) %>% paste0('_auto'), .cols = c(F1, F2, F3)) %>% 
  right_join(manual_measures, by = c('discourse', 'speaker', 'phone', 'phone_begin'))

check_measures <- check_measures %>% 
  mutate(phone = phone %>% fct_relevel(vowelset)) %>% 
  arrange(phone)

check_measures <- check_measures %>% 
  mutate(F1_diff = F1_auto - F1_man,
         F2_diff = F2_auto - F2_man,
         F3_diff = F3_auto - F3_man)

check_measures_long <- check_measures %>%
  select(speaker, phone, F1_man, F2_man, F3_man, F1_auto, F2_auto, F3_auto) %>%
  pivot_longer(cols = F1_man:F3_auto,
               names_to = c('formant', '.value'),
               names_sep = '_')

check_plot <- check_measures_long %>% 
  ggplot(aes(x = man, y = auto)) +
  geom_abline(slope = 1, colour = 'red') +
  geom_point(alpha = 0.2, size = 0.4) +
  facet_wrap(~formant,
             scales = 'free',
             ncol = 1,
             strip.position = 'right') +
  labs(x = 'Mesure manuelle (Hz)',
       y = 'Mesure automatique (Hz)') +
  theme(strip.text = element_blank())

diff_plot <- check_measures_long %>% 
  mutate(diff.abs = abs(auto - man)) %>% 
  left_join(data.frame('formant' = c('F1', 'F2', 'F3'), ref_error = c(10, 20, NA))) %>% 
  ggplot(aes(x = phone, y = diff.abs)) +
  stat_summary(fun.data = iqr, size = 0.1) +
  geom_hline(aes(yintercept = ref_error), lty = 'dashed', linewidth = 0.75, colour = 'red') +
  facet_wrap(~formant, scales = 'free', ncol = 1, strip.position = 'right') +
  labs(x = 'Voyelle',
       y = 'Différence absolue (Hz)')

valid <- check_plot + diff_plot

valid %>% 
  ggsave('./LFDI 9/figures/valid.png', ., device = 'png', width = 15.59, height = 12, units = 'cm')


# Figure 4 ----------------------------------------------------------------

# Préparation des données
vowelset <- c('i', 'e', 'ɛ', 'ɜ', 'a', 'y', 'ø', 'ə', 'œ', 'u', 'o', 'ɔ', 'ɑ', 'ɛ\U0303', 'œ\U0303', 'ɔ\U0303', 'ɑ\U0303')

vowels <- all_vowels %>% 
  filter(phone %in% vowelset,
         phone_duration >= 0.05,
         phone_duration <= 0.5) %>% 
  mutate(phone = phone %>% fct_relevel(vowelset),
         speaker = speaker %>% as.character)

lax_sub <- c('i' = 'ɪ',
             'y' = 'ʏ',
             'u' = 'ʊ')

vowels_finalsyll <- vowels %>% 
  filter(syllable_end == word_end) %>% 
  mutate(allophone = case_when((!phone %in% c('ɛ\U0303', 'œ\U0303', 'ɔ\U0303', 'ɑ\U0303', 'ɑ', 'ɜ', 'ɛ', 'o', 'ø')) &
                                 (following_phone %in% c('v', 'z', 'ʒ', 'ʁ')) &
                                 (transcription %>% str_detect('[vzʒʁ]$|v\\.ʁ$')) &
                                 (phone_end != syllable_end) ~ paste0(phone, 'ː'),
                               (phone == 'ɑ') & (phone_end == word_end) ~ 'ɑ',
                               (phone %in% c('i', 'y', 'u')) &
                                 (phone_end != syllable_end) ~ str_replace_all(phone, lax_sub),
                               (phone %in% c('o', 'ø', 'ɑ')) &
                                 (phone_end != syllable_end) ~ paste0(phone, 'ː'),
                               TRUE ~ phone),
         length = case_when(allophone %>% str_detect('[ːɜ]') ~ 'long',
                            allophone %>% str_detect('\U0303') ~ 'nasal',
                            TRUE ~ 'short') %>% as.factor() %>% fct_relevel(c('short', 'long', 'nasal'))) %>% 
  filter(!allophone %in% c('eː', 'əː', 'ʊː'))

allophone_set <- c('i', 'iː', 'ɪ', 'e', 'ɛ', 'ɜ', 'a', 'aː', 'y', 'yː', 'ʏ', 'ø', 'øː', 'ə', 'œ', 'œː', 'u', 'uː', 'ʊ', 'o', 'oː', 'ɔ', 'ɔː', 'ɑ', 'ɑː', 'ɛ\U0303', 'œ\U0303', 'ɔ\U0303', 'ɑ\U0303')

vowels_finalsyll <- vowels_finalsyll %>% 
  mutate(allophone = allophone %>% fct_relevel(allophone_set))

vowels_finalsyll <- vowels_finalsyll %>% 
  left_join(bios,
            by = c('speaker' = 'id')) %>% 
  filter(lieu == 'Québec')

speaker_means <- vowels_finalsyll %>% 
  summarize(across(F1:F3,
                   ~ mean(.x, na.rm = TRUE)),
            .by = c(time, allophone, word, speaker, genre, length)) %>% 
  summarize(across(F1:F3,
                   ~ mean(.x, na.rm = TRUE)),
            .by = c(time, allophone, speaker, genre, length))

gender_means <- speaker_means %>% 
  summarize(across(F1:F3,
                   c('mean' = ~ mean(.x, na.rm = TRUE),
                     'sd' = ~ sd(.x, na.rm = TRUE))),
            .by = c(time, allophone, genre, length))

# Espace vocalique

dummy <- rbind(gender_means %>% 
                 summarize(F1_mean = min(F1_mean) - 0.5 * sd(F1_mean),
                           F2_mean = min(F2_mean) - 0.5 * sd(F2_mean),
                           F3_mean = min(F3_mean) - 0.5 * sd(F3_mean),
                           allophone = NA,
                           .by = c(genre, time)),
               gender_means %>% 
                 summarize(F1_mean = max(F1_mean) + 0.9 * sd(F1_mean),
                           F2_mean = max(F2_mean) + 0.7 * sd(F2_mean),
                           F3_mean = max(F3_mean) + 0.5 * sd(F3_mean),
                           allophone = NA,
                           .by = c(genre, time))) %>% 
  filter(time == 0.5)


f1xf2_short <- gender_means %>% 
  filter(length == 'short', time == 0.5) %>% 
  ggplot(aes(x = F2_mean, y = F1_mean, colour = allophone)) +
  stat_ellipse(data = speaker_means %>% filter(length == 'short', time == 0.5),
               aes(x = F2, y = F1), level = 0.68, alpha = 0.25) +
  geom_text(aes(label = allophone), size = 3.5) +
  scale_x_reverse() +
  scale_y_reverse() +
  labs(x = 'F2 (Hz)',
       y = 'F1 (Hz)') +
  theme(legend.position = 'none') +
  geom_blank(data = dummy) +
  facet_wrap(~ genre,
             scales = 'free',
             labeller = c('f' = 'Femmes', 'm' = 'Hommes') %>% as_labeller(),
             ncol = 1,
             strip.position = 'right') +
  theme(strip.text = element_blank())

f1xf2_long <- gender_means %>% 
  filter(length == 'long', time == 0.5) %>% 
  ggplot(aes(x = F2_mean, y = F1_mean, colour = allophone)) +
  stat_ellipse(data = speaker_means %>% filter(length == 'long', time == 0.5),
               aes(x = F2, y = F1), level = 0.68, alpha = 0.25) +
  geom_text(aes(label = allophone), size = 3.5) +
  scale_x_reverse() +
  scale_y_reverse() +
  labs(x = 'F2 (Hz)',
       y = 'F1 (Hz)') +
  theme(legend.position = 'none') +
  geom_blank(data = dummy) +
  facet_wrap(~ genre,
             scales = 'free',
             labeller = c('f' = 'Femmes', 'm' = 'Hommes') %>% as_labeller(),
             ncol = 1,
             strip.position = 'right') +
  theme(strip.text = element_blank())

f1xf2_nasal <- gender_means %>% 
  filter(length == 'nasal', time == 0.5) %>% 
  ggplot(aes(x = F2_mean, y = F1_mean, colour = allophone)) +
  stat_ellipse(data = speaker_means %>% filter(length == 'nasal', time == 0.5),
               aes(x = F2, y = F1), level = 0.68, alpha = 0.25) +
  geom_text(aes(label = allophone), size = 3.5) +
  scale_x_reverse() +
  scale_y_reverse() +
  labs(x = 'F2 (Hz)',
       y = 'F1 (Hz)') +
  theme(legend.position = 'none') +
  geom_blank(data = dummy) +
  facet_wrap(~ genre,
             scales = 'free',
             labeller = c('f' = 'Femmes', 'm' = 'Hommes') %>% as_labeller(),
             ncol = 1,
             strip.position = 'right')

f1xf2 <- (f1xf2_short + f1xf2_long + f1xf2_nasal) +
  plot_layout(axes = 'collect')

f1xf2 %>% 
  ggsave('LFDI 9/figures/f1xf2.png', ., device = 'png', width = 15.59, height = 10, units = 'cm')


# Figure 5 ----------------------------------------------------------------

f3 <- gender_means %>% 
  filter(time == 0.5) %>% 
  ggplot(aes(x = allophone, y = F3_mean, colour = allophone)) +
  geom_pointrange(aes(ymin = F3_mean - F3_sd,
                      ymax = F3_mean + F3_sd),
                  size = 0.25) +
  theme(legend.position = 'none') +
  labs(x = 'Voyelle',
       y = 'F3 (Hz)') +
  facet_wrap(~ genre,
             scales = 'free',
             labeller = c('f' = 'Femmes', 'm' = 'Hommes') %>% as_labeller(),
             ncol = 1,
             strip.position = 'right')

f3 %>% 
  ggsave('./LFDI 9/figures/f3.png', ., device = 'png', width = 15.59, height = 10, units = 'cm')


# Tableau 1 ---------------------------------------------------------------

old_data <- read_csv('extract/AssNat_speech_breakdown.csv') %>% 
  rename(old_data = duration) %>% 
  filter(speaker != '010') # Non-native speaker with < 2s of data, none of which was successfully aligned

new_data <- read_csv('extract/exp_speech_breakdown.csv') %>% 
  rename(new_data = duration) %>% 
  mutate(speaker = speaker %>% as.character())

ids <- read_csv('meta/id.csv') %>% 
  mutate(id_original = id_original %>% { if_else(is.na(.), NA, sprintf('%03d', .)) } )

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
  gtsave('./LFDI 9/figures/parlementaires.docx')
