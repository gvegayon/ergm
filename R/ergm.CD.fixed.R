#  File R/ergm.CD.fixed.R in package ergm, part of the Statnet suite
#  of packages for network analysis, https://statnet.org .
#
#  This software is distributed under the GPL-3 license.  It is free,
#  open source, and has the attribution requirements (GPL Section 7) at
#  https://statnet.org/attribution
#
#  Copyright 2003-2019 Statnet Commons
#######################################################################
############################################################################
# The <ergm.CD> function provides one of the styles of maximum
# likelihood estimation that can be used. This one is the default and uses
# optimization of an MCMC estimate of the log-likelihood.  (The other
# MLE styles are found in functions <ergm.robmon>, <ergm.stocapprox>, and
# <ergm.stepping> 
#
#
# --PARAMETERS--
#   init         : the initial theta values
#   nw             : the network 
#   model          : the model, as returned by <ergm_model>
#   initialfit     : an ergm object, as the initial fit, possibly returned
#                    by <ergm.initialfit>
#   control     : a list of parameters for controlling the MCMC sampling;
#                    recognized components include
#       samplesize : the number of MCMC sampled networks
#       maxit      : the maximum number of iterations to use
#       parallel   : the number of threads in which to run the sampling
#       packagenames: names of packages; this is only relevant if "ergm" is given
#       interval    : the number of proposals to ignore between sampled networks
#       burnin      : the number of proposals to initially ignore for the burn-in
#                     period
#
#       epsilon    : ??, this is essentially unused, except to print it if
#                    'verbose'=T and to pass it along to <ergm.estimate>,
#                    which ignores it;   
#   proposal     : an proposal object for 'nw', as returned by
#                    <proposal>
#   proposal.obs : an proposal object for the observed network of'nw',
#                    as returned by <proposal>
#   verbose        : whether the MCMC sampling should be verbose (T or F);
#                    default=FALSE
#   sequential     : whether to update the network returned in
#                    'v$newnetwork'; if the network has missing edges,
#                    this is ignored; default=control$CD.sequential
#   estimate       : whether to optimize the init coefficients via
#                    <ergm.estimate>; default=TRUE
#   ...            : additional parameters that may be passed from within;
#                    all are ignored
#
# --RETURNED--
#   v: an ergm object as a list containing several items; for details see
#      the return list in the <ergm> function header (<ergm.CD>=*);
#      note that if the model is degenerate, only 'coef' and 'sample' are
#      returned; if 'estimate'=FALSE, the MCMC and se variables will be
#      NA or NULL
#
#############################################################################

