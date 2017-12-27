#------------------------------pool-------------------------------

#'Multiple imputation pooling
#'
#'Pools the results of m repeated complete data analysis
#'
#'The function averages the estimates of the complete data model, computes the
#'total variance over the repeated analyses, and computes the relative increase
#'in variance due to nonresponse and the fraction of missing information. The
#'function relies on the availability of \enumerate{ \item the estimates of the
#'model, typically present as 'coefficients' in the fit object \item an
#'appropriate estimate of the variance-covariance matrix of the estimates per
#'analyses (estimated by \code{\link{vcov}}.  } The function pools also
#'estimates obtained with \code{lme()} and \code{lmer()}, BUT only the fixed
#'part of the model.
#'
#'@aliases pool
#'@param object An object of class \code{mira} (produced by \code{with.mids()} 
#'or \code{as.mira()}), or a \code{list} with model fits.
#'@param method A string describing the method to compute the degrees of
#'freedom.  The default value is "smallsample", which specifies the is
#'Barnard-Rubin adjusted degrees of freedom (Barnard and Rubin, 1999) for small
#'samples. Specifying a different string produces the conventional degrees of
#'freedom as in Rubin (1987).
#'@return An object of class \code{mipo}, which stands for 'multiple imputation
#'pooled outcome'. 
#'@seealso \code{\link{with.mids}}, \code{\link{as.mira}}, \code{\link{vcov}}
#'@references Barnard, J. and Rubin, D.B. (1999). Small sample degrees of
#'freedom with multiple imputation. \emph{Biometrika}, 86, 948-955.
#'
#'Rubin, D.B. (1987).  \emph{Multiple Imputation for Nonresponse in Surveys}.
#'New York: John Wiley and Sons.
#'
#'van Buuren S and Groothuis-Oudshoorn K (2011). \code{mice}: Multivariate
#'Imputation by Chained Equations in \code{R}. \emph{Journal of Statistical
#'Software}, \bold{45}(3), 1-67. \url{http://www.jstatsoft.org/v45/i03/}
#'
#'Pinheiro, J.C. and Bates, D.M. (2000).  \emph{Mixed-Effects Models in S and
#'S-PLUS}.  Berlin: Springer.
#'@keywords htest
#'@examples
#'
#'# which vcov methods can R find
#'methods(vcov)
#'
#'# 
#'imp <- mice(nhanes)
#'fit <- with(data=imp,exp=lm(bmi~hyp+chl))
#'pool(fit)
#'
#'#Call: pool(object = fit)
#'#
#'#Pooled coefficients:
#'#(Intercept)         hyp         chl 
#'#  22.01313    -1.45578     0.03459 
#'#
#'#Fraction of information about the coefficients missing due to nonresponse: 
#'#(Intercept)         hyp         chl 
#'#    0.29571     0.05639     0.38759 
#'#> summary(pool(fit))
#'#                 est      se       t     df Pr(>|t|)    lo 95    hi 95 missing
#'#(Intercept) 22.01313 4.94086  4.4553 12.016 0.000783 11.24954 32.77673      NA
#'#hyp         -1.45578 2.26789 -0.6419 20.613 0.528006 -6.17752  3.26596       8
#'#chl          0.03459 0.02829  1.2228  9.347 0.251332 -0.02904  0.09822      10
#'#               fmi
#'#(Intercept) 0.29571
#'#hyp         0.05639
#'#chl         0.38759
#'# 
#'
#'@export
pool <- function (object, method = "smallsample") {
  call <- match.call()
  if (!is.list(object)) stop("Argument 'object' not a list", call. = FALSE)
  object <- as.mira(object)
  m <- length(object$analyses)
  
  # deal with m = 1
  fa <- getfit(object, 1)
  if (m == 1) {
    warning("Number of multiple imputations m = 1. No pooling done.")
    return(fa)
  }
  
  rr <- pool.fitlist(getfit(object))

  fit <- c(list(call = call, call1 = object$call, call2 = object$call1,
                nmis = object$nmis, m = m), rr)
  oldClass(fit) <- c("mipo", oldClass(object))
  return(fit)
}

pool.fitlist <- function (fitlist) {
  # call broom to do the hard work
  v <- lapply(fitlist, glance) %>% bind_rows()
  w <- lapply(fitlist, tidy) %>% bind_rows()
  
  # residual degrees of freedom for hypothetically complete data
  dfcom <- v$df.residual[1]
  if (is.null(dfcom)) dfcom <- df.residual(fitlist[[1]])
  if (is.null(dfcom)) dfcom <- 99999
  
  # Rubin's rules
  group_by(w, .data$term) %>%
    summarize(m = n(),
              qbar = mean(.data$estimate),
              ubar = mean(.data$std.error ^ 2),
              b = var(.data$estimate),
              t = ubar + (1 + 1 / m) * b,
              r = (1 + 1 / m) * b / ubar,
              lambda = (1 + 1 / m) * b / t,
              dfcom = dfcom,
              dfold = (m - 1) / lambda ^ 2,
              dfobs = (dfcom + 1) / (dfcom + 3) * dfcom * (1 - lambda),
              df = dfold * dfobs / (dfold + dfobs),
              fmi = (r + 2 / (df + 3)) / (r + 1))
}

