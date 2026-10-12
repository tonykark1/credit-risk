# Sourced by analysis.R. Explain the frozen logistic benchmark without refitting.
ex_model <- readRDS('results/models.rds')$logistic
features <- all.vars(delete.response(terms(ex_model)))
pretty <- c(checking='Checking account',duration='Loan duration',log_amount='Log amount',
  history='Credit history',savings='Savings',employment='Employment duration',
  installment='Installment category',other_plans='Other installment plans')
set.seed(108)
base_brier <- mean((predict(ex_model,valid,type='response')-valid$bad)^2)
importance <- do.call(rbind,lapply(features,function(feature) {
  changes <- replicate(50, {
    shuffled <- valid
    shuffled[[feature]] <- sample(shuffled[[feature]])
    mean((predict(ex_model,shuffled,type='response')-valid$bad)^2)-base_brier
  })
  data.frame(feature=feature,mean_brier_increase=mean(changes),
    shuffle_p05=unname(quantile(changes,.05)),shuffle_p95=unname(quantile(changes,.95)))
}))
importance <- importance[order(importance$mean_brier_increase,decreasing=TRUE),]
write.csv(importance,'results/permutation_importance.csv',row.names=FALSE)
# Fixed transparent example: lowest source-row ID in the held-out set; no cherry-picking.
example <- test[which.min(test$id),,drop=FALSE]
term_values <- predict(ex_model,example,type='terms')
constant <- attr(term_values,'constant')
contributions <- as.numeric(term_values[1,])
names(contributions) <- colnames(term_values)
eta <- constant+sum(contributions)
example_score <- as.numeric(predict(ex_model,example,type='response'))
explanation <- data.frame(feature=names(contributions),
  observed_value=sapply(names(contributions),function(n) as.character(example[[n]])),
  log_odds_contribution=contributions,row.names=NULL)
write.csv(explanation,'results/example_contributions.csv',row.names=FALSE)
write.csv(data.frame(source_row=example$id,reference_log_odds=constant,
  reference_score=plogis(constant),total_log_odds=eta,score=example_score),
  'results/example_score.csv',row.names=FALSE)
png('results/explainability.png',width=1800,height=1150,res=160)
par(bg='#F4F6FA',fg='#13243A',col.axis='#52647A',col.lab='#13243A',
  col.main='#13243A',mar=c(5,10,4,2),oma=c(4,0,5,0),mfrow=c(1,2))
imp <- importance[nrow(importance):1,]
positions <- barplot(imp$mean_brier_increase,horiz=TRUE,
  names.arg=pretty[imp$feature],las=1,cex.names=.8,col='#087E8B',border=NA,
  xlim=range(c(0,imp$shuffle_p05,imp$shuffle_p95))*1.15,
  xlab='Increase in validation Brier score',main='01 / MODEL RELIANCE')
segments(imp$shuffle_p05,positions,imp$shuffle_p95,positions,col='#13243A',lwd=2)
abline(v=0,col='#A6B0BD')
local <- sort(contributions)
barplot(local,horiz=TRUE,names.arg=pretty[names(local)],las=1,cex.names=.8,
  col=ifelse(local>=0,'#E7A14A','#087E8B'),border=NA,
  xlab='Contribution to log odds versus reference',main=sprintf('02 / EXAMPLE ROW %d',example$id))
abline(v=0,col='#52647A')
mtext(sprintf('Reference %.1f%% -> example score %.1f%%',100*plogis(constant),100*example_score),
  side=3,line=.3,cex=.8)
mtext('EXPLAINING CREDIT RISK / R',outer=TRUE,line=2.3,cex=1.5,font=2)
mtext('Frozen logistic model | 50 validation shuffles per feature | Exact log-odds decomposition',
  outer=TRUE,line=.8,cex=.8)
mtext('Shuffle ranges are not confidence intervals. Contributions explain model associations, not causes.',
  outer=TRUE,side=1,line=1,cex=.8)
mtext('Reference = model score at mean training design values; sample scores are not population PDs.',
  outer=TRUE,side=1,line=2.3,cex=.8)
dev.off()
stopifnot(abs(plogis(eta)-example_score)<1e-10,
  abs(eta-as.numeric(predict(ex_model,example,type='link')))<1e-10,
  nrow(importance)==length(features),all(is.finite(importance$mean_brier_increase)))
cat(sprintf('Explainability checks passed. Top validation feature: %s. Example row %d score: %.4f.\n',
  importance$feature[1],example$id,example_score))
