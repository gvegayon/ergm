ergm.degeneracy<-function(xobs, theta0, model, statsmatrix,
                        epsilon=1e-10, nr.maxit=100,
                        verbose=FALSE, trace=6*verbose,
                        hessian=FALSE,
                        trustregion=20, ...) {
  samplesize <- dim(statsmatrix)[1]
  statsmatrix0 <- statsmatrix
  probs <- rep(1/nrow(statsmatrix0),nrow(statsmatrix0))
  statsmatrix0.miss <- NULL
  probs.miss <- NULL
  av <- apply(sweep(statsmatrix0,1,probs,"*"), 2, sum)
  xsim <- sweep(statsmatrix0, 2, av,"-")
  xsim.miss <- NULL
  probs.miss <- NULL
# xobs0 <- summary(model$formula)
  xobs <- -xobs - av
#
# Set up the initial estimate
#
  guess <- theta0
  if (verbose) cat("Converting theta0 to eta0\n")
  eta0 <- ergm.eta(theta0, model$etamap) #unsure about this
  model$etamap$theta0 <- theta0
#
# Log-Likelihood and gradient functions
#
  penalty <- 0.5
  if (verbose) cat("Optimizing loglikelihood\n")
  Lout <- try(optim(par=guess, 
                    fn=llik.fun, #  gr=llik.grad,
                    hessian=FALSE,
                    method="BFGS",
                    control=list(trace=trace,fnscale=-1,maxit=nr.maxit),
                    xobs=xobs,
                    xsim=xsim, probs=probs,
                    xsim.miss=xsim.miss, probs.miss=probs.miss,
                    penalty=0.5, trustregion=trustregion,
                    eta0=eta0, etamap=model$etamap))
  if(verbose){cat("Log-likelihood ratio is", Lout$value,"\n")}
  if(inherits(Lout,"try-error") || Lout$value > 199 ||
     Lout$value < -790) {
    cat("MLE could not be found. Degenerate!\n")
    cat("Nelder-Mead Log-likelihood ratio is ", Lout$value,"\n")
#   return(list(coef=theta0, 
#      loglikelihood=Lout$value))
  }
  theta <- Lout$par
  names(theta) <- names(theta0)
# c0  <- llik.fun(theta=Lout$par, xobs=xobs,
#                 xsim=xsim, probs=probs,
#                 xsim.miss=xsim.miss, probs.miss=probs.miss,
#                 penalty=0.5, eta0=eta0, etamap=model$etamap)
  loglikelihood <- Lout$value

# list(coef=theta, 
#      loglikelihood=loglikelihood)
  loglikelihood
}
