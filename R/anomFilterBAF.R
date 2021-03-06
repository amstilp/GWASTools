############
mergeSeg<-function(segs,snum,ch,cL,cR, base.mean,base.sd,sd.reg,sd.long,num.mark.thresh,long.num.mark.thresh,low.frac.used,

  low.frac.used.num.mark,baf.raw,baf.dat,index,braw.base.med,small.thresh, dev.sim.thresh, LRR,snp.ids,intid ) { 

#segs is data.frame of DNAcopy segments from sample snum and chromosome ch

# cL and cR: left and right indices of centromere for the given chrom ch
#############################
runTrue2<-function(ss){
  if(class(ss)!="logical")stop("input needs to be logical")
  r<-rle(ss)
  vals<-r[[2]]
  lens<-r[[1]]
  nv<-length(vals)
  endp<-cumsum(lens)  #end positions of each run
  stp<-c(1,endp[1:(nv-1)]+1)
  wt<-which(vals & lens>=2)
  if(length(wt)==0) return(NULL)
  endt<-endp[wt]
  stt<-stp[wt]
  out<-list(stt,endt)
  names(out)<-c("start","end")   # start and end of runs of TRUE
  return(out)
}
########################



if(!is.element(class(segs),"data.frame")) stop("segment data is not a data.frame")
if(dim(segs)[1]==0)stop("error: no segment info given to merge")
colm<-c("scanID","chrom","left","right","num.mark","seg.mean","sd.fac","sex")
if(!all(is.element(colm,names(segs)))){
 stop("incorrect column variables for segs - must be c(scanID,chrom,left,right,num.mark,seg.mean,sd.fac,sex)")}

if(!all(segs$scanID==snum))stop("data.frame of segments needs to be from same sample")
if(!all(segs$chrom==ch))stop("data.frame of segments needs to be from same chromosome")

sx<-segs$sex[1]
an<-segs[order(segs$left),]

an$merge<-FALSE
nms<-names(an)
if(dim(an)[1]<2) return(an)

frac.used<-an$num.mark/(an$right-an$left+1)
  # denom is total number of markers in between, including intensity only
  # this would make it more likely for frac.used to be smaller
  # would be an unusual anom and would probably not want to merge
  
  s1<-an$sd.fac>=sd.reg
  s2<-an$num.mark>long.num.mark.thresh & an$sd.fac>=sd.long
  s<-s1|s2
  s3<-frac.used>low.frac.used | an$num.mark >= low.frac.used.num.mark
  ss<-s & s3  # T for ones above threshold and not low.frac or above threshold and more markers if is low frac
  out<-runTrue2(ss)
  if(is.null(out)) return(an)
  endt<-out$end
  stt<-out$start

######## determine type: gain (1), loss (2), neutral (3)
      

## break up sets if 'type' changes
  selgood<-is.element(intid,snp.ids)
     stt2<-NULL;endt2<-NULL 
     for(i in 1:length(stt)){
       ind<-stt[i]:endt[i]
       tmp<-an[ind,]  #set of consecutive anoms

       tmp$type<-2
       for(jk in 1:nrow(tmp)){
         seg<-tmp[jk,]
         ledge<-seg$left;redge<-seg$right
         int<- intid>=intid[ledge] & intid<=intid[redge]  # $left and right are intid values
         sel<-int&selgood
         lrrseg<-LRR[sel]
         medlrr<-median(lrrseg,na.rm=TRUE)
         sdlrr<-sd(lrrseg,na.rm=TRUE)
         if(medlrr>0.3*sdlrr) tmp$type[jk]<-3
         if(medlrr< -0.3*sdlrr) tmp$type[jk]<-1
       }      

       ts<-tmp$type
       r<-rle(ts)
       vals<-r[[2]]
       lens<-r[[1]]
       nv<-length(vals)
       endp<-cumsum(lens)  #end positions of each run
       stp<-c(1,endp[1:(nv-1)]+1)
       wt<-which(lens>=2)
       if(length(wt)==0){endt2<-endt2;stt2<-stt2} else {
          endt2<-c(endt2,ind[endp[wt]])
          stt2<-c(stt2,ind[stp[wt]])
       }
     }
     if(is.null(stt2)|is.null(endt2)) return(an)  # after accounting for type, no consec anoms
     stt<-stt2;endt<-endt2  #stt and endt record sets as we go along

  ## have used 'type' and no longer need it
   
########

## break sets up if cross centromere

   if(!is.null(cL) & !is.null(cR)){
    # skip acrocentric; cL and cR  are indices of intid; left and right are indices of intid

     bk<-NULL
     for(i in 1:length(stt)){
       ind<-stt[i]:endt[i]
       tmp<-an[ind,]  #set of consecutive anoms
       
       nn<-nrow(tmp)  # will be at least 2
       J<-0
       for(j in 1:(nn-1)){
         if(tmp$right[j]<=cL & tmp$left[j+1]>=cR) {
             J<-j; break
         }
       }
       if(J!=0){bk<-c(i,J); break}
     }

     if(!is.null(bk)){
        ii<-bk[1];J<-bk[2]
        ind<-stt[ii]:endt[ii]
        if(length(stt)==1){
           stt2<-c(stt[ii],ind[J+1])
           endt2<-c(ind[J],endt[ii])
        }
        if(length(stt)>1){
          if(ii==1){
            stt2<-c(stt[ii],ind[J+1],stt[(ii+1):length(stt)])
            endt2<-c(ind[J],endt[ii:length(endt)])
          } else {
            if(ii==length(stt)){
              stt2<-c(stt[1:ii],ind[J+1])
              endt2<-c(endt[1:(ii-1)],ind[J],endt[ii:length(endt)]) 
            } else { 
            stt2<-c(stt[1:ii],ind[J+1],stt[(ii+1):length(stt)])
            endt2<-c(endt[1:(ii-1)],ind[J],endt[ii:length(endt)])  
            }
          }  
        }
        sdiff<-endt2-stt2+1
        sel<-sdiff>=2
        stt<-stt2[sel]; endt<-endt2[sel]   
     }
     if(length(stt)==0) return(an) 
   }

     
  del.merge<-NULL
  merged.anoms<-NULL 

  for(i in 1:length(stt)){
     cnt<-0
     mrg<-list()
     ind<-stt[i]:endt[i]
     tmp<-an[ind,]

## compute baf.dev.med
    tmp$baf.dev.med<-NA
    for(jjj in 1:nrow(tmp)){
         tmp2<-tmp[jjj,]
         set1<-index>=tmp2$left & index<=tmp2$right # indices that are baf eligible
         abf<-baf.raw[set1]
         bf.dev<-abs(abf-braw.base.med)
         tmp$baf.dev.med[jjj]<-median(bf.dev,na.rm=TRUE)
    }

       #create strings of T/F depending upon num.mark
     sel<-tmp$num.mark>=num.mark.thresh
     tmp$ok<-FALSE
     tmp$ok[sel]<-TRUE


     if(all(tmp$ok)) next # if all intervals meet num.mark threshold, keep separate

     if(all(!tmp$ok)){ # none meet num.mark threshold
        ss<-tmp$sd.fac>=small.thresh
        out<-runTrue2(ss)
        if(!is.null(out)){
           st<-out$start; ed<-out$end
           nk<-length(st)
           for(ii in 1:nk){
              cnt<-cnt+1
              mrg[[cnt]]<-st[ii]:ed[ii]  #indicates intervals to merge
           }
        }
    ### ADD CODE for indicating merging results for that set
        if(length(mrg) !=0){
          dt<-unlist(mrg)
          del.merge<-c(del.merge,ind[dt])
          tpmerge<-NULL
          for(jj in 1:length(mrg)){
             x<-mrg[[jj]]
             a1<-ind[x[1]];a2<-ind[x[length(x)]]  
             set1<-a1:a2
             new.left<-an$left[a1];new.right<-an$right[a2]
             new.num.mark<-sum(an$num.mark[set1])
             new.seg.mean<-sum(an$seg.mean[set1]*an$num.mark[set1])/new.num.mark
             new.sdfac<-abs(new.seg.mean-base.mean)/base.sd
             new<-data.frame(snum,ch,new.left,new.right,new.num.mark,new.seg.mean,new.sdfac,sx,TRUE,stringsAsFactors=FALSE)
             names(new)<-c("scanID","chrom","left","right","num.mark","seg.mean","sd.fac","sex","merge")

             merged.anoms<-rbind(merged.anoms,new)

          }
        }

      next   # go to next set - which will restart cnt
     }
           
  # find positions of the T's
    ww<-which(tmp$ok)
 
 # initial block of potential F's in front of first T
    k1<-ww[1] #position of first T

    if(k1==2){
       if(tmp$sd.fac[1]>=small.thresh){
          cnt<-cnt+1;mrg[[cnt]]<-c(1,2)   #merge if only one F before first T and meets thresh
       }
    }
    if(k1==3){
       if(tmp$sd.fac[k1-1]>=small.thresh & tmp$sd.fac[k1-2]<small.thresh){
         cnt<-cnt+1
         mrg[[cnt]]<-c(k1-1,k1)   # FFT with first F not high but second F is
       } else {
         if(tmp$sd.fac[k1-1]>=small.thresh & tmp$sd.fac[k1-2]>=small.thresh){
           cnt<-cnt+1
           mrg[[cnt]]<-c(k1-2,k1-1) # both F's high - merge them together
         }
       }
    }
    if(k1>3){
      if(tmp$sd.fac[k1-1]>=small.thresh & tmp$sd.fac[k1-2]<small.thresh){
         flag<-1;ix<-1:(k1-3)} else {flag<-0; ix<-1:(k1-1)
      }  # sets of F's to consider looking for consec sd.fac large
      ss<-tmp$sd.fac[ix]>=small.thresh
      out<-runTrue2(ss)
      if(!is.null(out)){
         st<-out$start; ed<-out$end
         nk<-length(st)
         for(ii in 1:nk){
            cnt<-cnt+1
            mrg[[cnt]]<-ix[st[ii]:ed[ii]]
         }
      }
      if(flag==1){
         cnt<-cnt+1; mrg[[cnt]]<-c(k1-1,k1)  # add on merging the FT to the sets of preceding consec F's that get merged
      }
    }
 # end initial block
    if(length(ww)>1){
      for(kk in 2:length(ww)){
         ki<-ww[kk]
         kip<-ww[kk-1]
         df<-ki-kip
         if(df==1) next  #we have 2 T's consecutive
         if(df==2){ # TFT configuration

           mnbd<-min(tmp$baf.dev.med[ki],tmp$baf.dev.med[kip])
           if(mnbd==0) relerr<-10 else relerr<-abs(tmp$baf.dev.med[ki]-tmp$baf.dev.med[kip])/mnbd
           if(relerr<=dev.sim.thresh){# 
              cnt<-cnt+1
              mrg[[cnt]]<-kip:ki
           } else { #deciding which T interval to merge the F interval with
              df1<-abs(tmp$baf.dev.med[kip]-tmp$baf.dev.med[kip+1])
              df2<-abs(tmp$baf.dev.med[ki] - tmp$baf.dev.med[kip+1])
              cnt<-cnt+1
              if(df1<df2)mrg[[cnt]]<-kip:(kip+1) else mrg[[cnt]]<-(kip+1):ki 
           }
         }
         if(df==3){ # TFFT configuration
           sm<-tmp$num.mark[kip+1]+tmp$num.mark[kip+2]
           mnbd<-min(tmp$baf.dev.med[k1],tmp$baf.dev.med[kip])
           if(mnbd==0) relerr<-10 else relerr<-abs(tmp$baf.dev.med[ki]-tmp$baf.dev.med[kip])/mnbd
           if(sm>=num.mark.thresh){              
                   cnt<-cnt+1; mrg[[cnt]]<-(kip+1):(kip+2)
           } else {
               if(relerr<=dev.sim.thresh){ # if the T's similar, merge them with the F's
                  cnt<-cnt+1
                  mrg[[cnt]]<-kip:ki
               } else { # determine which T each F merges with, if any
                  ws1<-c(kip,kip+1); ws2<-c(kip+2,ki)
                  if(tmp$sd.fac[kip+1]>=small.thresh){cnt<-cnt+1;mrg[[cnt]]<-ws1}
                  if(tmp$sd.fac[kip+2]>=small.thresh){cnt<-cnt+1;mrg[[cnt]]<-ws2}
               }
            }
          }
          if(df>3){  # just look for runs of F's with enough evidence
            ix<-(kip+1):(ki-1)
            ss<-tmp$sd.fac[ix]>=small.thresh
            out<-runTrue2(ss)
            if(!is.null(out)){
              st<-out$start; ed<-out$end
              nk<-length(st)
              for(ii in 1:nk){
                cnt<-cnt+1
                mrg[[cnt]]<-ix[st[ii]:ed[ii]]
              }
            }
          }
      } # end of loop for 'middle' runs
    } # end if on length of ww

   # block of potential F's after last T
    kf<-ww[length(ww)] 
    kd<-nrow(tmp)- kf   # number of F's after the last T
    if(kd==1) {
        if(tmp$sd.fac[kf+1]>=small.thresh){cnt<-cnt+1;mrg[[cnt]]<-c(kf,kf+1) }
    }
    if(kd==2){ # TFF  
      c1<-tmp$sd.fac[kf+1]>=small.thresh
      c2<-tmp$sd.fac[kf+2]>=small.thresh
      if(c1&c2){ cnt<-cnt+1; mrg[[cnt]]<-c(kf+1,kf+2)} # still possible for it to get eliminated later if sum of num.mark too small
      if(c1&!c2) {cnt<-cnt+1; mrg[[cnt]]<-c(kf,kf+1) } 
    }
    if(kd>2){
      c1<-tmp$sd.fac[kf+1]>=small.thresh
      c2<-tmp$sd.fac[kf+2]>=small.thresh
      if(c1 & !c2){
         flag<-1; ix<-(kf+3):nrow(tmp) } else {
         flag<-0; ix<-(kf+1):nrow(tmp)
      }
      ss<-tmp$sd.fac[ix]>=small.thresh
      out<-runTrue2(ss)
      if(!is.null(out)){
         st<-out$start; ed<-out$end
         nk<-length(st)
         for(ii in 1:nk){
            cnt<-cnt+1
            mrg[[cnt]]<-ix[st[ii]:ed[ii]]
         }
      }
      if(flag==1){
         cnt<-cnt+1; mrg[[cnt]]<-c(kf,kf+1)  # add on initial TF merge
      }
    }

####
## for given set i, we now have mrg with sets of indices to merge - check/deal with overlaps   
## although clearly baf.dev.med 'similarity' is not transitive, there is no good way to control the degree of transitivity
## is have string of overlaps, how to decide which pieces to merge is not easy
## so most cases, transitivity works well enough
## i.e. if sets overlap, combine them
    msets<-length(mrg)
    if(msets>1){
      ovlap<-rep(FALSE,msets-1)
      for(m in 1:(msets-1)){
        if(length(intersect(mrg[[m]],mrg[[m+1]]))!=0) ovlap[m]<-TRUE
      }
      r<-rle(ovlap)
      vals<-r[[2]]
      lens<-r[[1]]      
                   
      nv<-length(vals)
      endp<-cumsum(lens)  #end positions of each run
      stp<-c(1,endp[1:(nv-1)]+1)
      wT<-which(vals==TRUE)
      if(length(wT) ==0){ mrg2<-mrg} else {
        used<-NULL
        cnt2<-0
        mrg2<-list()
        for(kl in 1:length(wT)){
           cnt2<-cnt2+1
           s1<-stp[wT[kl]];e1<-endp[wT[kl]]
           cm<-s1:(e1+1)
           a<-mrg[cm]
           used<-c(used,cm)
           mrg2[[cnt2]]<-unique(c(a,recursive=TRUE))
        }
        oth<-setdiff(1:length(mrg),used)
        if(length(oth)!=0){
          for(ij in 1:length(oth)){
            sel<-oth[ij]
            cnt2<-cnt2+1
            mrg2[[cnt2]]<-mrg[[sel]]
          }
        }
      } 
    } else mrg2<-mrg  


    ### ADD CODE for indicating merging results for that set
        if(length(mrg2) !=0){
          dt<-unlist(mrg2)
          del.merge<-c(del.merge,ind[dt])
          tpmerge<-NULL
          for(jj in 1:length(mrg2)){
             x<-mrg2[[jj]]
             a1<-ind[x[1]];a2<-ind[x[length(x)]]
             set1<-a1:a2
             new.left<-an$left[a1];new.right<-an$right[a2]
             new.num.mark<-sum(an$num.mark[set1])
             new.seg.mean<-sum(an$seg.mean[set1]*an$num.mark[set1])/new.num.mark
             new.sdfac<-abs(new.seg.mean-base.mean)/base.sd
             new<-data.frame(snum,ch,new.left,new.right,new.num.mark,new.seg.mean,new.sdfac,sx,TRUE,stringsAsFactors=FALSE)
             names(new)<-c("scanID","chrom","left","right","num.mark","seg.mean","sd.fac","sex","merge")

             merged.anoms<-rbind(merged.anoms,new)

          }
        }
          
  } # end of loop on i (number of sets of consec anoms)     

   if(length(del.merge)!=0){
      tmp<-an[-del.merge,names(merged.anoms)]

      out<-rbind(tmp,merged.anoms)
      out<-out[order(out$left),]
   } else out<-an

return(out)
          
                 
} #end function
#########

