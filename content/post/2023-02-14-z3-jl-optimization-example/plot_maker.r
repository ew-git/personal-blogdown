library(rgl)

mm = 20

r2 = c(0, 0, 0)
locations2 <- cbind(x = c(r2[1]), y = c(r2[2]), z = c(r2[3]))
for (xi in -mm:mm) {
  for (yi in -mm:mm) {
    for (zi in -mm:mm) {
      if (abs(xi-r2[1]) + abs(yi-r2[2]) + abs(zi-r2[3]) == 6) {
        locations2 <- rbind(locations2, cbind(x = c(xi), y = c(yi), z = c(zi)))
      }
    }
  }
}

r2 = c(3, 3, 2)
locations3 <- cbind(x = c(r2[1]), y = c(r2[2]), z = c(r2[3]))
for (xi in -mm:mm) {
  for (yi in -mm:mm) {
    for (zi in -mm:mm) {
      if (abs(xi-r2[1]) + abs(yi-r2[2]) + abs(zi-r2[3]) == 4) {
        locations3 <- rbind(locations3, cbind(x = c(xi), y = c(yi), z = c(zi)))
      }
    }
  }
}

r2 = c(-2, -3, 1)
locations4 <- cbind(x = c(r2[1]), y = c(r2[2]), z = c(r2[3]))
for (xi in -mm:mm) {
  for (yi in -mm:mm) {
    for (zi in -mm:mm) {
      if (abs(xi-r2[1]) + abs(yi-r2[2]) + abs(zi-r2[3]) == 5) {
        locations4 <- rbind(locations4, cbind(x = c(xi), y = c(yi), z = c(zi)))
      }
    }
  }
}

r2 = c(-8, 1, 1)
locations5 <- cbind(x = c(r2[1]), y = c(r2[2]), z = c(r2[3]))
for (xi in -mm:mm) {
  for (yi in -mm:mm) {
    for (zi in -mm:mm) {
      if (abs(xi-r2[1]) + abs(yi-r2[2]) + abs(zi-r2[3]) == 3) {
        locations5 <- rbind(locations5, cbind(x = c(xi), y = c(yi), z = c(zi)))
      }
    }
  }
}

locations <- locations2
for (i in 1:nrow(locations))
  shade3d(translate3d(cube3d(scaleMatrix(0.5, 0.5, 0.5), col = "#4063D8", alpha=0.5), 
                      x=locations[i,1], y = locations[i, 2], z = locations[i, 3]))

locations <- locations3
for (i in 1:nrow(locations))
  shade3d(translate3d(cube3d(scaleMatrix(0.5, 0.5, 0.5), col = "#389826", alpha=0.5), 
                      x=locations[i,1], y = locations[i, 2], z = locations[i, 3]))

locations <- locations4
for (i in 1:nrow(locations))
  shade3d(translate3d(cube3d(scaleMatrix(0.5, 0.5, 0.5), col = "#9558B2", alpha=0.5), 
                      x=locations[i,1], y = locations[i, 2], z = locations[i, 3]))

locations <- locations5
for (i in 1:nrow(locations))
  shade3d(translate3d(cube3d(scaleMatrix(0.5, 0.5, 0.5), col = "#CB3C33", alpha=0.5), 
                      x=locations[i,1], y = locations[i, 2], z = locations[i, 3]))