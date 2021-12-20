setwd('/Users/liwenyu/Desktop/usc/460/final/DATA')
include = read.table('include_sum_numeric.txt')

install.packages('fastDummies')
library('fastDummies')

include = dummy_cols(include, select_columns = c('METRO3','SMSA','CMSA','REGION','DIVISION','NUNIT2','BATHS','BEDRMS','BUILT','TENURE','KITCHEN','HHCITSHP','HHRACE','CELLAR','HHGRAD','TYPE','WATER'),remove_first_dummy = TRUE)
include = subset(include, select = -c(METRO3,SMSA,CMSA,REGION,DIVISION,NUNIT2,BATHS,BEDRMS,BUILT,TENURE,KITCHEN,HHCITSHP,HHRACE,CELLAR,HHGRAD,TYPE,WATER))

dim(include)

include = subset(include,select = -CONTROL)
for(i in 1:20415){
    for (j in list('PORCH','IFFEE','TXRE','WATERS','BSINK','SHARPF','TOILET','TUB','GARAGE','DRSHOP','DRSHOP','NOSTEP','OTBUP','EBAR','HDSB','HHSPAN','NEWC','HOTPIP')){
        if (include[i,j]==2){
            include[i,j] = 0
        }
    }    
}
for(i in 1:20415){
    if (include[i,'CONDO']==3){
            include[i,'CONDO'] = 0
    }    
}

hist(include$VALUE)

include$VALUE = log(include$VALUE)
hist(include$VALUE)

x = scale(include[,-33],center = T,scale = T)
x = data.frame(x)
y = include['VALUE']

install.packages('tidyverse')
library(tidyverse)

include1 = bind_cols(x, y)
head(include1)

OLS_model <- glm(VALUE ~., data=include1)
summary(OLS_model)

x = data.frame(x)
include = x
include$VALUE = y
include = subset(include,select = -c(TOILET,NUNITS,CONDO,HOTPIP,TENURE_,TYPE_ ))

head(include)

n = 20415/5
test_index = sample(c(1:20415),size=n)
sample_test = include[test_index,]
sample_train = include[-test_index,]

dim(sample_train)

x = subset(sample_train,select = -c(VALUE,METRO3_5,SMSA_9999,CMSA_99,REGION_4,DIVISION_7,NUNIT2_2,BATHS_8,BEDRMS_7,BUILT_2013,KITCHEN_2,HHCITSHP_5,HHRACE_21,CELLAR_5,HHGRAD_47,WATER_5))
kappa(x)

sample_train = data.frame(sample_train,  VALUE = unlist(sample_train$VALUE))

str(sample_train$VALUE)

# linear regression
OLS_model <- glm(VALUE ~., data=sample_train)
summary(OLS_model)

# 9/10 of sample for estimation for estimation
set.seed(0)
n_est_sample <- round(9*length(sample_train[,1])/10)
est_sample_ind <- sample.int(n = length(sample_train[,1]), size = n_est_sample, replace = FALSE)
training_sample = sample_train[est_sample_ind,]
training_true_y = training_sample['VALUE']
validation_sample = sample_train[-est_sample_ind,]
validation_x = subset(validation_sample, select = -VALUE)
validation_true_y = validation_sample['VALUE']
OLS_model <- glm(VALUE ~ ., data=training_sample)
in_sample_predictions = predict(OLS_model,newdata = training_sample)
out_sample_predictions = predict(OLS_model,newdata = validation_x)

is_mse = sum((training_true_y - in_sample_predictions)^2)/length(training_true_y)
is_rmse = is_mse^(0.5)
cat(is_mse,' ', is_rmse)

oos_mse = sum((validation_true_y - out_sample_predictions)^2)/length(validation_true_y)
oos_rmse = oos_mse^(0.5)
cat(oos_mse,' ', oos_rmse)

summary(training_true_y)

summary(out_sample_predictions)

dim(include)

#lasso
install.packages('gamlr')
library(gamlr)

set.seed(0)
training_x = subset(training_sample, select = -VALUE)
par(mfrow=c(1,2))
plot(cv_lasso <- cv.gamlr(x=training_x, y=training_sample['VALUE'], lmr=1e-4))
plot(cv_lasso$gamlr)
  
