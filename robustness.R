# Repeated development-set holdouts. Original 200 test records stay excluded.
# Fixed features and model settings: this diagnostic does not retune the final model.
development <- d[d$id %in% c(train_id,valid_id), ]
stopifnot(!any(development$id %in% test$id),nrow(development)==800)
robust_runs <- lapply(1:50,function(run) {
  set.seed(5000+run)
  fit_ids <- unlist(lapply(0:1,function(label) {
    available <- which(development$bad==label)
    sample(available,floor(.75*length(available)))
  }))
  fitting <- development[fit_ids,]; checking <- development[-fit_ids,]
  fit <- glm(form,data=fitting,family=binomial())
  stopifnot(fit$converged,all(is.finite(coef(fit))),
    !any(fitting$id %in% checking$id),nrow(fitting)==600,nrow(checking)==200)
  tree_data <- fitting; tree_data$bad <- factor(tree_data$bad,levels=0:1)
  challenger <- rpart::rpart(form,data=tree_data,method='class',
    control=rpart::rpart.control(cp=.01,maxdepth=3,minsplit=40,xval=0))
  scores <- list(Logistic=as.numeric(predict(fit,checking,type='response')),
    Tree=as.numeric(predict(challenger,checking,type='prob')[,'1']),
    Baseline=rep(mean(fitting$bad),nrow(checking)))
  do.call(rbind,lapply(names(scores),function(name) {
    values <- measure(checking$bad,scores[[name]])
    data.frame(run=run,seed=5000+run,model=name,AUC=values['AUC'],
      Brier=values['Brier'],LogLoss=values['LogLoss'],row.names=NULL)
  }))
})
robust_results <- do.call(rbind,robust_runs)
robust_summary <- do.call(rbind,lapply(c('Logistic','Tree','Baseline'),function(name) {
  z <- robust_results[robust_results$model==name,]
  data.frame(model=name,mean_auc=mean(z$AUC),auc_p05=unname(quantile(z$AUC,.05)),
    auc_p95=unname(quantile(z$AUC,.95)),mean_brier=mean(z$Brier),
    brier_p05=unname(quantile(z$Brier,.05)),brier_p95=unname(quantile(z$Brier,.95)))
}))
logistic_runs <- robust_results[robust_results$model=='Logistic',]
tree_runs <- robust_results[robust_results$model=='Tree',]
wins <- sum(logistic_runs$Brier<tree_runs$Brier)
write.csv(robust_results,'results/robustness_runs.csv',row.names=FALSE)
write.csv(robust_summary,'results/robustness_summary.csv',row.names=FALSE)
png('results/robustness.png',width=1700,height=1000,res=150)
par(bg='#F4F6FA',fg='#13243A',col.axis='#52647A',col.lab='#13243A',
  col.main='#13243A',mar=c(5,5,4,2),oma=c(4,0,5,0),mfrow=c(1,2))
robust_results$model <- factor(robust_results$model,levels=c('Logistic','Tree','Baseline'))
boxplot(AUC~model,data=robust_results,col=c('#087E8B','#E7A14A','#CAD3DE'),
  main='01 / RANKING STABILITY',ylab='Validation AUC',xlab='',outline=TRUE)
boxplot(Brier~model,data=robust_results,col=c('#087E8B','#E7A14A','#CAD3DE'),
  main='02 / PROBABILITY ERROR',ylab='Validation Brier score (lower is better)',xlab='',outline=TRUE)
mtext('ROBUSTNESS REVIEW / R',outer=TRUE,line=2.5,cex=1.5,font=2)
mtext(sprintf('50 stratified development splits | Logistic beats tree on Brier in %d / 50 runs',wins),
  outer=TRUE,line=.9,cex=.85)
mtext('800 development records only. Original 200-record test set stays excluded.',side=1,outer=TRUE,line=1,cex=.85)
mtext('Splits overlap: distributions describe split sensitivity, not independent confidence intervals.',
  side=1,outer=TRUE,line=2.3,cex=.8)
dev.off()
stopifnot(nrow(robust_results)==150,all(is.finite(robust_results$AUC)),
  all(robust_results$AUC>=0 & robust_results$AUC<=1),
  all(robust_results$Brier>=0 & robust_results$Brier<=1))
print(robust_summary)
cat(sprintf('Robustness checks passed: 50 runs; logistic Brier wins %d/50. Original test excluded.\n',wins))
