test_IntensityData <- function() {
  # simulate data
  ncfile <- tempfile()
  simulateIntensityMatrix(n.snps=10, n.chromosomes=26,
                         n.samples=20, filename=ncfile, file.type="ncdf")
  nc <- NcdfIntensityReader(ncfile)
  scanID <- getScanID(nc)
  sex <- c(rep("M", 10), rep("F", 10))
  plate <- rep(paste("batch", 1:4, sep=""), 5)
  scandf <- data.frame(scanID=scanID, sex=sex, plate=plate)
  scanAnnot <- ScanAnnotationDataFrame(scandf)
  snpID <- getSnpID(nc)
  chrom <- getChromosome(nc)
  pos <- getPosition(nc)
  rsID <- paste("rs", snpID, sep="")
  snpdf <- data.frame(snpID=snpID, chromosome=chrom, position=pos, rsID=rsID,
                      stringsAsFactors=FALSE)
  snpAnnot <- SnpAnnotationDataFrame(snpdf)

  # creation with only ncdf
  obj <- IntensityData(nc)
  checkTrue(!hasSnpAnnotation(obj))
  checkTrue(!hasScanAnnotation(obj))
  # creation with only snpAnnot
  obj <- IntensityData(nc, snpAnnot=snpAnnot)
  checkTrue(hasSnpAnnotation(obj))
  checkTrue(!hasScanAnnotation(obj))
  # creation with only scanAnnot
  obj <- IntensityData(nc, scanAnnot=scanAnnot)
  checkTrue(!hasSnpAnnotation(obj))
  checkTrue(hasScanAnnotation(obj))
  # creation with both annotations
  obj <- IntensityData(nc, snpAnnot=snpAnnot, scanAnnot=scanAnnot)
  checkTrue(hasSnpAnnotation(obj))
  checkTrue(hasScanAnnotation(obj))

  # required variables
  x <- getX(obj)
  checkIdentical(c(nsnp(obj),nscan(obj)), dim(x))
  checkIdentical(length(getSnpID(obj)), nsnp(obj))
  checkIdentical(length(getChromosome(obj)), nsnp(obj))
  checkIdentical(length(getPosition(obj)), nsnp(obj))
  checkIdentical(length(getScanID(obj)), nscan(obj))

  # annotation variables - snp
  checkTrue(is.character(getSnpVariableNames(obj)))
  checkTrue(hasSnpVariable(obj, "rsID"))
  checkTrue(!hasSnpVariable(obj, "foo"))
  checkIdentical(NULL, getSnpVariable(obj, "foo"))
  # annotation variables - scan
  checkTrue(is.character(getScanVariableNames(obj)))
  checkTrue(hasSex(obj))
  checkTrue(hasScanVariable(obj, "plate"))
  checkTrue(!hasScanVariable(obj, "foo"))
  checkIdentical(NULL, getScanVariable(obj, "foo"))

  # annotation mismatch
  snpAnnot <- snpAnnot[1:100,]
  checkException(GenotypeData(nc, snpAnnot=snpAnnot))
  scanAnnot$scanID[1] <- 25L
  checkException(GenotypeData(nc, scanAnnot=scanAnnot))

  close(obj)
  unlink(ncfile)
}
