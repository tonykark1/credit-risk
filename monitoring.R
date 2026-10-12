# Run after analysis.R. Uses its frozen model, preprocessing, and split manifest.
model_bundle <- readRDS('results/models.rds')
selected <- model_bundle$selected
monitor_score <- function(x) {
  if (selected == 'Logistic') as.numeric(predict(model_bundle$logistic,x,type='response'))
  else as.numeric(predict(model_bundle$tree,x,type='prob')[,'1'])
}
reference <- monitor_score(train)
current <- monitor_score(test)
# Freeze bin boundaries on training scores. Infinite endpoints cover future scores.
edges <- unique(c(-Inf,as.numeric(quantile(reference,seq(.1,.9,.1))),Inf))
bin_counts <- function(p) tabulate(cut(p,edges,labels=FALSE,include.lowest=TRUE),nbins=length(edges)-1)
# Add 0.5 to every count to avoid undefined log ratios for empty bins.
proportions <- function(counts) (counts+.5)/(sum(counts)+.5*length(counts))
ref_counts <- bin_counts(reference)
ref_prop <- proportions(ref_counts)
psi <- function(scores) {
  observed <- proportions(bin_counts(scores))
  sum((observed-ref_prop)*log(observed/ref_prop))
}
# A designed sensitivity scenario, not a macroeconomic forecast or later time period.
shifted <- test
shifted$checking <- factor(ifelse(as.character(test$checking)=='high','low',
  ifelse(as.character(test$checking)=='low','negative',as.character(test$checking))),
  levels=levels(train$checking))
shifted$duration <- test$duration*1.25
scenario <- monitor_score(shifted)
# Empirical reference for finite-sample variation; conditional on the training data.
set.seed(73)
null_psi <- replicate(2000,psi(sample(reference,nrow(test),replace=TRUE)))
cutoff <- unname(quantile(null_psi,.95))
observed_psi <- c(psi(current),psi(scenario))
monitor <- data.frame(comparison=c('Held-out sample','Illustrative profile shift'),
  n=nrow(test),PSI=observed_psi,reference_95pct=cutoff,
  review_flag=observed_psi>cutoff,
  mean_score=c(mean(current),mean(scenario)))
write.csv(monitor,'results/monitoring_metrics.csv',row.names=FALSE)
write.csv(data.frame(bin=seq_along(ref_counts),lower=head(edges,-1),upper=tail(edges,-1),
  training_count=ref_counts,test_count=bin_counts(current),scenario_count=bin_counts(scenario),
  training_share=ref_prop,test_share=proportions(bin_counts(current)),
  scenario_share=proportions(bin_counts(scenario))),
  'results/monitoring_bins.csv',row.names=FALSE)
write.csv(data.frame(PSI=null_psi),'results/monitoring_reference_simulation.csv',row.names=FALSE)
png('results/monitoring.png',width=1700,height=1000,res=150)
par(bg='#F4F6FA',fg='#13243A',col.axis='#52647A',col.lab='#13243A',
  col.main='#13243A',mar=c(5,5,4,2),oma=c(3,0,4,0),mfrow=c(1,2))
mat <- rbind(ref_prop,proportions(bin_counts(current)),proportions(bin_counts(scenario)))
barplot(mat,beside=TRUE,col=c('#CAD3DE','#087E8B','#E7A14A'),border=NA,
  names.arg=seq_along(ref_counts),xlab='Frozen training-score bins',ylab='Smoothed share',
  main='01 / SCORE DISTRIBUTION',ylim=c(0,max(mat)*1.45))
legend('topright',c('Training','Held-out','Profile shift'),
  fill=c('#CAD3DE','#087E8B','#E7A14A'),bty='n',cex=.8)
hist(null_psi,breaks=30,col='#CAD3DE',border='white',main='02 / PSI REVIEW SIGNAL',
  xlab='Population Stability Index',xlim=range(c(0,null_psi,observed_psi))*c(1,1.15))
abline(v=cutoff,lty=2,lwd=2,col='#52647A')
abline(v=observed_psi,col=c('#087E8B','#E7A14A'),lwd=3)
legend('topright',c(sprintf('Held-out: %.3f',observed_psi[1]),
  sprintf('Profile shift: %.3f',observed_psi[2]),sprintf('Reference 95th pct: %.3f',cutoff)),
  col=c('#087E8B','#E7A14A','#52647A'),lty=c(1,1,2),lwd=2,bty='n',cex=.8)
mtext('MODEL MONITORING / R',outer=TRUE,line=1.5,cex=1.5,font=2)
mtext('Illustrative sensitivity, not temporal drift. PSI detects distribution change, not loss of accuracy.',
  side=1,outer=TRUE,line=1,cex=.8)
dev.off()
stopifnot(abs(psi(reference))<1e-12,all(is.finite(observed_psi)),all(observed_psi>=0),
  sum(bin_counts(scenario))==nrow(test),abs(sum(ref_prop)-1)<1e-12,
  identical(as.character(shifted$checking[test$checking=='none']),as.character(test$checking[test$checking=='none'])))
print(monitor)
cat('Monitoring checks passed.\n')
