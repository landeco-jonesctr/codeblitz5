library(CrownScorchTLS)
library(lidR)
library(readr)
library(randomForest)
library(tidyverse)

#examining point cloud
las <- readLAS("data/laz/M-04-15549_post.laz")

plot(las)                        # raw point cloud
plot(las, color = "Intensity")   # colored by reflectance intensity

crown <- remove_stem(las)        # strip out the trunk, keep just the crown
crown <- add_reflectance(crown)  # fill in any missing reflectance values

hist(crown$Reflectance)          # just a plain base-R histogram, in dB, of the crown's points

hist_df <- get_histogram(crown)  # same idea, packaged as a one-row table

print(hist_df)

#testing random forest model 
df <- read_csv("data/scorch_training_table.csv")
set.seed(38)

mod <- randomForest(x = as.matrix(df[, 4:103]), y = as.matrix(df[, 3]))

str(mod)

plot(df$scorch, mod$predicted, asp = 1)
abline(a = 0, b = 1, lty = "dashed", col = "blue", lwd = 2)

df$error <- mod$predicted - df$scorch
bias <- mean(df$error)
mae <- mean(sqrt((df$error)^2))
rmse <- sqrt(mean((df$error)^2))
rsq <- (cor(df$scorch, mod$predicted))^2

#running random forest with training and validation data
df <- read_csv("data/scorch_training_table.csv")
nrow(df)
#253 * 0.75 = 190

set.seed(801)
training_id <- sample(df$treeid, 190, replace = FALSE)
training <- subset(df, (treeid %in% training_id))
training
validation <- subset(df, !(treeid %in% training_id)) 

mod <- randomForest(x = as.matrix(training[, 4:103]), y = as.matrix(training[, 3]))
print(mod)

plot(training$scorch, mod$predicted, asp = 1)
abline(a = 0, b = 1, lty = "dashed", col = "blue", lwd = 2)

validation$new_prediction <- predict(mod, newdata = validation)
validation

#plot of prediction of validation data vs. actual scorch
plot(validation$scorch, validation$new_prediction, asp = 1)
abline(a = 0, b = 1, lty = "dashed", col = "blue", lwd = 2)

validation$error <- validation$new_prediction - validation$scorch
bias <- mean(validation$error)
mae <- mean(sqrt((validation$error)^2))
rmse <- sqrt(mean((validation$error)^2))
rsq <- (cor(validation$scorch, validation$new_prediction))^2
