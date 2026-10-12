# Credit Risk Review | Run from RStudio with source('analysis.R')
# Or from a terminal: Rscript analysis.R
# Base R + recommended package rpart. No package installation normally needed.
args <- commandArgs(trailingOnly = FALSE)
script <- grep('^--file=', args, value = TRUE)
if (length(script)) setwd(dirname(normalizePath(sub('^--file=', '', script[1]))))
if (!file.exists('data/SouthGermanCredit.asc')) stop('Set working directory to the project folder.')
if (!requireNamespace('rpart', quietly = TRUE)) stop('Install rpart: install.packages("rpart")')
dir.create('results', showWarnings = FALSE)
set.seed(42)
raw <- read.table('data/SouthGermanCredit.asc', header = TRUE)
stopifnot(nrow(raw) == 1000, !anyNA(raw), sum(raw$kredit == 0) == 300)
# Codes are categorical, not continuous measurements. Labels follow bundled code table.
d <- data.frame(id = seq_len(nrow(raw)), bad = 1L - raw$kredit,
  checking = factor(raw$laufkont, 1:4, c('none','negative','low','high')),
  duration = raw$laufzeit, log_amount = log(raw$hoehe),
  history = factor(raw$moral, 0:4), savings = factor(raw$sparkont, 1:5),
  employment = factor(raw$beszeit, 1:5), installment = factor(raw$rate, 1:4),
  other_plans = factor(raw$weitkred, 1:3))
# Compact pre-specified feature set. Demographics excluded; that does not prove fairness.
train_id <- valid_id <- test_id <- integer()
for (label in 0:1) {
  ids <- sample(which(d$bad == label))
  a <- floor(.6 * length(ids)); b <- floor(.2 * length(ids))
  train_id <- c(train_id, ids[seq_len(a)])
  valid_id <- c(valid_id, ids[a + seq_len(b)])
  test_id <- c(test_id, ids[(a+b+1):length(ids)])
}
train <- d[train_id, ]; valid <- d[valid_id, ]; test <- d[test_id, ]
form <- bad ~ checking + duration + log_amount + history + savings + employment + installment + other_plans
logit <- glm(form, data = train, family = binomial())
stopifnot(logit$converged, all(is.finite(coef(logit))))
tree_train <- train; tree_train$bad <- factor(tree_train$bad, levels = 0:1)
tree <- rpart::rpart(form, data = tree_train, method = 'class',
  control = rpart::rpart.control(cp = .01, maxdepth = 3, minsplit = 40, xval = 0))
score <- function(data) list(Logistic = as.numeric(predict(logit, data, type = 'response')),
  Tree = as.numeric(predict(tree, data, type = 'prob')[, '1']),
  Baseline = rep(mean(train$bad), nrow(data)))
auc <- function(y, p) {
  n1 <- sum(y == 1); n0 <- sum(y == 0)
  (sum(rank(p)[y == 1]) - n1*(n1+1)/2)/(n1*n0)
}
measure <- function(y, p) c(AUC = auc(y,p), Brier = mean((p-y)^2),
  LogLoss = -mean(y*log(pmax(p,1e-10)) + (1-y)*log(pmax(1-p,1e-10))))
vp <- score(valid)
vm <- do.call(rbind, lapply(vp, function(p) measure(valid$bad,p)))
# Choose between two fixed candidate models using validation Brier, never test metrics.
winner <- rownames(vm)[which.min(vm[c('Logistic','Tree'),'Brier'])]
thresholds <- seq(.05,.95,.01)
# Illustrative relative costs: missed bad credit = 5; wrongly flagged good credit = 1.
cost <- function(y,p,t) 5*sum(y == 1 & p < t) + sum(y == 0 & p >= t)
vcost <- sapply(thresholds, function(t) cost(valid$bad,vp[[winner]],t))
threshold <- thresholds[which.min(vcost)]
tp <- score(test); p <- tp[[winner]]; y <- test$bad
tm <- do.call(rbind,lapply(tp,function(p) measure(y,p)))
# Conditional test-set bootstrap: captures sampling uncertainty, not training instability.
set.seed(2026)
boot <- replicate(1000, {i <- sample(seq_along(y), replace=TRUE); auc(y[i],p[i])})
ci <- quantile(boot,c(.025,.975))
pred <- as.integer(p >= threshold)
cm <- table(Actual = factor(y,0:1,c('Good','Bad')), Flagged = factor(pred,0:1,c('No','Yes')))
bands <- cut(rank(p,ties.method='first'), breaks=seq(0,length(p),length.out=6), labels=1:5)
cal <- aggregate(cbind(predicted=p,observed=y),list(band=bands),mean)
cal$n <- as.integer(table(bands))
cal$se <- sqrt(cal$observed*(1-cal$observed)/cal$n)
metrics <- data.frame(model=rownames(tm),tm,row.names=NULL)
write.csv(metrics,'results/test_metrics.csv',row.names=FALSE)
write.csv(data.frame(model=rownames(vm),vm),'results/validation_metrics.csv',row.names=FALSE)
write.csv(data.frame(id=test$id,actual_bad=y,score=p,flagged=pred),'results/test_predictions.csv',row.names=FALSE)
write.csv(cal,'results/calibration.csv',row.names=FALSE)
write.csv(as.data.frame(cm),'results/confusion_matrix.csv',row.names=FALSE)
write.csv(data.frame(id=d$id,split=ifelse(d$id %in% train_id,'train',ifelse(d$id %in% valid_id,'validation','test'))),
  'results/split_manifest.csv',row.names=FALSE)
