# Fixed model, validation-only policy exploration. No further test-set evaluation.
# Costs are hypothetical relative units; not a lending recommendation.
policy_scores <- vp[[winner]]
policy_y <- valid$bad
ratios <- c(1,2,5,10,20)
# Include all attainable flag sets plus flag-everyone and flag-nobody policies.
policy_grid <- sort(unique(c(0,policy_scores,1+1e-10)))
policy_curve <- do.call(rbind,lapply(policy_grid,function(t) {
  flags <- policy_scores >= t
  data.frame(threshold=t,missed_bad=sum(policy_y==1 & !flags),
    flagged_good=sum(policy_y==0 & flags),caught_bad=sum(policy_y==1 & flags),
    flagged=sum(flags),review_share=mean(flags))
}))
policies <- do.call(rbind,lapply(ratios,function(ratio) {
  costs <- ratio*policy_curve$missed_bad+policy_curve$flagged_good
  # Ties: fewer flags, then highest threshold. Explicit and reproducible.
  best <- order(costs,policy_curve$flagged,-policy_curve$threshold)[1]
  row <- policy_curve[best,]
  data.frame(missed_bad_cost=ratio,flagged_good_cost=1,row,
    recall=row$caught_bad/sum(policy_y==1),
    false_positive_rate=row$flagged_good/sum(policy_y==0),
    cost_units=costs[best],flag_none_cost=ratio*sum(policy_y==1),
    flag_all_cost=sum(policy_y==0),row.names=NULL)
}))
write.csv(policies,'results/decision_sensitivity.csv',row.names=FALSE)
write.csv(policy_curve,'results/validation_policy_curve.csv',row.names=FALSE)
png('results/decision_sensitivity.png',width=1700,height=1000,res=150)
par(bg='#F4F6FA',fg='#13243A',col.axis='#52647A',col.lab='#13243A',
  col.main='#13243A',mar=c(5,5,4,2),oma=c(4,0,5,0),mfrow=c(1,2))
plot(seq_along(ratios),policies$threshold,type='b',pch=19,lwd=3,col='#087E8B',
  xaxt='n',xlab='Assumed missed-bad : flagged-good cost',ylab='Selected score threshold',
  main='01 / POLICY CHANGES WITH COST',ylim=c(0,1))
axis(1,at=seq_along(ratios),labels=paste0(ratios,':1'))
matplot(seq_along(ratios),cbind(policies$recall,policies$false_positive_rate,policies$review_share),
  type='b',pch=c(19,17,15),lty=c(1,2,3),lwd=2,col=c('#087E8B','#E7A14A','#6D89A6'),
  xaxt='n',xlab='Assumed missed-bad : flagged-good cost',ylab='Proportion',ylim=c(0,1),
  main='02 / CAPTURE VERSUS REVIEW LOAD')
axis(1,at=seq_along(ratios),labels=paste0(ratios,':1'))
legend('bottomright',c('Bad-credit recall','Good-credit flag rate','All-record review share'),
  col=c('#087E8B','#E7A14A','#6D89A6'),lty=c(1,2,3),pch=c(19,17,15),bty='n',cex=.75)
mtext('DECISION-COST SENSITIVITY / R',outer=TRUE,line=2.4,cex=1.5,font=2)
mtext('Frozen model | Five assumed cost ratios | Validation-only policy exploration',outer=TRUE,line=.8,cex=.85)
mtext('Metrics are optimized and measured on the same validation sample: descriptive, not unbiased performance.',
  outer=TRUE,side=1,line=1,cex=.8)
mtext('Relative cost units, not euros. Original saved model and 0.22 threshold are unchanged.',
  outer=TRUE,side=1,line=2.3,cex=.8)
dev.off()
stopifnot(nrow(policies)==5,all(policies$cost_units<=policies$flag_none_cost),
  all(policies$cost_units<=policies$flag_all_cost),
  all(diff(policies$missed_bad)<=0),all(diff(policies$review_share)>=0),
  all(policies$flagged==policies$caught_bad+policies$flagged_good))
print(policies[,c('missed_bad_cost','threshold','recall','false_positive_rate','review_share','cost_units')])
cat('Decision sensitivity checks passed. Original model and test metrics unchanged.\n')