###### delHomoRuns ##############
## function to possibly narrow segments found containing homo del
# look for adjustment for selected anoms
# to identify homozygous deletions
# looking for run of lrr values < lrr.cut then narrow to this run
# (BAF DNAcopy tends to not segment these well - often occur in longer homozygous runs)

delHomoRuns<-function(anoms,sid,eligible,intid,LRR,run.size,inter.size,
   low.frac.used,lrr.cut,ct.thresh,frac.thresh){
#run.size - min length of run
#inter.size - number of homozygotes allowed to "interrupt" run
#low.frac.used - fraction of markers used compared to number of markers in interval
#lrr.cut-look for runs of lrr values below lrr.cut
#ct.thresh - minimum number of lrr values below lrr.cut needed in order to process
#frac.thresh - process only if (# lrr values below lrr.cut)/(# eligible lrr in interval) > frac.thresh
#anoms: data.frame of anomalies  scanID, chrom, left, right, num.mark, seg.mean, sd.fac, sex, merge

if(!is.element("data.frame",class(anoms))) stop("anoms needs to be a data.frame")
annames<-c("scanID","chrom","left","right","num.mark","seg.mean","sd.fac","sex","merge")
if(!all(is.element(annames,names(anoms)))) stop("anoms does not have required variable names")
if(length(unique(anoms$scanID))!=1) stop("anoms needs to be for one sample")

anoms.rev<-NULL

for(I in 1:dim(anoms)[1]){
  an<-anoms[I,]
  snum<-an$scanID; chr<-an$chrom
  ledge<-an$left;redge<-an$right
  sindex <- which(is.element(sid, snum))
  if(length(sindex)==0) stop(paste("Sample ",snum, " does not exist",sep=""))

##want to look for runs only in the already identified anomaly
  int<-intid>=intid[ledge] & intid<=intid[redge]  #$left and $right are indices of intid
  selgood<-is.element(intid,eligible)
  index<-which(selgood&int)

  lrr <- LRR[index]
  wn<-!is.na(lrr)
  lrr<-lrr[wn]
  index<-index[wn]

  whm<-lrr< lrr.cut
  ct<-sum(whm)
  frac<-ct/length(index)
  an$low.ct<-ct
  an$nmark.lrr<-length(index)
  pct<-an$num.mark/(an$right-an$left+1)
  w<-frac>frac.thresh | pct<low.frac.used
  if(ct< ct.thresh |!w){
     an$old.left<-an$left; an$old.right<-an$right
     anoms.rev<-rbind(anoms.rev,an)
     next
  }
  who<-!whm
  lrr[whm]<-0
  lrr[who]<-1

  rgt<-NULL;lft<-NULL
  w<-rle(as.vector(lrr))
  #w<-rle(  ) has w[[1]] = lengths of runs, w[[2]] corresponding values
  vals<-w[[2]];lngs<-w[[1]]
  r0<-vals

  rlen<-length(r0)
  if(rlen==1){  # keep original if only one value    
     an$old.left<-an$left; an$old.right<-an$right
     anoms.rev<-rbind(anoms.rev,an)
     next  
  }

##establish initial positions of alternating runs
  endp<-cumsum(lngs)
  in.pos<-c(1,endp[1:(rlen-1)]+1)

##merging intervals if separated by < inter.size no. of undesirable values
# assuming sum of lengths of desirable intervals on either side meets run.size criterion

  tpos<-which(r0==1&lngs<=inter.size) #identify small runs of homos
  smf<-which(r0==0 & lngs<run.size) #identify 'small' runs of hets
  if(length(tpos)!=0){
    if(tpos[1]==1) {
     if(lngs[2]>=run.size){r0[1]<-0}
     tpos<-tpos[-1]}
     if(length(tpos)!=0){
       if(tpos[length(tpos)]==rlen) {
          tpos<-tpos[-length(tpos)]; if(lngs[rlen-1]>=run.size) {r0[rlen]<-0}}
     if(length(tpos)!=0){
        for(k in tpos){if((lngs[k-1]+lngs[k+1])>=run.size) {r0[k]<-0}
        }
  }} }

##want smaller runs of 0s to become runs of undesirable but not if they
 #are part of a combined run
run2<-rle(r0)
vals2<-run2[[2]];lngs2<-run2[[1]]
w0<-which(vals2==0 & lngs2>1)
if(length(w0)==0){r0[smf]<-1} else {
index.set<-NULL
for(j in 1:length(w0)){ if(w0[j]==1){start<-1} else {start<-sum(lngs2[1:(w0[j]-1)])+1}
end<-sum(lngs2[1:w0[j]])
index.set<-c(index.set,start:end)}
smf.use<-setdiff(smf,intersect(smf,index.set))
r0[smf.use]<-1}

##after merging some of the initial runs, we get modified listing of r0 vals
## look for runs here; e.g. if run of two 0s that means that initially
#we had a run of desirable with small run of undesirable - rle length of 2 then indicates
#putting those two original runs together as one run of desirable 
new.rle<-rle(r0)
nvals<-new.rle[[2]]
nlens<-new.rle[[1]]  ##indicates how many of original runs to put together
if(length(nvals)==1){ #all now classified as undesirable or as desirable = no change
   an$old.left<-an$left; an$old.right<-an$right
   anoms.rev<-rbind(anoms.rev,an)
   next  
 }
 
newt<-which(nvals==0) #newt could be empty if originally there were no long het/miss runs
if(length(newt)==0){     
    an$old.left<-an$left; an$old.right<-an$right
    anoms.rev<-rbind(anoms.rev,an)
    next  
 }
 

left<-NULL
right<-NULL
### if newt indicates runs of 0s, change initial and end positions of 
#runs of desired accordingly
if(newt[1]==1){left<-c(left,1);right<-c(right,in.pos[nlens[1]+1]-1);newt<-newt[-1]}
for(k in newt){ind<-sum(nlens[1:(k-1)]);left<-c(left,in.pos[ind+1])
kl<-length(newt);kk<-newt[kl]
if((ind+1+nlens[kk])<=length(in.pos)){
right<-c(right,in.pos[ind+1+nlens[k]]-1)} else {right<-c(right,length(index))}}
##right and left positions are indices of lrr (= indices of index)

## if splits into more than one run, leave as the original 
if(length(right)==0|length(left)==0|length(right)>1|length(left)>1){
     an$old.left<-an$left; an$old.right<-an$right
     anoms.rev<-rbind(anoms.rev,an)
     next  
   }

## there is one adjusted interval found

an$old.left<-an$left;an$old.right<-an$right
an$left<-index[left];an$right<-index[right] 
anoms.rev<-rbind(anoms.rev,an)
 } #end loop on anomalies
return(anoms.rev)
 }
