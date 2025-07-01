library(tidyverse)

interpolate_to <- 21

# Read in the original csv
tokens <- read_csv('./proto/vowels_sample_checked.csv')

# Read in the formant measures
acoustics <- data.frame()
sound_dirs <- list.dirs('./proto', recursive = FALSE)

for (d in sound_dirs) {
  d <- d %>%
    paste0('/csvs')
  
  sounds_list <- list.files(d)
  
  for (sound in sounds_list) {
    sound_csv <- read_csv(paste(d, sound, sep = '/')) %>% 
      mutate(sound = sound,
             .before = everything())
    
    sound_csv <- sound_csv %>% 
      mutate(time = time - 0.027,
             .after = time)
    
    acoustics <- acoustics %>% 
      rbind(sound_csv)
  }
}

# Drop unnecessary columns
acoustics <- acoustics %>% 
  select(-c(f1p:f3p))

# Join the datasets
tokens <- tokens %>% 
  mutate(token = row_number())

acoustics <- acoustics %>% 
  mutate(token = sound %>% str_split_i(pattern = '_', i = 1) %>% as.numeric())

tokens <- tokens %>% 
  right_join(acoustics, by = 'token')

# Add relative time measure
tokens <- tokens %>% 
  mutate(time.rel = time / (phone_end - phone_begin),
         .after = time)

if (!interpolate_to %>% is.null()) {
  tokens <- tokens %>% 
    reframe(across(f1:harmonicity,
                   ~ approx(x = time.rel,
                            y = .x,
                            xout = seq(0, 1, length.out = interpolate_to),
                            rule = 2)$y),
            .by = discourse:sound)

  tokens$time.rel <- rep(seq(0, 1, length.out = interpolate_to), nrow(tokens)/interpolate_to)
  
  tokens <- tokens %>% 
    relocate(time.rel,
             .before = f1)
}

# Write output
tokens %>% 
  write_csv('./proto/formants.csv')
