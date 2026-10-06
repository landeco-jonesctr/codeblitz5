library(CrownScorchTLS)
library(lidR)
library(readr)
library(randomForest)

las <- readLAS("data/laz/M-04-15549_post.laz")

plot(las)                        # raw point cloud
plot(las, color = "Intensity")   # colored by reflectance intensity

crown <- remove_stem(las)        # strip out the trunk, keep just the crown
crown <- add_reflectance(crown)  # fill in any missing reflectance values

hist(crown$Reflectance)          # just a plain base-R histogram, in dB, of the crown's points

hist_df <- get_histogram(crown)  # same idea, packaged as a one-row table

print(hist_df)

df <- read_csv("data/scorch_training_table.csv")
set.seed(38)

mod = randomForest(x = as.matrix(df[, 4:103]), y = as.matrix(df[, 3]))
mod

str(mod)

plot(df$scorch, mod$predicted, asp = 1)
abline(a = 0, b = 1, lty = "dashed", col = "blue", lwd = 2)

df$error <- mod$predicted - df$scorch
bias <- mean(df$error)
bias
mae <- mean(sqrt((df$error)^2))
mae
rmse <- sqrt(mean((df$error)^2))
rmse
rsq <- (cor(df$scorch, mod$predicted))^2
rsq

df
print(df)
str(df)
df$error

