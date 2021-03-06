library(magrittr)
library(keras)
use_backend("tensorflow")
#install_keras()

### To train a new model, put desired classes into "classes" vector and
##### change the date in name.file() (and other variables, if appropriate)

gpu <- F
classes <- c("bowtie", "chevron", "circle", "hexagon", "line",
             "pentagon", "quad", "star", "text", "triangle")

name.file <- function(mod_num, ext) {
  work_dir <- ifelse(gpu, "/work/CSAFE/", "~/shoe_nnet/")
  mod_type_dir = "shoe_models/OneHot/"
  path <- paste(work_dir, mod_type_dir, sep = "")
  
  ### Change these if global variables change
  date = "092518_"
  pretrained_base = "vgg16_"
  mod_type = "onehotaug_"
  nclass = paste(length(classes), "class_", sep="")
  pixel_size = "256_"
  if (mod_num == 0) {
    pixel_size = "256"
    mod_num <- ""}
  
  filename <- paste(date, pretrained_base, mod_type, nclass, 
                    pixel_size, as.character(mod_num), sep = "")
  
  return(paste(path, filename, ext, sep = ""))
}

conv_base <- application_vgg16(
  weights = "imagenet",
  include_top = FALSE,
  input_shape = c(256, 256, 3)
)


### base_dir should contain the train, validation, 
##### and test folders of desired images

base_dir <- ifelse(gpu, "/work/CSAFE/shoes/onehot", "~/shoe_nnet/shoes/onehot")
# train_dir <- file.path(base_dir, "train")
train_dir <- file.path(base_dir, "train_aug")
validation_dir <- file.path(base_dir, "validation")
test_dir <- file.path(base_dir, "test")


### This code configures new images into folders for model training.
##### It randomizes original images into train (50%), validation (25%), and
##### test (25%) images. For a new set of images, change "all.images.folder"
##### to reflect path containing all images (before sorting).

# dir.create(train_dir)
# dir.create(validation_dir)
# dir.create(test_dir)

# all.images.folder <- "~/shoe_nnet/shoes/original data/OneHotTestV2"
# all.files <- list.files(all.images.folder) %>%
#   paste(all.images.folder, ., sep = "/")
# n <- length(all.files)
# 
# set.seed(1)
# fnames <- all.files[sample(1:n)]
# file.copy(fnames[1:round(n/2)], train_dir)
# file.copy(fnames[(round(n/2)+1):round(3*n/4)], validation_dir)
# file.copy(fnames[(round(3*n/4)+1):n], test_dir)


#datagen <- image_data_generator(rescale = 1/255)

extract_features2 <- function(directory, sample_count, verbose = F) {
  #library(imager)
  library(jpeg)
  
  features <- array(0, dim = c(sample_count, 8, 8, 512))  
  labels <- array(0, dim = c(sample_count, length(classes)))
  
  files <- list.files(directory)
  
  for (i in 1:sample_count) {
    if (verbose) cat(paste(i, ", ", sep=""))
    
    fname <- files[i]
    str <- substr(fname, 1, regexpr("-",fname)-1)
    for (j in 1:length(classes)) {
      labels[i, j] <- grepl(classes[j], str)
    }
    
    # img <- load.image(file.path(directory, files[i]))
    img <- readJPEG(file.path(directory, files[i]))
    dim(img) <- c(1, 256, 256, 3)
    features[i,,,] <- conv_base %>% predict(img)
  }
  
  list(
    features = features, 
    labels = labels
  )
}

n_train <- length(list.files(train_dir))
n_validation <- length(list.files(validation_dir))
n_test <- length(list.files(test_dir))


train <- extract_features2(train_dir, n_train, verbose = T)
validation <- extract_features2(validation_dir, n_validation, verbose = T)
test <- extract_features2(test_dir, n_test, verbose = T)


reshape_features <- function(features) {
  array_reshape(features, dim = c(nrow(features), 8 * 8 * 512))
}

train$features <- reshape_features(train$features)
validation$features <- reshape_features(validation$features)
test$features <- reshape_features(test$features)

model <- keras_model_sequential() %>% 
  layer_dense(units = 256, activation = "relu", 
              input_shape = 8 * 8 * 512) %>% 
  layer_dropout(rate = 0.5) %>% 
  layer_dense(units = length(classes), activation = "sigmoid")

model %>% compile(
  optimizer = optimizer_rmsprop(lr = 2e-5),
  loss = "binary_crossentropy",
  metrics = c("accuracy")
)

history <- model %>% fit(
  train$features, train$labels,
  epochs = 30,
  batch_size = 20,
  validation_data = list(validation$features, validation$labels)
)


png(name.file(2, ".png"))
plot(history)
dev.off()

save_model_hdf5(model, name.file(2, ".h5"))
# model <- load_model_hdf5(name.file(2, ".h5"))

preds <- model %>% predict(test$features)
test_labs <- test$labels

colnames(preds) <- colnames(test_labs) <- classes
save(preds, test_labs, file = name.file(2, ".Rdata"))
base::save.image(name.file(0, ".RData"))