cs <- summary(logit)$coefficients
write.csv(data.frame(term=rownames(cs),odds_ratio=exp(cs[,1]),
  lower=exp(cs[,1]-1.96*cs[,2]),upper=exp(cs[,1]+1.96*cs[,2])),
  'results/logistic_odds_ratios.csv',row.names=FALSE)
saveRDS(list(logistic=logit,tree=tree,selected=winner,threshold=threshold),'results/models.rds')
capture.output(sessionInfo(),file='results/sessionInfo.txt')

# Publication-sized visual, generated entirely in R.
png('results/project_summary.png',width=1800,height=1400,res=160)
par(bg='#F4F6FA',fg='#13243A',col.axis='#52647A',col.lab='#13243A',
  col.main='#13243A',family='sans',mar=c(4.4,4.4,3.5,1.5),oma=c(3,0,5,0))
layout(matrix(1:4,2,2,byrow=TRUE))
ord <- order(p,decreasing=TRUE); yy <- y[ord]
plot(c(0,cumsum(yy==0)/sum(y==0)),c(0,cumsum(yy==1)/sum(y==1)),
  type='s',lwd=3,col='#087E8B',xlab='False positive rate',ylab='True positive rate',
  main=sprintf('01 / RISK RANKING   AUC %.3f',auc(y,p)),xlim=c(0,1),ylim=c(0,1))
abline(0,1,lty=2,col='#A6B0BD')
legend('bottomright',legend=sprintf('95%% bootstrap interval: %.2f - %.2f',ci[1],ci[2]),bty='n',cex=.8)
barplot(t(as.matrix(cal[,c('predicted','observed')])),beside=TRUE,
  col=c('#087E8B','#E7A14A'),names.arg=cal$band,ylim=c(0,1),border=NA,
  xlab='Score quintile (low to high)',ylab='Bad-credit proportion',main='02 / SAMPLE CALIBRATION')
legend('topleft',c('Predicted','Observed'),fill=c('#087E8B','#E7A14A'),bty='n',cex=.85)
barplot(tm[,'Brier'],col=c('#087E8B','#6D89A6','#CAD3DE'),border=NA,
  ylim=c(0,max(tm[,'Brier'])*1.25),ylab='Brier score (lower is better)',main='03 / HELD-OUT COMPARISON')
plot(thresholds,vcost,type='l',lwd=3,col='#087E8B',xlab='Flagging threshold',
  ylab='Illustrative validation cost units',main='04 / DECISION COST TRADE-OFF')
abline(v=threshold,col='#E7A14A',lwd=2,lty=2)
legend('topright',sprintf('Validation-selected threshold: %.2f',threshold),bty='n',cex=.8)
mtext('CREDIT RISK REVIEW / R',outer=TRUE,line=2.8,cex=1.6,font=2,col='#13243A')
mtext(sprintf('1,000 historical records | 600 train / 200 validation / 200 test | Selected: %s',winner),
  outer=TRUE,line=1.1,cex=.85)
mtext('UCI South German Credit | Bad credits oversampled: scores are not population PDs.',outer=TRUE,side=1,line=1,cex=.8)
dev.off()
summary_lines <- c(sprintf('Selected model: %s',winner),sprintf('Test AUC: %.3f (bootstrap 95%%: %.3f - %.3f)',auc(y,p),ci[1],ci[2]),
 sprintf('Test Brier: %.4f; baseline: %.4f',mean((p-y)^2),tm['Baseline','Brier']),
 sprintf('Validation-selected threshold: %.2f; assumed FN:FP cost = 5:1',threshold),
 sprintf('Test cost units: %d; flag nobody: %d; flag everybody: %d',cost(y,p,threshold),5*sum(y),sum(y==0)),
 sprintf('Bad credits flagged: %d of %d; good credits flagged: %d of %d',cm[2,2],sum(y),cm[1,2],sum(y==0)))
writeLines(summary_lines,'results/summary.txt')
stopifnot(length(intersect(train_id,test_id))==0,length(intersect(valid_id,test_id))==0,
  length(unique(c(train_id,valid_id,test_id)))==1000,
  auc(c(0,1),c(.1,.9))==1,auc(c(0,1),c(.5,.5))==.5,
  all(is.finite(p)),all(p>=0 & p<=1),sum(cm)==200,all(cal$n==40))
cat(paste(summary_lines,collapse='\n'),'\nAll numerical checks passed.\n')
source('monitoring.R')
source('explainability.R')
source('robustness.R')
source('decision_sensitivity.R')