###############################
anomFilterBAF<-function(intenData, genoData, segments, snp.ids,
   centromere,low.qual.ids=NULL,
  num.mark.thresh=15,long.num.mark.thresh=200,sd.reg=2,sd.long=1,
  low.frac.used=.1,run.size=10,inter.size=2,low.frac.used.num.mark=30,
   very.low.frac.used=.01,low.qual.frac.num.mark=150,
  lrr.cut= -2,ct.thresh=10,frac.thresh=.1,verbose=TRUE,

  small.thresh=2.5, dev.sim.thresh=0.1, centSpan.fac=1.25, centSpan.nmark=50){

##segments - data.frame to determine which are anomalous
 # names of data.frame must include "scanID","chromosome","num.mark","left.index","right.index","seg.mean"
 # assume have segmented each chromosome (at least all autosomes) for a given sample
##snp.ids: vector of eligible snp ids
##centromere: data.frame with centromere position info
## low.qual.ids: sample numbers determined to be messy for which segments are filtered
#     based on num.mark and fraction used
## num.mark.thresh: minimum size of segment to consider for anomaly
## long.num.mark.thresh: min number of markers for "long" segment
 # (significance threshold allowed to be lower)
## sd.reg: number of standard deviations from segment mean 
 # compared to a baseline mean for "normal" needed to declare segment anomalous
## sd.long: same meaning as sd. long but applied to "long" segments
## low.frac.used: fraction used to declare a segment with 
 # low number hets or missing compared with number of markers in interval 
## run.size, inter.size: for possible determination of homozygous deletions 
 # (see description in delHomoRuns function above)
## low.frac.used.num.mark: used in final step of deleting "small" low frac.used segments
 # which tend to be false positives (after determining homo deletions)
## very.low.frac.used: any segments with (num.mark)/(number of markers in interval) less than this are filtered out
## low.qual.frac.num.mark: num.mark threshold for messy samples
##lrr.cut-look for runs of lrr values below lrr.cut to adjust homo del endpts
##ct.thresh - minimum number of lrr values below lrr.cut needed in order to adjust
##frac.thresh - adjust only if (# lrr values below lrr.cut)/(# eligible lrr in interval) > frac.thresh

 ##small.thresh - sd.fac threshold used in making merge decisions involving small num.mark segments
 ##dev.sim.thresh - relative error threshold for determining similarity in BAF deviations; used in merge decisions  
 ## centSpan.fac - thresholds increased by this factor when considering filtering of centromere pieces
 ## centSpan.nmark - minimum number of markers for centromere cross
          
                 
#############################
  # check that intenData has BAF
  if (!hasBAlleleFreq(intenData)) stop("BAlleleFreq not found in intenData")
  
  # check that dimensions of intenData and genoData are equal
  intenSnpID <- getSnpID(intenData)
  genoSnpID <- getSnpID(genoData)
  if (!all(intenSnpID == genoSnpID)) stop("snp dimensions of intenData and genoData differ")
  intenScanID <- getScanID(intenData)
  genoScanID <- getScanID(genoData)
  if (!all(intenScanID == genoScanID)) stop("scan dimensions of intenData and genoData differ")
  
  # check that sex is present in annotation
  if (hasSex(intenData)) {
    sex <- getSex(intenData)
  } else if (hasSex(genoData)) {
    sex <- getSex(genoData)
  } else stop("sex not found in intenData or genoData")

  intid <- intenSnpID


  if(!all(is.element(snp.ids,intid))) stop("eligible snps not contained in snp ids")

  sid <- intenScanID
  chrom <- getChromosome(intenData)
  Pos <- getPosition(intenData)
  
  if(!is.element(class(segments),"data.frame")) stop("data is not a data.frame")
  chk<-is.element(c("scanID","chromosome","num.mark","left.index","right.index","seg.mean"),names(segments))
  if(!all(chk)) stop("Error in names of columns of data")
  if(!is.element(class(centromere),"data.frame")) stop("centromere info is not a data.frame")
  cchk<-is.element(c("chrom","left.base","right.base"),names(centromere))
  if(!all(cchk)) stop("Error in names of centromere data.frame")
  centromere$chrom[is.element(centromere$chrom, "X")] <- XchromCode(intenData)
  centromere$chrom[is.element(centromere$chrom, "Y")] <- YchromCode(intenData)
  centromere$chrom[is.element(centromere$chrom, "XY")] <- XYchromCode(intenData)
  centromere$chrom <- as.integer(centromere$chrom)

  # internal functions require these names, so convert from package standard
  names(segments)[names(segments) == "chromosome"] <- "chrom"
  names(segments)[names(segments) == "left.index"] <- "left"
  names(segments)[names(segments) == "right.index"] <- "right"

  ##delete any segments from male samples on chromosome X
  male<-sid[is.element(sex,"M")] 
  wdel<-is.element(segments$scanID,male)&segments$chrom==XchromCode(intenData)
  anoms<-segments[!wdel,]
  anoms<-anoms[order(anoms$scanID,anoms$chrom),]

  #find unsegmented chromosomes 
  smpchr<-paste(anoms$scanID,anoms$chrom)
  dup<-which(duplicated(smpchr))
  sng<-which(!is.element(smpchr,smpchr[dup]))
  anoms.sngl<-anoms[sng,]  #unsegmented chromosomes

  ######
  anoms2<-NULL  #raw with sd factor
  anoms.fil<-NULL #filtered
  normal.info<-NULL
  seg.info<-NULL
  samples<-unique(anoms$scanID)
  NS<-length(samples)
  for(i in 1:NS){
     snum<-samples[i]

     if(floor(i/10)*10-i==0 & verbose==TRUE){
       message(paste("processing ",i,"th scanID out of ",NS,sep=""))
     }

    sindex <- which(is.element(sid, snum))
    if(length(sindex)==0) stop(paste("Sample ",snum, " does not exist",sep=""))

    GENO <- getGenotype(genoData, snp=c(1,-1), scan=c(sindex,1))

    ## compute baf metric 
    sel<-is.element(intid,snp.ids) & (GENO == 1 | is.na(GENO))

    baf <- getBAlleleFreq(intenData, snp=c(1,-1), scan=c(sindex,1))
    ws<-!is.na(baf)

    INDEX<-which(sel&ws)
    CHR<-chrom[sel&ws]
    BAF<-baf[sel&ws]

    index<-NULL
    chr<-NULL
    baf.dat<-NULL

    baf.raw<-NULL

    uuch<-unique(anoms$chrom)
    uch<-uuch[uuch!=XYchromCode(intenData)]
    for(ch in uch){
      wc<-CHR==ch    #T/F for indices of CHR which match indices of INDEX,BAF
      bf<-BAF[wc]
      ind<-INDEX[wc]
      chrm<-CHR[wc]
      med<-median(bf,na.rm=TRUE)
      bf1<-1-bf
      bfm<-abs(bf-med)
      c<-cbind(bf,bf1,bfm)
      met<-apply(c,1,min)
      baf.metric<-sqrt(met)
      index<-c(index,ind)
      chr<-c(chr,chrm)
      baf.dat<-c(baf.dat,baf.metric)   
      
      baf.raw<-c(baf.raw,bf)
     
    } #end of chrom loop

    an<-anoms[is.element(anoms$scanID,snum),]
    an.sngl<-anoms.sngl[is.element(anoms.sngl$scanID,snum),]
  
    sel.chr.all<-an.sngl$chrom  
    if(sum(duplicated(an.sngl$chrom))!=0) stop(paste("Error in singletons for Sample ",snum,sep=" "))
    ## treat X chromosome and XY differently
    # not included in baseline but do need to be compared
    wX<-which(sel.chr.all==XchromCode(intenData))
    wps<-which(sel.chr.all==XYchromCode(intenData)) 
    if(length(wX)==0 & length(wps)==0){ sel.chr<-sel.chr.all} else {sel.chr<-sel.chr.all[-union(wX,wps)]}

    if(length(sel.chr)<2) {w.selec<-which(!is.element(chr,c(XchromCode(intenData),XYchromCode(intenData))))} else { 
  
      ##compare each autosome seg.mean with baseline based on other autosomes
      an.snglo<-an.sngl[order(an.sngl$seg.mean,decreasing=TRUE),]
      an.snglo<-an.snglo[is.element(an.snglo$chrom,sel.chr),]
      sel.chro<-an.snglo$chrom  #decreasing order of seg.mean so work with largest mean sequentially
      N<-length(sel.chro)  #sel.chro are autosome chroms unsegmented
      
      flag<-1
      j<-1
      while(flag==1){ 
        w.selec<-is.element(chr,sel.chro[(j+1):N])
        bbase<-baf.dat[w.selec]
        base.mean<-mean(bbase,na.rm=TRUE)
        base.sd<-sd(bbase,na.rm=TRUE)
        mean.chk<-an.snglo$seg.mean[is.element(an.snglo$chrom,sel.chro[j])]
        if(abs(mean.chk-base.mean)/base.sd >sd.long){
          if((N-j)==1) {flag<-0;keep<-N}
          j<-j+1
        }  else {keep<- j:N; flag<-0} 
      }#end while
      w.selec<-is.element(chr,sel.chro[keep])
    } #end of else - selection of unsegmented chroms to use
  
    ##baseline now based on autosome unsegmented not identified as whole chrom anoms

    bbase<-baf.dat[w.selec]
    base.mean<-mean(bbase,na.rm=TRUE)
    base.sd<-sd(bbase,na.rm=TRUE)
    sd.fac<-abs(an$seg.mean-base.mean)/base.sd
    
    braw.base<-baf.raw[w.selec]
    braw.base.med<-median(braw.base,na.rm=TRUE)

    if(length(sel.chr)<2){chr.ct<-0} else {chr.ct<-length(sel.chro[keep])}

    normi<-data.frame(snum,base.mean,base.sd,braw.base.med,chr.ct)
    names(normi)<-c("scanID","base.mean","base.sd","base.baf.med","chr.ct")

    normal.info<-rbind(normal.info,normi)


    an$sd.fac<-sd.fac
    an$sex<-sex[sindex]

    anoms2<-rbind(anoms2,an)

    ##an is segment/sd.fac info for the given sample
    ## base.mean and base.sd are for the given sample
    ##anoms2 now contains segment info along with sd.fac info - accumulating over samples


########## Centromere spanning, Merging

    an<-an[order(an$chrom,an$left),]
    an.seg.info<-NULL

    CHR<-unique(an$chrom)
    CHR<-CHR[CHR!=XYchromCode(intenData)]

    LRR <- getLogRRatio(intenData, snp=c(1,-1), scan=c(sindex,1))
    
    an3.fil<-NULL
    for(ch in CHR){

      anch<-an[an$chrom==ch,]
      if(dim(anch)[1]==0) next
      nsegs<-dim(anch)[1]
      tp<-data.frame(snum,ch,nsegs)
      names(tp)<-c("scanID","chrom","num.segs")

      an.seg.info<-rbind(an.seg.info,tp) 

## cent-span code insert here
      centL<-centromere$left.base[centromere$chrom==ch]
      centR<-centromere$right.base[centromere$chrom==ch] 
      cleft<-chrom==ch & Pos<centL & is.element(intid,index) # baf eligible
      cright<-chrom==ch & Pos>centR & is.element(intid,index)
      if(sum(cleft) == 0) {cL<-NULL; cR<-NULL} else {
         cLL<-max(intid[cleft])
         cRR<-min(intid[cright])
         cL<-which(intid==cLL)
         cR<-which(intid==cRR)  # left and right are indices of intid
         w<-anch$left<=cL & anch$right>=cR
         if(sum(w)!=0){ # segment spans centromere - will be at most one
           ach<-anch[w,]
           anrest<-anch[!w,]
             # check if segment passes basic filter 
     
           s2<-ach$num.mark>=centSpan.nmark & ach$sd.fac>=sd.reg
           s3<-ach$num.mark>long.num.mark.thresh& ach$sd.fac>=sd.long
           s<-(s2|s3) 
           if(!s){anch<-anrest} else {
  
 # if passes filter, split into two pieces, one on either side of centromere
              tmp<-ach  # 
              tmp$right<-cL
              tmp2<-ach
              tmp2$left<-cR

              tmpmarkers<-intid>=intid[tmp$left] & intid<=intid[tmp$right]
              tmplrr<-is.element(intid,snp.ids) & tmpmarkers
              tmpbaf<-index>=tmp$left & index<=tmp$right

              tmp2markers<-intid>=intid[tmp2$left] & intid<=intid[tmp2$right]
              tmp2baf<-index>=tmp2$left & index<=tmp2$right
              tmp2lrr<-is.element(intid,snp.ids) & tmp2markers   


      # recompute/compute basic features for each piece
              tmp$num.mark<-sum(tmpbaf)
              tmp2$num.mark<-sum(tmp2baf)
              tmp$seg.mean<-mean(baf.dat[tmpbaf],na.rm=TRUE)
              tmp2$seg.mean<-mean(baf.dat[tmp2baf],na.rm=TRUE)
              tmp$sd.fac<-abs(tmp$seg.mean-base.mean)/base.sd
              tmp2$sd.fac<-abs(tmp2$seg.mean-base.mean)/base.sd
              tmp$frac.used<-tmp$num.mark/sum(tmplrr)
              tmp2$frac.used<-tmp2$num.mark/sum(tmp2lrr)

      # test each piece for passing (somewhat more stringent) filter
              s1<-tmp$num.mark>=centSpan.fac*num.mark.thresh
              if(tmp$num.mark< 3*centSpan.fac* num.mark.thresh){
                 s2<-tmp$sd.fac>=centSpan.fac*sd.reg & tmp$frac.used>= centSpan.fac* low.frac.used
              } else {
                 s2<-tmp$sd.fac>=centSpan.fac*sd.reg
              } 
              s3<-tmp$num.mark>long.num.mark.thresh& tmp$sd.fac>=sd.long
              t1<-(s2|s3) & s1

              s1<-tmp2$num.mark>=centSpan.fac*num.mark.thresh
              if(tmp2$num.mark< 3* centSpan.fac*num.mark.thresh){
                 s2<-tmp2$sd.fac>=centSpan.fac*sd.reg & tmp$frac.used>= centSpan.fac*low.frac.used
              } else {
                 s2<-tmp2$sd.fac>=centSpan.fac*sd.reg
              } 
              s3<-tmp2$num.mark>long.num.mark.thresh& tmp2$sd.fac>=sd.long
              t2<-(s2|s3) & s1

              if(!t1 & !t2) anch<-anrest   #delete both failed
              if(t1 & !t2) anch<-rbind(anrest,tmp[,names(anch)]) # delete one fail, keep other OK
              if(!t1 & t2) anch<-rbind(anrest,tmp2[,names(anch)])
              if(t1&t2){ # check same type and similar baf.dev (width)

               # gain, loss, neutral
                tlrr<-LRR[tmplrr]
                mtlrr<-median(tlrr,na.rm=TRUE); sdtlrr<-sd(tlrr,na.rm=TRUE)
                tmp$type<-3
                if(mtlrr> 0.3*sdtlrr) tmp$type<-1
                if(mtlrr< -0.3*sdtlrr) tmp$type<-2
              # gain, loss, neutral    
                t2lrr<-LRR[tmp2lrr]
                mt2lrr<-median(t2lrr,na.rm=TRUE); sdt2lrr<-sd(t2lrr,na.rm=TRUE)
                tmp2$type<-3
                if(mt2lrr> 0.3*sdt2lrr)  tmp2$type<-1
                if(mt2lrr< -0.3*sdt2lrr) tmp2$type<-2
                q<-tmp$type==tmp2$type

                br<-baf.raw[tmpbaf]
                tmp$baf.dev.med<-median(abs(br-braw.base.med),na.rm=TRUE)
                br2<-baf.raw[tmp2baf]
                tmp2$baf.dev.med<-median(abs(br2-braw.base.med),na.rm=TRUE)

                mbd<-min(tmp$baf.dev.med,tmp2$baf.dev.med)
                if(mbd==0) relerr<-1 else relerr<-abs(tmp$baf.dev.med-tmp2$baf.dev.med)/mbd
                q2<-relerr<=dev.sim.thresh

                if(!q | !q2) { # keep each piece separate
                  anch<-rbind(anrest,tmp[,names(anch)],tmp2[,names(anch)])
                }
               # note at this stage, anch hasn't changed
              }
       
           }
           if(nrow(anch)==0) next
           anch<-anch[order(anch$left),] 
         }
      }             




      tmp2<-mergeSeg(anch,snum,ch,cL,cR,base.mean,base.sd,sd.reg,sd.long,num.mark.thresh,long.num.mark.thresh,low.frac.used,low.frac.used.num.mark,baf.raw,baf.dat,index,braw.base.med,small.thresh, dev.sim.thresh, LRR,snp.ids,intid ) ## merged for given samp/chrom
     
      tst.rev<-delHomoRuns(tmp2,sid,snp.ids,intid,LRR,
        run.size,inter.size,low.frac.used,lrr.cut,ct.thresh,frac.thresh)

      diff.right<-tst.rev$old.right-tst.rev$right
      diff.left<-tst.rev$old.left-tst.rev$left
      d.keep<-NULL
      tst.rev$homodel.adjust<-FALSE
      for(k in 1:dim(tst.rev)[1]) {
        if(diff.right[k]==0 & diff.left[k]==0) next
        d.keep<-c(d.keep,k)
        int2<-intid>=intid[tst.rev$left[k]] & intid<=intid[tst.rev$right[k]]
        selgood<-is.element(intid,snp.ids)
        whm<- GENO == 1 | is.na(GENO)
        index2<-which(int2&selgood&whm)  
        mt<-is.element(index,index2)
        seg.mn<-mean(baf.dat[mt],na.rm=TRUE)
        sdf<-abs(seg.mn-base.mean)/base.sd
        tst.rev$num.mark[k]<-length(index2)
        tst.rev$sd.fac[k]<-sdf
        tst.rev$seg.mean[k]<-seg.mn  
      }
      if(length(d.keep)!=0) tst.rev$homodel.adjust[d.keep]<-TRUE
       # want to include small homo dels originally found exactly (so not adjusted)
      ct<-tst.rev$low.ct
      nlrr<-tst.rev$nmark.lrr
      ws<-which(ct>=ct.thresh & ct/nlrr>=.9) 
      #keeps homo dels found exactly (didn't need adjustment) that might be too small to pass further filters
      d.keep<-union(d.keep,ws)
      colm<-c("scanID","chrom","left","right","num.mark","seg.mean","sd.fac","sex","merge","homodel.adjust")
      tst.rev<-tst.rev[,colm]
     


    ######## FILTER ######################

       s1<-d.keep #will keep any homo dels found
      s2<-tst.rev$num.mark>=num.mark.thresh& tst.rev$sd.fac>=sd.reg
      s3<-tst.rev$num.mark>long.num.mark.thresh& tst.rev$sd.fac>=sd.long
      s<-which(s2|s3)
      filin<-union(s,d.keep)
      fil<-tst.rev[filin,]

      an3.fil<-rbind(an3.fil,fil) #becomes filtered anoms for current sample
    }#end ch loop


    anoms.fil<-rbind(anoms.fil,an3.fil)

    seg.info<-rbind(seg.info,an.seg.info)

  } #end of sample loop
  anoms2<-anoms2[order(anoms2$scanID,anoms2$chrom,anoms2$left),] #raw annotated
  anoms2$left.base <- getPosition(intenData, index=anoms2$left)
    anoms2$right.base <- getPosition(intenData, index=anoms2$right)

  if(!is.null(anoms.fil)){
    anoms.fil<-anoms.fil[order(anoms.fil$scanID,anoms.fil$chrom,anoms.fil$left),]

    # convert index to base position
    anoms.fil$left.base <- getPosition(intenData, index=anoms.fil$left)
    anoms.fil$right.base <- getPosition(intenData, index=anoms.fil$right)
  }

  ## XY filter
  tmp<-anoms2[anoms2$chrom==XYchromCode(intenData),]
  if(dim(tmp)[1]!=0){
    s1<-tmp$num.mark>=num.mark.thresh& tmp$sd.fac>=sd.reg
    s2<-tmp$num.mark>long.num.mark.thresh& tmp$sd.fac>=sd.long
    if(sum(s1|s2)!=0){
      an.XY<-tmp[s1|s2,]
      an.XY$merge<-NA
      an.XY$homodel.adjust<-NA
      an.XY$left.base<-getPosition(intenData, index=an.XY$left)
      an.XY$right.base<-getPosition(intenData, index=an.XY$right)} else an.XY<-NULL
    anoms.fil<-rbind(anoms.fil,an.XY)
    an.seg.info<-NULL
    s<-unique(tmp$scanID)
    for(snum in s){ 
      an<-tmp[tmp$scanID==snum,]
      ns<-dim(an)[1]
      tt<-data.frame(snum,XYchromCode(intenData),ns)
      names(tt)<-c("scanID","chrom","num.segs")
      an.seg.info<-rbind(an.seg.info,tt)
    }
    seg.info<-rbind(seg.info,an.seg.info)
  }


  ## further filtering based on low.frac.used and/or messiness
  if(!is.null(anoms.fil)& dim(anoms.fil)[1]!=0){
    nf<-dim(anoms.fil)[1]  
    frac.used<-NULL
    for(kk in 1:nf){
      int<-intid>=intid[anoms.fil$left[kk]] & intid<=intid[anoms.fil$right[kk]]
      selgood<-is.element(intid,snp.ids)
      int.ok<-int&selgood
      frac.used<-c(frac.used,anoms.fil$num.mark[kk]/sum(int.ok)) 
    }
    anoms.fil$frac.used<-frac.used 
    wd1<-anoms.fil$frac.used<=very.low.frac.used
    wd2<-anoms.fil$frac.used<low.frac.used & anoms.fil$num.mark<low.frac.used.num.mark
    if(!is.null(low.qual.ids)){
      wd3<-anoms.fil$frac.used<low.frac.used & anoms.fil$num.mark<low.qual.frac.num.mark & is.element(anoms.fil$scanID,low.qual.ids)
    }
    wdel<-wd1 | wd2 
    if(!is.null(low.qual.ids)) wdel<-wdel|wd3
    anoms.fil<-anoms.fil[!wdel,]
  }
  seg.info<-seg.info[order(seg.info$scanID,seg.info$chrom),]
  out<-list(anoms2,anoms.fil,normal.info,seg.info)
  names(out)<-c("raw","filtered","base.info","seg.info")
  
  # convert back to package standard names
  for (i in 1:length(out)) {
    if ("chrom" %in% names(out[[i]]))
      names(out[[i]])[names(out[[i]]) == "chrom"] <- "chromosome"
    if ("left" %in% names(out[[i]]))
      names(out[[i]])[names(out[[i]]) == "left"] <- "left.index"
    if ("right" %in% names(out[[i]]))
      names(out[[i]])[names(out[[i]]) == "right"] <- "right.index"
  }

  return(out)
} #end of function