lin <- cv.gamlr(x=validation_x, y=validation_sample['VALUE'], lmr=1e-4)
yhat.lin <- drop(predict(lin, training_x))
rmse = sqrt(sum((validation_sample['VALUE'] - yhat.lin)^2))
rmse

#regression tree
install.packages('tree')
library(tree)

dim(training_sample)

set.seed(0)
n_est_sample <- round(9*length(sample_train[,1])/10)
est_sample_ind <- sample.int(n = length(sample_train[,1]), size = n_est_sample, replace = FALSE)
training_sample = sample_train[est_sample_ind,]
training_true_y = training_sample['VALUE']
validation_sample = sample_train[-est_sample_ind,]
validation_x = subset(validation_sample, select = -VALUE)
validation_true_y = validation_sample['VALUE']

tree <- tree(VALUE ~ ., data=training_sample)

plot(tree, col = 8) 
text(tree,cex=.75, font=2)

in_sample_predictions = predict(tree,data = training_sample)
out_sample_predictions = predict(tree,data = validation_x)

is_mse = sum((training_true_y - in_sample_predictions)^2)/length(training_true_y)
is_rmse = is_mse^(0.5)
cat(is_mse,' ', is_rmse)

oos_mse = sum((validation_true_y - out_sample_predictions)^2)/length(validation_true_y)
oos_rmse = oos_mse^(0.5)
cat(oos_mse,' ', oos_rmse)

set.seed(0)
cv_tree <- cv.tree(tree) 
plot(cv_tree)

cv_tree$dev

cv_tree$size

( cv_tree_best_size <- cv_tree$size[which.min(cv_tree$dev)] )

pr_tree <- prune.tree(tree, best=cv_tree_best_size)
plot(pr_tree, col=2)
text(pr_tree)

MSE <- list(CART=NULL)
rt <- tree(VALUE ~ ., data=training_sample, mindev=0, mincut=1)
cvrt <- cv.tree(rt)
opt_size_rt <- cvrt$size[which.min(cvrt$dev)]
rtcut <- prune.tree(rt, best=opt_size_rt)
yhat.cvrt <- predict(rtcut, data = validation_x)
MSE$CART <- c(MSE$CART, sqrt(sum((validation_sample['VALUE'] - yhat.cvrt)^2)))
#in_sample_predictions = predict(tree,data = training_sample)
#out_sample_predictions = predict(tree,data = validation_x)

#random forest
set.seed(0)
install.packages('ranger')
library(ranger)

rf <- ranger(VALUE ~ ., data=training_sample, write.forest=TRUE, num.tree=200, min.node.size=5, importance="impurity")  
barplot(sort(importance(rf), decreasing=TRUE), las=2)

yhat.rf <- predict(rf, data=validation_sample)$predictions
rmse = sqrt(sum((validation_sample['VALUE'] - yhat.rf)^2)) )
rmse

set.seed(0)
MSE <- list(LASSO=NULL, CART=NULL, RF=NULL)
for(i in 1:10){
  train <- sample(1:nrow(CAhousing), 5000)

  lin <- cv.gamlr(x=XXca[train,], y=logMedVal[train], lmr=1e-4)
  yhat.lin <- drop(predict(lin, XXca[-train,]))
  MSE$LASSO <- c( MSE$LASSO, sqrt(sum((logMedVal[-train] - yhat.lin)^2)) )

  rt <- tree(logMedVal ~ ., data=CAhousing[train,], mindev=0, mincut=1)
  cvrt <- cv.tree(rt)
  opt_size_rt <- cvrt$size[which.min(cvrt$dev)]
  rtcut <- prune.tree(rt, best=opt_size_rt)
  yhat.cvrt <- predict(rtcut, newdata=CAhousing[-train,])
  MSE$CART <- c( MSE$CART, sqrt(sum((logMedVal[-train] - yhat.cvrt)^2)))

  rf <- ranger(logMedVal ~ ., data=CAhousing[train,],
               num.tree=200, min.node.size=5, write.forest=TRUE)
  yhat.rf <- predict(rf, data=training_sample[-VALUE,])$predictions
  MSE$RF <- c( MSE$RF, sqrt(sum((logMedVal[-train] - yhat.rf)^2)) )
}
par(mai=c(.8,.8,.1,.1))
boxplot(as.data.frame(MSE), col="dodgerblue", xlab="model", ylab="root-MSE")