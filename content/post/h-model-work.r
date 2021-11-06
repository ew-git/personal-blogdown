library(manipulate)
# Two step ----------------------------------------------------------------

exact1 <- function(D, a, A, inf, r){
  times <- 1:A
  term1 <- D*sum(rep((1+a)/(1+r), A)^times)
  term2 <- D*((1+a)/(1+r))^A*(1+inf)/(r-inf)
  pv <- term1 + term2
  return(pv)
}

apx <- function(D, a, A, inf, r){
  pv <- D/(r-inf)*(1 + inf + A*(a - inf))
  return(pv)
}

exact1(1, 0.02, 5, 0.01, 0.05)
apx(1, 0.02, 5, 0.01, 0.05)

manipulate({
  aa <- seq(from=0, to=0.2, by = 0.01)
  plot(aa, sapply(aa, function(x) return(exact1(DD, x, AA, infinf, rr))),
       col = "black", type = "l")
  lines(aa, sapply(aa, function(x) return(apx(DD, x, AA, infinf, rr))),
        col = "red")
  abline(v=infinf, col = "green")
  abline(v=rr, col = "orange")
},  
DD=slider(1,2, initial = 1),
# a=slider(1,2, initial = 1),
AA=slider(1L,10L, initial = 5L),
infinf=slider(0.01,0.05, initial = 0.01),
rr=slider(0.01,0.2, initial = 0.1)
)

# Three step --------------------------------------------------------------

exact <- function(D, a, A, b, B, inf, r){
  term1 <- D*sum(rep((1+a)/(1+r), A)^(1:A))
  if (A < B){
    term2 <- D*((1+a)/(1+r))^A*sum(rep((1+b)/(1+r), B-A)^((A+1):B))
    term3 <- D*((1+a)/(1+r))^A*((1+b)/(1+r))^(B-A)*(1+inf)/(r-inf)
  } else {
    term2 <- 0
    term3 <- D*((1+a)/(1+r))^A*(1+inf)/(r-inf)
  }
  pv <- term1 + term2 + term3
  return(pv)
}

apx <- function(D, a, A, b, B, inf, r){
  pv <- D/(r-inf)*(1 + inf + A*(a - inf) + (B-A)*(b-inf))
  return(pv)
}

exact(1, 0.03, 3, 0.02, 5, 0.01, 0.05)
apx(1, 0.03, 3, 0.02, 5, 0.01, 0.05)

manipulate({
  aa <- seq(from=0, to=0.2, by = 0.01)
  values <- sapply(aa, function(x) return(exact(DD, x, AA, bb, BB, infinf, rr)))
  plot(aa, values,
       col = "black", type = "l", ylim=c(0, max(values)))
  lines(aa, sapply(aa, function(x) return(apx(DD, x, AA, bb, BB, infinf, rr))),
        col = "red")
  lines(aa, sapply(aa, function(x) return(exact(DD, x, AA, x, AA, infinf, rr))),
        lty="dashed")
  # abline(v=infinf, col = "green")
  # abline(v=rr, col = "orange")
  # abline(v=bb, col = "blue")
  # print(DD/(rr-infinf)*(1 + infinf + AA*(aa - infinf)))
  lines(aa, DD/(rr-infinf)*(1 + infinf + AA*(aa - infinf)), col = "red", lty="dashed")
  # print(DD/(rr-infinf)*(1 + infinf + (BB)*(bb - infinf)))
  abline(h=DD/(rr-infinf)*((BB-AA)*(bb - infinf)), col = "orange")
},  
DD=slider(1,2, initial = 1),
# a=slider(1,2, initial = 1),
AA=slider(1L,10L, initial = 9L),
bb=slider(0,.2, initial = .1192),
BB=slider(1L,10L, initial = 10L),
infinf=slider(0.01,0.05, initial = 0.03),
rr=slider(0.01,0.2, initial = 0.15)
)

obj <- function(x){
  DD=1
  #a
  AA=8L
  bb=.0152
  BB=10L
  infinf=0.04344
  rr=0.11564
  return(exact(DD, x, AA, bb, BB, infinf, rr) - apx(DD, x, AA, bb, BB, infinf, rr))
}

# obj(0.05)
result <- uniroot(obj, c(0.001, 0.05))
print(result$root)


# surface
library(plotly)
library(plot3D)

makeplots <- function(){
  A <- 9
  B <- 10
  ginf <- 0.03
  r <- 0.2
  rawa <- seq(from=0, to=0.2, by = 0.001)
  rawb <- seq(from=0, to=0.2, by = 0.001)
  df <- expand.grid(a = rawa, b = rawb)
  df$exact <- mapply(function(x, y) exact(1, x, A, y, B, ginf, r), df$a, df$b)
  df$apx <- mapply(function(x, y) apx(1, x, A, y, B, ginf, r), df$a, df$b)
  
  zmat <- matrix(xtabs(exact ~ a + b, data = df), nrow = length(rawa))
  zmatapx <- matrix(xtabs(apx ~ a + b, data = df), nrow = length(rawa))
  # fig <- plot_ly(x=rawa, y=rawb, z = zmat) %>%
  #   add_surface() %>%
  #   add_surface(z = zmatapx, colorscale = list(c(0, 1), c("tan", "blue"))) %>%
  #   layout(scene = list(xaxis=list(title = "a"), yaxis=list(title="b"),
  #                       zaxis=list(title = "PV")))
  # fig
  
  errormat <- zmatapx - zmat
  fig2 <- plot_ly(x=rawa, y=rawb, z = errormat, type = "contour",
                  autocontour = F,
                  contours = list(start = -.1,end = .1,size = 0.01))
  fig2
}
makeplots()


# apx evaluation ----------------------------------------------------------

apxcompare1 <- function(A, ga, r, ginf){
  x <- sum(((1+ga)/(1+r))^(1:A))
  y <- A*((ga-ginf)/(r-ginf))
  z <- ((1+ga)/(1+r))^A*(1+ginf)/(r-ginf)
  zz <- (1+ginf)/(r-ginf)
  return(c(x,y,z,zz))
}
apxcompare1(5, 0.11, 0.1, 0.02)

# h manip -----------------------------------------------------------------

exacth <- function(D, a, H, inf, r){
  h2 <- 2*H
  gs <- a - (a-inf)*((0:(h2-1))/(h2))
  ds <- cumprod(1+gs)
  term1 <- sum(ds*(1/(1+r))^(1:h2)) # present value of dividends during the linear decline
  term2 <- ds[h2]/(1+r)^h2*(1+inf)/(r-inf) # terminal value
  return(term1+term2)
}

apxh <- function(D, a, H, inf, r){
  pv <- D/(r-inf)*(1 + inf + H*(a - inf))
  return(pv)
}

plot_h <- function(D, H, inf, r){
  a <- seq(from=0, to=0.2, by = 0.01)
  plot(a, sapply(a, function(x) return(exacth(D, x, H, inf, r))),
       col = "black", type = "l", xlab = bquote(g[a]), ylab = "Present Value")
  lines(a, sapply(a, function(x) return(apxh(D, x, H, inf, r))),
        col = "red")
  abline(v=inf, col = "green")
  abline(v=r, col = "orange")
  legend(x = "topleft",
         legend = c("Exact PV", "Approximate PV", expression(g[infinity]), "r"),
         col = c("black", "red", "green", "orange"),
         lty = c(1,1,1,1))
}

manipulate({
  plot_h(1, H, inf, r)
}, H = slider(1, 10, 5), inf = slider(0.01, 0.1, 0.01), r = slider(0.05, 0.2, 0.15))

