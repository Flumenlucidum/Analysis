##SKAT_gene_SSD function
SKAT_gene_SSD<-function(anno,bfile,resultfilename,cov=NULL,method='SKAT',Is.binary,genefunc=c(),exonicfunc=c(),number=1000,leaveSSD=F,plinkver=2){
  #making fam_cov file 
  #object for continuous phenotype
  if(!Is.binary){
    if(!is.null(cov)){
      File.Fam<-paste0(bfile,'.fam')
      File.Cov<-cov
      Fam_cov<-Read_Plink_FAM_Cov(File.Fam,File.Cov,Is.binary = F)
      y<-Fam_cov$Phenotype
      obj<-SKAT_Null_Model(y~as.matrix(Fam_cov[,7:ncol(Fam_cov)]),out_type='C')
      
    }else{
      File.Fam<-paste0(bfile,'.fam')
      Fam_cov<-Read_Plink_FAM(File.Fam,Is.binary=F)
      y<-Fam_cov$Phenotype
      obj<-SKAT_Null_Model(y~1,out_type='C')
    }
  }  
  
  #object for binary phenotype
  if(Is.binary){
    if(!is.null(cov)){
      File.Fam<-paste0(bfile,'.fam')
      File.Cov<-cov
      Fam_cov<-Read_Plink_FAM_Cov(File.Fam,File.Cov,Is.binary = T)
      y<-Fam_cov$Phenotype
      obj<-SKAT_Null_Model(y~as.matrix(Fam_cov[,7:ncol(Fam_cov)]),out_type='D',data=Fam_cov,Adjustment=F)
      
    }else{
      File.Fam<-paste0(bfile,'.fam')
      Fam_cov<-Read_Plink_FAM(File.Fam,Is.binary=T)
      y<-Fam_cov$Phenotype
      obj<-SKAT_Null_Model(y~1,out_type='D',data=Fam_cov,Adjustment=F)
    }
  } 
  
  #change the name of the snps ID to prevent duplication
  command<-paste0(' --bfile ',bfile, ' --set-all-var-ids @:#:\\$r:\\$a --new-id-max-allele-len 300 --make-bed --out changed_',bfile)
  if(plinkver==1){
    system2('./plink',command,wait=T)
  }else{
    system2('./plink2',command,wait=T)
  }
  anno<-fread(anno,fill=T)
  genelist<-unique(anno$Gene.refGene)
  #for the binary phenotype, use SKATBinary.SSD.All 
  
  if(Is.binary){
    #read 1000 genes each time (default, possible to change the number variable)
    quotient<-floor(length(genelist)/number)
    
    for (k in 1:quotient){
      
      #make SetID and snps list file for the first 1000 genes
      SetID<-data.frame('GENE'=NA,'SNP'=NA)
      snps_selected<-data.frame('SNP'=NA)
      
      for (i in c((1+(k-1)*number):(number*k))){
        
        exon_id<-which(anno$Gene.refGene==genelist[i] & anno$Func.refGene %in% genefunc & (anno$ExonicFunc.refGene %in% exonicfunc | anno$ExonicFunc.refGene =='.') )
        
        #only for the gene with the snps with the condition fulfilled
        if (length(exon_id)>0){
          #get the annovar result file only for the part of the gene
          #which fulfilled the condition
          anno_gene<-anno[exon_id,1:16]    
          
          for (j in 1:length(exon_id)){
            #aggregate the info in annovar file to get the same name as changed snp name
            snp_name<-paste0(as.character(anno_gene[j,1]),':',as.character(anno_gene[j,2]),':',as.character(anno_gene[j,4]),':',as.character(anno_gene[j,5]))
            row<-c(anno_gene[j,7],snp_name)
            snps_selected<-rbind(snps_selected,snp_name)
            SetID<-rbind(SetID,row)
          }
        }
      }
      
      #In case of the empty SetID file, skip to the next cycle
      if(dim(SetID)[1]!=1 & dim(snps_selected)[1]!=1){
        
        #Remove the first columns of the SetID and snps_selected because they are NA
        SetID<-SetID[2:nrow(SetID),]
        snps_selected<-snps_selected[2:dim(snps_selected)[1],]
        
        #write SetID file and list of snps to be included
        if(!leaveSSD){
          write.table(SetID,file=paste0('selected_',bfile,'.SetID'),row.names = F,quote = F,col.names = F)
        }else{
          write.table(SetID,file=paste0('selected_',as.character(k),bfile,'.SetID'),row.names = F,quote = F,col.names = F)
        }
        
        write.table(snps_selected,file=paste0('selected_',bfile,'_snps.txt'),row.names =F,quote = F,col.names = F)
        
        command<-paste0(' --bfile changed_',bfile, ' --extract selected_',bfile,'_snps.txt --make-bed --out selected_',bfile)
        if(plinkver==1){
          system2('./plink',command,wait=T)
        }else{
          system2('./plink2',command,wait=T)
        }
        File.Bed<-paste0('selected_',bfile,'.bed')
        File.Bim<-paste0('selected_',bfile,'.bim')
        File.Fam<-paste0('selected_',bfile,'.fam')
        
        if(!leaveSSD){
          File.SetID<-paste0('selected_',bfile,'.SetID')
          File.SSD<-paste0('selected_',bfile,'.SSD')
          File.Info<-paste0('selected_',bfile,'.SSD.info')
          Generate_SSD_SetID(File.Bed,File.Bim,File.Fam,File.SetID,File.SSD,File.Info)
          SSD.Info<-Open_SSD(File.SSD,File.Info)
          if (k==1){
            result_table<-SKATBinary.SSD.All(SSD.Info,obj,method=method)         
            result_table<-data.frame(result_table$results)
          }else{
            result<-SKATBinary.SSD.All(SSD.Info,obj,method=method)
            result<-data.frame(result$results)
            result_table<-rbind(result_table,result)
          }
          Close_SSD()
        }else{
          File.SetID<-paste0('selected_',as.character(k),bfile,'.SetID')
          File.SSD<-paste0('selected_',as.character(k),bfile,'.SSD')
          File.Info<-paste0('selected_',as.character(k),bfile,'.SSD.info')
          Generate_SSD_SetID(File.Bed,File.Bim,File.Fam,File.SetID,File.SSD,File.Info)
          SSD.Info<-Open_SSD(File.SSD,File.Info)
          if (k==1){
            result_table<-SKATBinary.SSD.All(SSD.Info,obj,method=method)         
            result_table<-data.frame(result_table$results)
          }else{
            result<-SKATBinary.SSD.All(SSD.Info,obj,method=method)
            result<-data.frame(result$results)
            result_table<-rbind(result_table,result)
          }
          Close_SSD()
        }
      } 
    }
    
    SetID<-data.frame('GENE'=NA,'SNP'=NA)
    snps_selected<-data.frame('SNP'=NA)
    
    for (i in c((1+quotient*number):length(genelist))){
      
      exon_id<-which(anno$Gene.refGene==genelist[i] & anno$Func.refGene %in% genefunc & (anno$ExonicFunc.refGene %in% exonicfunc | anno$ExonicFunc.refGene =='.') )
      
      if (length(exon_id)>0){
        
        anno_gene<-anno[exon_id,1:16]
        
        for (j in 1:length(exon_id)){
          snp_name<-paste0(as.character(anno_gene[j,1]),':',as.character(anno_gene[j,2]),':',as.character(anno_gene[j,4]),':',as.character(anno_gene[j,5]))
          row<-c(anno_gene[j,7],snp_name)
          snps_selected<-rbind(snps_selected,snp_name)
          SetID<-rbind(SetID,row)
        }
      }
    }
    
    if(dim(SetID)[1]!=1 & dim(snps_selected)[1]!=1){
      
      SetID<-SetID[2:nrow(SetID),]
      snps_selected<-snps_selected[2:dim(snps_selected)[1],]
      if(!leaveSSD){
        write.table(SetID,file=paste0('selected_',bfile,'.SetID'),row.names = F,quote = F,col.names = F)
      }else{
        write.table(SetID,file=paste0('selected_last',bfile,'.SetID'),row.names = F,quote = F,col.names = F)
      }
      write.table(snps_selected,file=paste0('selected_',bfile,'_snps.txt'),row.names=F,quote=F,col.names = F)
      
      command<-paste0(' --bfile changed_',bfile, ' --extract selected_',bfile,'_snps.txt --make-bed --out selected_',bfile)
      if(plinkver==1){
        system2('./plink',command,wait=T)
      }else{
        system2('./plink2',command,wait=T)
      }
      File.Bed<-paste0('selected_',bfile,'.bed')
      File.Bim<-paste0('selected_',bfile,'.bim')
      File.Fam<-paste0('selected_',bfile,'.fam')
      
      
      if(!leaveSSD){
        File.SetID<-paste0('selected_',bfile,'.SetID')
        File.SSD<-paste0('selected_',bfile,'.SSD')
        File.Info<-paste0('selected_',bfile,'.SSD.info')
        Generate_SSD_SetID(File.Bed,File.Bim,File.Fam,File.SetID,File.SSD,File.Info)
        SSD.Info<-Open_SSD(File.SSD,File.Info)
        
        result<-SKATBinary.SSD.All(SSD.Info,obj,method=method)
        result<-data.frame(result$results)
        result_table<-rbind(result_table,result)
      }else{
        File.SetID<-paste0('selected_last',bfile,'.SetID')
        File.SSD<-paste0('selected_last',bfile,'.SSD')
        File.Info<-paste0('selected_last',bfile,'.SSD.info')
        Generate_SSD_SetID(File.Bed,File.Bim,File.Fam,File.SetID,File.SSD,File.Info)
        SSD.Info<-Open_SSD(File.SSD,File.Info)
        
        result<-SKATBinary.SSD.All(SSD.Info,obj,method=method)
        result<-data.frame(result$results)
        result_table<-rbind(result_table,result)
      }
      Close_SSD()
      
    }
  }
  
  #for the continuous phenotype, use SKAT.SSD.All
  else{
    #read 1000 genes each time (default, possible to change the number variable)
    quotient<-floor(length(genelist)/number)
    
    for (k in 1:quotient){
      
      #make SetID and snps list file for the first 1000 genes
      SetID<-data.frame('GENE'=NA,'SNP'=NA)
      snps_selected<-data.frame('SNP'=NA)
      
      for (i in c((1+(k-1)*number):(number*k))){
        
        exon_id<-which(anno$Gene.refGene==genelist[i] & anno$Func.refGene %in% genefunc & (anno$ExonicFunc.refGene %in% exonicfunc | anno$ExonicFunc.refGene =='.') )
        
        #only for the gene with the snps with the condition fulfilled
        if (length(exon_id)>0){
          #get the annovar result file only for the part of the gene
          #which fulfilled the condition
          anno_gene<-anno[exon_id,1:16]    
          
          for (j in 1:length(exon_id)){
            #aggregate the info in annovar file to get the same name as changed snp name
            snp_name<-paste0(as.character(anno_gene[j,1]),':',as.character(anno_gene[j,2]),':',as.character(anno_gene[j,4]),':',as.character(anno_gene[j,5]))
            row<-c(anno_gene[j,7],snp_name)
            snps_selected<-rbind(snps_selected,snp_name)
            SetID<-rbind(SetID,row)
          }
        }
      }
      
      #In case of the empty SetID file, skip to the next cycle
      if(dim(SetID)[1]!=1 & dim(snps_selected)[1]!=1){
        
        #Remove the first columns of the SetID and snps_selected because they are NA
        SetID<-SetID[2:nrow(SetID),]
        snps_selected<-snps_selected[2:dim(snps_selected)[1],]
        
        #write SetID file and list of snps to be included
        if(!leaveSSD){
          write.table(SetID,file=paste0('selected_',bfile,'.SetID'),row.names = F,quote = F,col.names = F)
        }else{
          write.table(SetID,file=paste0('selected_',as.character(k),bfile,'.SetID'),row.names = F,quote = F,col.names = F)
        }
        
        write.table(snps_selected,file=paste0('selected_',bfile,'_snps.txt'),row.names =F,quote = F,col.names = F)
        
        command<-paste0(' --bfile changed_',bfile, ' --extract selected_',bfile,'_snps.txt --make-bed --out selected_',bfile)
        if(plinkver==1){
          system2('./plink',command,wait=T)
        }else{
          system2('./plink2',command,wait=T)
        }
        File.Bed<-paste0('selected_',bfile,'.bed')
        File.Bim<-paste0('selected_',bfile,'.bim')
        File.Fam<-paste0('selected_',bfile,'.fam')
        
        
        if(!leaveSSD){
          File.SetID<-paste0('selected_',bfile,'.SetID')
          File.SSD<-paste0('selected_',bfile,'.SSD')
          File.Info<-paste0('selected_',bfile,'.SSD.info')
          Generate_SSD_SetID(File.Bed,File.Bim,File.Fam,File.SetID,File.SSD,File.Info)
          SSD.Info<-Open_SSD(File.SSD,File.Info)
          
          if (k==1){
            result_table<-SKAT.SSD.All(SSD.Info,obj,method=method)         
            result_table<-data.frame(result_table$results)
          }else{
            result<-SKAT.SSD.All(SSD.Info,obj,method=method)
            result<-data.frame(result$results)
            result_table<-rbind(result_table,result)
          }
        }else{
          File.SetID<-paste0('selected_',as.character(k),bfile,'.SetID')
          File.SSD<-paste0('selected_',as.character(k),bfile,'.SSD')
          File.Info<-paste0('selected_',as.character(k),bfile,'.SSD.info')
          Generate_SSD_SetID(File.Bed,File.Bim,File.Fam,File.SetID,File.SSD,File.Info)
          SSD.Info<-Open_SSD(File.SSD,File.Info)
          
          if(k==1){
            result_table<-SKAT.SSD.All(SSD.Info,obj,method=method)         
            result_table<-data.frame(result_table$results)
          }else{
            result<-SKAT.SSD.All(SSD.Info,obj,method=method)
            result<-data.frame(result$results)
            result_table<-rbind(result_table,result)
          }
        }
        Close_SSD()
      }
    } 
    
    
    SetID<-data.frame('GENE'=NA,'SNP'=NA)
    snps_selected<-data.frame('SNP'=NA)
    
    for (i in c((1+quotient*number):length(genelist))){
      
      exon_id<-which(anno$Gene.refGene==genelist[i] & anno$Func.refGene %in% genefunc & (anno$ExonicFunc.refGene %in% exonicfunc | anno$ExonicFunc.refGene =='.') )
      
      if (length(exon_id)>0){
        
        anno_gene<-anno[exon_id,1:16]
        
        for (j in 1:length(exon_id)){
          snp_name<-paste0(as.character(anno_gene[j,1]),':',as.character(anno_gene[j,2]),':',as.character(anno_gene[j,4]),':',as.character(anno_gene[j,5]))
          row<-c(anno_gene[j,7],snp_name)
          snps_selected<-rbind(snps_selected,snp_name)
          SetID<-rbind(SetID,row)
        }
      }
    }
    
    if(dim(SetID)[1]!=1 & dim(snps_selected)[1]!=1){
      
      SetID<-SetID[2:nrow(SetID),]
      snps_selected<-snps_selected[2:dim(snps_selected)[1],]
      if(!leaveSSD){
        write.table(SetID,file=paste0('selected_',bfile,'.SetID'),row.names = F,quote = F,col.names = F)
      }else{
        write.table(SetID,file=paste0('selected_',as.character(k),bfile,'.SetID'),row.names = F,quote = F,col.names = F)
      }
      write.table(snps_selected,file=paste0('selected_',bfile,'_snps.txt'),row.names=F,quote=F,col.names = F)
      
      command<-paste0(' --bfile changed_',bfile, ' --extract selected_',bfile,'_snps.txt --make-bed --out selected_',bfile)
      if(plinkver==1){
        system2('./plink',command,wait=T)
      }else{
        system2('./plink2',command,wait=T)
      }
      File.Bed<-paste0('selected_',bfile,'.bed')
      File.Bim<-paste0('selected_',bfile,'.bim')
      File.Fam<-paste0('selected_',bfile,'.fam')
      
      
      if(!leaveSSD){
        File.SetID<-paste0('selected_',bfile,'.SetID')
        File.SSD<-paste0('selected_',bfile,'.SSD')
        File.Info<-paste0('selected_',bfile,'.SSD.info')
        Generate_SSD_SetID(File.Bed,File.Bim,File.Fam,File.SetID,File.SSD,File.Info)
        SSD.Info<-Open_SSD(File.SSD,File.Info)
        
        result<-SKATBinary.SSD.All(SSD.Info,obj,method=method)
        result<-data.frame(result$results)
        result_table<-rbind(result_table,result)
      }else{
        File.SetID<-paste0('selected_last',bfile,'.SetID')
        File.SSD<-paste0('selected_last',bfile,'.SSD')
        File.Info<-paste0('selected_last',bfile,'.SSD.info')
        Generate_SSD_SetID(File.Bed,File.Bim,File.Fam,File.SetID,File.SSD,File.Info)
        SSD.Info<-Open_SSD(File.SSD,File.Info)
        
        result<-SKATBinary.SSD.All(SSD.Info,obj,method=method)
        result<-data.frame(result$results)
        result_table<-rbind(result_table,result)
        
      }
      Close_SSD()
    }
  }
  #put the chromosome number of each gene
  anno<-anno[c(1,7)]
  anno<-anno[!duplicated(anno),]
  colnames(anno)[2]<-'SetID'
  result_table<-left_join(result_table,anno,by='SetID')
  result_table$logpval=-log10(result_table$P.value)
  result_table<-result_table[c(9,1,2,3,4,5,6,7,8)]
  #write the table
  write.table(result_table, file=resultfilename, col.names = T,row.names=F, quote=F)
}
