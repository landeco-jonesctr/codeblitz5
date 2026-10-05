library(CrownScorchTLS)
library(lidR)
library(tidyverse)
library(readr)
library(randomForest)

scorch.table.csv <- read.csv("data/scorch_training_table.csv")
# 253 trees
# 102 features + treeid
# responce  = scorch?

set.seed(3)
mod <- randomForest(scorch ~., data = scorch.table.csv)
print(mod)

set.seed(497)
mod <- randomForest(scorch ~., data = scorch.table.csv)
print(mod)

set.seed(77711)
mod <- randomForest(scorch ~., data = scorch.table.csv)
print(mod)

set.seed(500)
mod <- randomForest(scorch ~., data = scorch.table.csv)
print(mod)
