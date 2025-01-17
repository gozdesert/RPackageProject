#' Functional Principal Analysis using Correlation Matrix
#'
#'Extract eigen-functions from smoothed correlation matrix which comes from a Gaussian latent model.
#'
#' @param X a numeric matrix (n x p). It is supplied by user. Here n is the number of samples and p is the number of observations.
#' @param types  a vector of length p representing the type of each of the p variables in \code{X}. For our case, it is "con". Users can learn more about it here: \code{\link[latentcor]{latentcor}}.
#' @param argvals the argument values of the function evaluations in Y, defaults to a equidistant grid from 0 to 1.
#' @param nbasis number of B-spline basis functions used for estimation of the mean function and bivariate smoothing of the covariance surface.
#' @param pve  proportion of variance explained: used to choose the number of principal components. It should be supplied by users.The default is 0.99. (See \code{\link[refund]{fpca.sc}}.)
#' @param npc  the number of principal components.if it is given, this overrides pve; the default is NULL. (See \code{\link[refund]{fpca.sc}}.)
#'
#' @return A list with the elements
#'   \item{npc}{The number of principal components. If it is given, the given value. Otherwise it is calculated in the function based on given \code{pve}}
#'   \item{eigenfuncs}{A (p x npc) matrix where its colums are eigenfunction extracted from the smoothed correlation matrix.}
#'
#' @export
#'
#' @examples
#' #To see the difference when we have 2 different pve values.
#' # set.seed(53787)
#' #Create a matrix from Gaussian latent data
#' X = gaussian_copula_cor(n = 10, ntime = 30)$Y
#' #Example 1
#' output1 = fpcaCor(X = X, types = "con", argvals = NULL, nbasis = 10, pve = 0.99, npc = NULL)
#' ## Change pve value to obtain a different number of eigen-functions.
#' #Example 2
#'output2 = fpcaCor(X = X, types = "con", argvals = NULL, nbasis = 10, pve = 0.95, npc = NULL)
#' #Example 3
#' #If pnc is supplied by user. (npc overrides pve.)
#' output3 = fpcaCor(X = X, types = "con", argvals = NULL, nbasis = 10, pve = 0.95, npc = 5)
#'
fpcaCor = function(X = NULL, types = "con", argvals = NULL, nbasis = 10, pve = 0.99, npc = NULL){

  if(!is.matrix(X)){
    stop("X must be a matrix!")
  }
  I = nrow(X)
  D = ncol(X)
  #compatibility checks
  if (!is.null(npc)){
    if(npc >  D){
      stop("The number of principal components must be less than the number of columns of X")
    }
  }

  #First we find Khat for our case we choose Rpointwise
  mylist = latentcor(X, types = types) #use latentcor funct to calculate the correlation matrix
  Khat = mylist$Rpointwise

  #now we smooth Khat to get Ktilde
  # we use the code coming from fpca.sc function
  dia.Khat = diag(Khat)
  diag(Khat) = NA  #we ignore diagonal elements first
  #Take the upper triangular part of Khat
  ut.Khat = upper.tri(Khat, diag = TRUE)
  ut.Khat[2, 1] <- ut.Khat[ncol(Khat), ncol(Khat) - 1] <- TRUE
  #next step we need to calculate
  cov.count = matrix(0, D, D)
  #construct a matrix just taking the elements not equal to NA
  for (i in 1:I) {
    obs.points = which(!is.na(X[i, ]))
    cov.count[obs.points, obs.points] = cov.count[obs.points, obs.points] + 1
  }
  usecov.count <- cov.count
  usecov.count[2, 1] <- usecov.count[ncol(Khat), ncol(Khat) - 1] <- 0
  usecov.count <- as.vector(usecov.count)[ut.Khat]
  use <- as.vector(ut.Khat)
  vKhat <- as.vector(Khat)[use]   #make it vector

  #since we will use argument values NULL default, we take the part where we generate argument values
  argvals = seq(0, 1, length = D)

  row.vec = rep(argvals, each = D)[use]
  col.vec = rep(argvals, times = D)[use]
  mCov = gam(vKhat ~ te(row.vec, col.vec, k = nbasis), weights = usecov.count)

  Ktilde = matrix(NA, D, D) #to get the smooth cor mat we create a matrix
  spred = rep(argvals, each = D)[upper.tri(Ktilde, diag = TRUE)]
  tpred =  rep(argvals, times = D)[upper.tri(Ktilde, diag = TRUE)]
  smVCov = predict(mCov, newdata = data.frame(row.vec = spred, col.vec = tpred))
  Ktilde[upper.tri(Ktilde, diag = TRUE)] = smVCov
  Ktilde[lower.tri(Ktilde)] = t(Ktilde)[lower.tri(Ktilde)]

  #now we obtain Ktilde and we want to extract the efunctions from Ktilde
  # Here the number of evalues or eigenfunctions is depend on the choice of pve or npc
  #I need to write another function for quadWeights
  w = my_quadWeights(argvals = argvals, method = "trapezoidal")
  Wsqrt <- diag(sqrt(w))
  Winvsqrt <- diag(1/(sqrt(w)))
  V <- Wsqrt %*% Ktilde %*% Wsqrt
  evalues = eigen(V, symmetric = TRUE, only.values = TRUE)$values
  evalues = replace(evalues, which(evalues <= 0), 0)
  # npc = prespecified value for the number of principal components. default = NULL
  # pve = proportion of variance explained: used to choose the number of principal components.
  npc = ifelse(is.null(npc), min(which(cumsum(evalues)/sum(evalues) > pve)), npc)
  #now we can find eigenfunctions of Ktilde matrix
  efunctions = matrix(Winvsqrt %*% eigen(V, symmetric = TRUE)$vectors[, seq(len = npc)], nrow = D, ncol = npc)
  #evalues = eigen(V, symmetric = TRUE, only.values = TRUE)$values[1:npc]
  #Kdoubletilde = efunctions %*% tcrossprod(diag(evalues, nrow = npc, ncol = npc), efunctions)
  return(list(eigenfuncs = efunctions, npc = npc))
}