ergm.CD.fixed <- function(init, nw, model,
                             control, 
                             proposal, proposal.obs,
                             verbose=FALSE,
                             estimate=TRUE,
                             response=NULL, ...) {
  message("Starting contrastive divergence estimation via CD-MCMLE:")
  # Initialize the history of parameters and statistics.
  coef.hist <- rbind(init)
  stats.hist <- matrix(NA, 0, length(model$nw.stats))
  stats.obs.hist <- matrix(NA, 0, length(model$nw.stats))
  steplen.hist <- c()
  steplen <- control$CD.steplength
  
  # Store information about original network, which will be returned at end
  nw.orig <- network.copy(nw)

  # Impute missing dyads.
  nw <- single.impute.dyads(nw, response=response, constraints=proposal$arguments$constraints, constraints.obs=proposal.obs$arguments$constraints, min_informative = control$obs.MCMC.impute.min_informative, default_density = control$obs.MCMC.impute.default_density, verbose=verbose)
  model$nw.stats <- summary(model, nw, response=response)

  # Start cluster if required (just in case we haven't already).
  ergm.getCluster(control, max(verbose-1,0))
  
  nws <- rep(list(nw),nthreads(control)) # nws is now a list of networks.

  # statshift is the difference between the target.stats (if
  # specified) and the statistics of the networks in the LHS of the
  # formula or produced by SAN. If target.stats is not speficied
  # explicitly, they are computed from this network, so
  # statshift==0. To make target.stats play nicely with offsets, we
  # set statshifts to 0 where target.stats is NA (due to offset).
  statshift <- model$nw.stats - model$target.stats
  statshift[is.na(statshift)] <- 0
  statshifts <- rep(list(statshift), nthreads(control)) # Each network needs its own statshift.

  # Is there observational structure?
  obs <- ! is.null(proposal.obs)
  if(obs){
    control$CD.nsteps<-control$CD.nsteps.obs
    control$CD.multiplicity<-control$CD.multiplicity.obs
  }
  
  # Initialize control.obs and other *.obs if there is observation structure
  
  if(obs){
    control.obs <- control
    control.obs$MCMC.samplesize <- control$obs.MCMC.samplesize
    control.obs$MCMC.interval <- control$obs.MCMC.interval
    control.obs$MCMC.burnin <- control$obs.MCMC.burnin
    control.obs$MCMC.burnin.min <- control$obs.MCMC.burnin.min

    nws.obs <- lapply(nws, network.copy)
    statshifts.obs <- statshifts
  }
  # mcmc.init will change at each iteration.  It is the value that is used
  # to generate the MCMC samples.  init will never change.
  mcmc.init <- init
  finished <- FALSE

  for(iteration in 1:control$CD.maxit){
    if(iteration == control$CD.maxit) finished <- TRUE
    if(verbose){
      message("\nIteration ",iteration," of at most ", control$CD.maxit,
          " with parameter:")
      message_print(mcmc.init)
    }else{
      message("Iteration ",iteration," of at most ", control$CD.maxit,":")
    }

    # Obtain MCMC sample
    z <- ergm_CD_sample(nws, model, proposal, control, verbose=verbose, response=response, theta=mcmc.init)

    # post-processing of sample statistics:  Shift each row by the
    # vector model$nw.stats - model$target.stats, store returned nw
    # The statistics in statsmatrix should all be relative to either the
    # observed statistics or, if given, the alternative target.stats
    # (i.e., the estimation goal is to use the statsmatrix to find 
    # parameters that will give a mean vector of zero)
    statsmatrices <- mapply(sweep, z$stats, statshifts, MoreArgs=list(MARGIN=2, FUN="+"), SIMPLIFY=FALSE)
    for(i in seq_along(statsmatrices)) colnames(statsmatrices[[i]]) <- param_names(model,canonical=TRUE)
    statsmatrix <- do.call(rbind,statsmatrices)
    
    if(verbose){
      message("Back from unconstrained CD.")
      if(verbose>1){
        message("Average statistics:")
        message_print(colMeans(statsmatrix))
      }
    }
    
    ##  Does the same, if observation process:
    if(obs){
      z.obs <- ergm_CD_sample(nws.obs, model, proposal.obs, control.obs, verbose, response=response, theta=mcmc.init)

      statsmatrices.obs <- mapply(sweep, z.obs$stats, statshifts.obs, MoreArgs=list(MARGIN=2, FUN="+"), SIMPLIFY=FALSE)
      for(i in seq_along(statsmatrices.obs)) colnames(statsmatrices.obs[[i]]) <- param_names(model,canonical=TRUE)
      statsmatrix.obs <- do.call(rbind,statsmatrices.obs)
      
      if(verbose){
        message("Back from constrained CD.")
        if(verbose>1){
          message("Average statistics:")
          message_print(colMeans(statsmatrix.obs))
        }
      }
    }else{
      statsmatrices.obs <- statsmatrix.obs <- NULL
      z.obs <- NULL
    }

    # Compute the sample estimating functions and the convergence p-value. 
    esteq <- ergm.estfun(statsmatrix, mcmc.init, model)
    if(isTRUE(all.equal(apply(esteq,2,sd), rep(0,ncol(esteq)), check.names=FALSE))&&!all(esteq==0))
      stop("Unconstrained CD sampling did not mix at all. Optimization cannot continue.")
    esteq.obs <- if(obs) ergm.estfun(statsmatrix.obs, mcmc.init, model) else NULL   
    conv.pval <- suppressWarnings(approx.hotelling.diff.test(esteq, esteq.obs, assume.indep=TRUE)$p.value)
                                            
    # We can either pretty-print the p-value here, or we can print the
    # full thing. What the latter gives us is a nice "progress report"
    # on whether the estimation is getting better..
    if(verbose){
      message("Average estimating function values:")
      message_print(if(obs) colMeans(esteq.obs)-colMeans(esteq) else -colMeans(esteq))
    }
    message("Convergence test P-value:",format(conv.pval, scientific=TRUE,digits=2),"")
    if(conv.pval>control$CD.conv.min.pval){
      message("Convergence detected. Stopping.")
      finished <- TRUE
    }

    if(!estimate){
      if(verbose){message("Skipping optimization routines...")}
      l <- list(coef=mcmc.init, mc.se=rep(NA,length=length(mcmc.init)),
                sample=statsmatrix, sample.obs=statsmatrix.obs,
                iterations=1, MCMCtheta=mcmc.init,
                loglikelihood=NA, #mcmcloglik=NULL, 
                mle.lik=NULL,
                gradient=rep(NA,length=length(mcmc.init)), #acf=NULL,
                samplesize=control$MCMC.samplesize, failure=TRUE,
                newnetwork = nw)
      return(structure (l, class="ergm"))
    } 

    statsmatrix.0 <- statsmatrix
    statsmatrix.0.obs <- statsmatrix.obs
    if(control$CD.steplength=="adaptive"){
      if(verbose){message("Calling adaptive CD-MCMLE Optimization...")}
      adaptive.steplength <- 2
      statsmean <- apply(statsmatrix.0,2,mean)
      v <- list(loglikelihood=control$CD.adaptive.trustregion*2)
      while(v$loglikelihood > control$CD.adaptive.trustregion){
        adaptive.steplength <- adaptive.steplength / 2
        if(!is.null(statsmatrix.0.obs)){
          statsmatrix.obs <- t(adaptive.steplength*t(statsmatrix.0.obs) + (1-adaptive.steplength)*statsmean) # I.e., shrink each point of statsmatrix.obs towards the centroid of statsmatrix.
        }else{
          statsmatrix <- sweep(statsmatrix.0,2,(1-adaptive.steplength)*statsmean,"-")
        }
        if(verbose){message(paste("Using Newton-Raphson Step with step length",adaptive.steplength,"..."))}
        #
        #   If not the last iteration do not compute all the extraneous
        #   statistics that are not needed until output
        #
        v<-ergm.estimate(init=mcmc.init, model=model,
                         statsmatrix=statsmatrix, 
                         statsmatrix.obs=statsmatrix.obs, 
                         epsilon=control$epsilon,
                         nr.maxit=control$CD.NR.maxit,
                         nr.reltol=control$CD.NR.reltol,
                         calc.mcmc.se=FALSE, hessianflag=control$main.hessian,
                         trustregion=control$CD.trustregion, method=control$CD.method,
                         metric=control$CD.metric,
                         dampening=control$CD.dampening,
                         dampening.min.ess=control$CD.dampening.min.ess,
                         dampening.level=control$CD.dampening.level,
                         compress=control$MCMC.compress, verbose=verbose,
                         estimateonly=TRUE)
      }
      if(v$loglikelihood < control$CD.trustregion-0.001){
        current.scipen <- options()$scipen
        options(scipen=3)
        message("The log-likelihood improved by",
            format.pval(v$loglikelihood,digits=4,eps=1e-4),".")
        options(scipen=current.scipen)
      }else{
        message("The log-likelihood did not improve.")
      }
      steplen.hist <- c(steplen.hist, adaptive.steplength)
      steplen <- adaptive.steplength
    }else{
      if(verbose){message("Calling CD-MCMLE Optimization...")}
      steplen <-
        if(!is.null(control$CD.steplength.margin))
          .Hummel.steplength(
            if(control$CD.Hummel.esteq) esteq else statsmatrix.0[,!model$etamap$offsetmap,drop=FALSE], 
            if(control$CD.Hummel.esteq) esteq.obs else statsmatrix.0.obs[,!model$etamap$offsetmap,drop=FALSE],
            control$CD.steplength.margin, control$CD.steplength, steplength.prev=steplen, verbose=verbose,
            x2.num.max=control$CD.Hummel.miss.sample, steplength.maxit=control$CD.Hummel.maxit, control=control)
        else control$CD.steplength
      
      statsmean <- apply(statsmatrix.0,2,base::mean)
      if(!is.null(statsmatrix.0.obs)){
        statsmatrix.obs <- t(steplen*t(statsmatrix.0.obs) + (1-steplen)*statsmean) # I.e., shrink each point of statsmatrix.obs towards the centroid of statsmatrix.
      }else{
        statsmatrix <- sweep(statsmatrix.0,2,(1-steplen)*statsmean,"-")
      }
      steplen.hist <- c(steplen.hist, steplen)
      # stop if MCMLE is stuck (steplen stuck near 0)
      if ((length(steplen.hist) > 2) && sum(tail(steplen.hist,2)) < 2*control$CD.steplength.min) {
        stop("CD-MCMLE estimation stuck. There may be excessive correlation between model terms, suggesting a poor model for the observed data. If target.stats are specified, try increasing SAN parameters.")
      }    
      
      message("Optimizing with step length ",steplen,".")
      # Use estimateonly=TRUE if this is not the last iteration.
      v<-ergm.estimate(init=mcmc.init, model=model,
                       statsmatrix=statsmatrix, 
                       statsmatrix.obs=statsmatrix.obs, 
                       epsilon=control$epsilon,
                       nr.maxit=control$CD.NR.maxit,
                       nr.reltol=control$CD.NR.reltol,
                       calc.mcmc.se=FALSE, 
                       hessianflag=control$main.hessian,
                       trustregion=control$CD.trustregion, 
                       method=control$CD.method,
                       dampening=control$CD.dampening,
                       dampening.min.ess=control$CD.dampening.min.ess,
                       dampening.level=control$CD.dampening.level,
                       metric=control$CD.metric,
                       compress=control$MCMC.compress, verbose=verbose,
                       estimateonly=!finished)
      if(v$loglikelihood < control$CD.trustregion-0.001){
        current.scipen <- options()$scipen
        options(scipen=3)
        message("The log-likelihood improved by ",
            format.pval(v$loglikelihood,digits=4,eps=1e-4),".")
        options(scipen=current.scipen)
      }else{
        message("The log-likelihood did not improve.")
      }
    }
          
    mcmc.init <- v$coef
    coef.hist <- rbind(coef.hist, mcmc.init)
    stats.obs.hist <- NVL3(statsmatrix.obs, rbind(stats.obs.hist, apply(.[], 2, mean)))
    stats.hist <- rbind(stats.hist, apply(statsmatrix, 2, mean))
    if(finished) break # This allows premature termination.
  } # end of main loop

  # FIXME:  We should not be "tacking on" extra list items to the 
  # object returned by ergm.estimate.  Instead, it is more transparent
  # if we build the output object (v) from scratch, of course using 
  # some of the info returned from ergm.estimate.
  v$sample <- ergm.sample.tomcmc(statsmatrix.0, control) 
  if(obs) v$sample.obs <- ergm.sample.tomcmc(statsmatrix.0.obs, control)
  
  v$network <- nw.orig
  v$newnetwork <- nw
  v$coef.init <- init
  #v$initialfit <- initialfit
  v$est.cov <- v$mc.cov
  v$mc.cov <- NULL

  v$coef.hist <- coef.hist
  v$stats.hist <- stats.hist
  v$stats.obs.hist <- stats.obs.hist
  v$steplen.hist <- steplen.hist
  
  v$iterations <- iteration
  v$control <- control
  
  v$etamap <- model$etamap
  v
}

