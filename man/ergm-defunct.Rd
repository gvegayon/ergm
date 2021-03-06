% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ergm-defunct.R
\name{ergm-defunct}
\alias{ergm-defunct}
\alias{robust.inverse}
\alias{plot.network.ergm}
\alias{ergm.getterms}
\alias{plot.mcmc.list.ergm}
\alias{plot.ergm}
\alias{summary.statistics}
\alias{ergm.checkargs}
\alias{ergm.checkbipartite}
\alias{ergm.checkdirected}
\alias{summary.gof}
\alias{ergm.getMCMCsample}
\alias{ergm.MHP.table}
\alias{MHproposal}
\alias{MHproposal.character}
\alias{MHproposal.ergm}
\alias{MHproposal.formula}
\alias{ergm.init.methods}
\alias{ergm.ConstraintImplications}
\alias{ergm.mcmcslave}
\title{Functions that have been removed from this package}
\usage{
sociality(object, ...)

robust.inverse(H, tol = sqrt(.Machine$double.eps))

\method{plot}{network.ergm}(x, attrname = NULL,
  label = network.vertex.names(x), coord = NULL, jitter = TRUE,
  thresh = 0, usearrows = TRUE, mode = "fruchtermanreingold",
  displayisolates = TRUE, interactive = FALSE, xlab = NULL,
  ylab = NULL, xlim = NULL, ylim = NULL, pad = 0.2,
  label.pad = 0.5, displaylabels = FALSE, boxed.labels = TRUE,
  label.pos = 0, label.bg = "white", vertex.sides = 8,
  vertex.rot = 0, arrowhead.cex = 1, label.cex = 1, loop.cex = 1,
  vertex.cex = 1, edge.col = 1, label.col = 1, vertex.col = 2,
  label.border = 1, vertex.border = 1, edge.lty = 1,
  label.lty = NULL, vertex.lty = 1, edge.lwd = 0,
  label.lwd = par("lwd"), edge.len = 0.5, edge.curve = 0.1,
  edge.steps = 50, loop.steps = 20, object.scale = 0.01,
  uselen = FALSE, usecurve = FALSE, suppress.axes = TRUE,
  vertices.last = TRUE, new = TRUE, layout.par = NULL,
  cex.main = par("cex.main"), cex.sub = par("cex.sub"), seed = NULL,
  latent.control = list(maxit = 500, trace = 0, dyadsample = 10000,
  penalty.sigma = c(5, 0.5), nsubsample = 200), colornames = "rainbow",
  verbose = FALSE, latent = FALSE, ...)

ergm.getterms(formula)

\method{plot}{mcmc.list.ergm}(...)

\method{plot}{ergm}(x, ...)

\method{summary}{statistics}(...)

ergm.checkargs(fname, arglist, varnames = NULL, vartypes = NULL,
  defaultvalues = list(), required = NULL)

ergm.checkbipartite(fname, nw.bipartiteflag, requirement,
  extramessage = "")

ergm.checkdirected(fname, nw.directedflag, requirement,
  extramessage = "")

\method{summary}{gof}(object, ...)

ergm.getMCMCsample(nw, model, MHproposal, eta0, control, verbose = FALSE,
  response = NULL, update.nws = TRUE, ...)

ergm.MHP.table(...)

MHproposal(...)

MHproposal.character(...)

MHproposal.ergm(...)

MHproposal.formula(...)

ergm.init.methods(...)

ergm.ConstraintImplications(...)

ergm.mcmcslave(Clist, MHproposal, eta0, control, verbose, ...,
  prev.run = NULL, burnin = NULL, samplesize = NULL,
  interval = NULL, maxedges = NULL)
}
\arguments{
\item{x, minsize, center, cov, inverted, ..., object, statistics, formula, init, nsim, burnin, interval, constraints, prop.weights, prop.args, seed, drop, ninflast, V, tol, g, print, nw, radius, probs, n, cols, control, statistic, H}{Arguments to defunct functions.}
}
\description{
Functions that have been removed after a period of deprecation.
}
\keyword{internal}
