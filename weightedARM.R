library(arules)
library(igraph)
library(openxlsx)
library(dplyr)
library(stringr)
if (!require("RColorBrewer")) {
  # install color package of R
  install.packages("RColorBrewer")
  #include library RColorBrewer
  library(RColorBrewer)
}

OnlineRetail.Prep <- function(){
  DataSet <- read.xlsx('../dataset4/Online Retail.xlsx')
  DataSet <- DataSet[!grepl("C", DataSet$InvoiceNo),]
  DataSet <- DataSet[!grepl("A", DataSet$InvoiceNo),]
  DataSet <- DataSet[!grepl("\\?", DataSet$Description),]
  DataSet <- DataSet[rowSums(is.na(DataSet)) == 0,]
  DataSet$Description <- gsub(',', '-', DataSet$Description)
  
  PrepData <- DataSet %>% select(InvoiceNo, Description)

  colnames(PrepData) <- c("order_id", "product_id")

  ForWeight <- DataSet %>% select(InvoiceNo,Quantity, UnitPrice)
  ForWeight$Total <- ForWeight$Quantity * ForWeight$UnitPrice
  Weight <- aggregate(. ~InvoiceNo, data=ForWeight, sum, na.rm=TRUE)
  Weight$Count <- table(ForWeight$InvoiceNo)
  Weight$TransactionWeight <- Weight$Total/Weight$Count
  Weight <- Weight %>% select(InvoiceNo, TransactionWeight)
  colnames(Weight) <- c("transactionID", "weight")
  
  write.table(PrepData, file = "../dataset4/data.csv",row.names=FALSE,col.names=TRUE, sep=',', quote = FALSE)
  write.table(Weight, file = "../dataset4/weight.csv",row.names=FALSE,col.names=TRUE, sep=',', quote = FALSE)
}
MovieRecommendation.Prep <- function(){
  
  DataSet <- read.csv('../dataset5/ratings_small.csv')
  MovieDesc <- read.csv('../dataset5/movies_metadata.csv')
  MovieDesc <- MovieDesc %>% select(id, original_title)
  MovieDesc$original_title <- gsub(',', '-', MovieDesc$original_title)
  DataSet <- merge(DataSet, MovieDesc, by.x="movieId", by.y="id")
  
  PrepData <- DataSet %>% select(userId, original_title)
  colnames(PrepData) <- c("order_id", "product_id")
  
# Transaction Weight ------------------------------------------------------

  ForWeight <- DataSet %>% select(userId, rating)
  Weight <- aggregate(. ~userId, data=ForWeight, sum, na.rm=TRUE)
  Weight$Count <- table(ForWeight$userId)
  Weight$TransactionWeight <- Weight$rating/Weight$Count
  Weight <- Weight %>% select(userId, TransactionWeight)
  colnames(Weight) <- c("transactionID", "weight")
  
  
# Weight avg rating -------------------------------------------------------

  ForWeight <- DataSet %>% select(movieId,rating)
  Weight <- aggregate(. ~movieId, data=ForWeight, sum, na.rm=TRUE)
  Weight$Count <- table(ForWeight$movieId)
  Weight$ItemWeight <- Weight$rating/Weight$Count
  Weight <- merge(Weight, MovieDesc, by.x="movieId", by.y="id")
  Weight <- Weight %>% select(original_title, ItemWeight)
  colnames(Weight) <- c("movieID", "weight")
  
  X <- DataSet %>% select(userId,movieId)
  X <- merge(X, MovieDesc, by.x="movieId", by.y="id")
  X <- X %>% select(userId,original_title)
  Y <- X %>% group_by(userId) %>% summarise(transactions = paste(original_title, collapse=", "))
  temp <- Y$transactions
  itemsetWeight <- vector()
  
  for (i  in temp) 
  { 
    splittedRow = as.data.frame(strsplit(i, ","))
    colnames(splittedRow) <- c("splittedMovies")
    splittedRow <- merge(splittedRow, Weight, by.x="splittedMovies", by.y="movieID")
    itemsetWeight <- c(itemsetWeight,sum(splittedRow$weight)/ max(as.numeric(rownames(splittedRow))))
  }
  Y$weight <- itemsetWeight
  Y <- Y %>% select(userId,weight)
  colnames(Y) <- c("transactionID", "weight")
  
# Weight movie count  -----------------------------------------------------
  
  ForWeight <- DataSet %>% select(movieId,rating)
  Weight <- aggregate(. ~movieId, data=ForWeight, sum, na.rm=TRUE)
  Weight$Count <- table(ForWeight$movieId)
  Weight <- merge(Weight, MovieDesc, by.x="movieId", by.y="id")
  Weight <- Weight %>% select(original_title, Count)
  colnames(Weight) <- c("movieID", "weight")
  
  X <- DataSet %>% select(userId,movieId)
  X <- merge(X, MovieDesc, by.x="movieId", by.y="id")
  X <- X %>% select(userId,original_title)
  Y <- X %>% group_by(userId) %>% summarise(transactions = paste(original_title, collapse=", "))
  temp <- Y$transactions
  itemsetWeight <- vector()
  
  for (i  in temp) 
  { 
    splittedRow = as.data.frame(strsplit(i, ","))
    colnames(splittedRow) <- c("splittedMovies")
    splittedRow <- merge(splittedRow, Weight, by.x="splittedMovies", by.y="movieID")
    itemsetWeight <- c(itemsetWeight,sum(splittedRow$weight)/ max(as.numeric(rownames(splittedRow))))
  }
  Y$weight <- itemsetWeight
  Y <- Y %>% select(userId,weight)
  colnames(Y) <- c("transactionID", "weight")
  
# Create CSV --------------------------------------------------------------
  
  write.table(PrepData, file = "../dataset5/data.csv",row.names=FALSE,col.names=TRUE, sep=',', quote = FALSE)
  write.table(Weight, file = "../dataset5/weight.csv",row.names=FALSE,col.names=TRUE, sep=',', quote = FALSE)
}

get.txn <- function(data.path, columns){
  transactions.obj <- read.transactions(file = data.path, format = "single", 
                                        sep = ",",
                                        cols = columns, 
                                        rm.duplicates = FALSE,
                                        quote = "", skip = 0,
                                        encoding = "unknown",
                                        header = TRUE)
  return(transactions.obj)
}

plot.graph <- function(cross.sell.rules){
  edges <- unlist(lapply(cross.sell.rules['rules'], strsplit, split='=>'))
  g <- graph(edges = edges)
  plot(g)
}

columns <- c("order_id","product_id" ) 
data.path = '../dataset4/data.csv' 
transactions.obj <- get.txn(data.path, columns)

transactions.obj@itemsetInfo$weight <- NULL


# Manuel Weight -----------------------------------------------------------

weights <- read.csv('../dataset4/weight.csv')
transactions.obj@itemsetInfo <- Weight


# Hits Weight -------------------------------------------------------------

weight <- hits(transactions.obj)
transactions.obj@itemsetInfo[["weight"]] <- weight
transactions.obj@itemsetInfo[["transactionID"]] <-as.numeric(as.character(transactions.obj@itemsetInfo[["transactionID"]]))


# Support -----------------------------------------------------------------

support <- 0.015
parameters = list(
  support = support,
  minlen  = 2,
  maxlen  = 10,
  target  = "frequent itemsets"
)

# Eclat -------------------------------------------------------------------

eclat.itemsets <- eclat(transactions.obj, parameter = parameters)
eclat.itemsets.df <-data.frame(eclat.itemsets = labels(eclat.itemsets)
                                , eclat.itemsets@quality)
eclat.itemsets.df

itemsets <- (gsub("\\{|\\}", "", eclat.itemsets.df$eclat.itemsets))
itemsetWeight <- vector()

for (i  in itemsets) 
{ 
  splittedRow = as.data.frame(strsplit(i, ","))
  colnames(splittedRow) <- c("splittedMovies")
  splittedRow <- merge(splittedRow, Weight, by.x="splittedMovies", by.y="movieID")
  itemsetWeight <- c(itemsetWeight,sum(splittedRow$weight)/ max(as.numeric(rownames(splittedRow))))
}

weightedSupport <-as.data.frame(eclat.itemsets.df$support * itemsetWeight)
weightedSupport <- apply(weightedSupport,MARGIN = 2,FUN = function(x)  (x- min(x))/(max(x) - min(x)))
eclat.itemsets.df$weightedSupport <- weightedSupport
Final <- eclat.itemsets.df %>% filter(weightedSupport > 0.22)


eclat.rules <- ruleInduction(eclat.itemsets, transactions.obj, confidence = 0.8)
eclat.rules.df <-data.frame(rules = labels(eclat.rules)
                             , eclat.rules@quality)
eclat.rules.df

rules <- (gsub("\\{|\\}", "", eclat.rules.df$rules))
rules <- gsub(' => ', ',', rules)

rulesWeight <- vector()

for (i  in rules) 
{ 
  splittedRow = as.data.frame(strsplit(i, ","))
  colnames(splittedRow) <- c("splittedMovies")
  splittedRow <- merge(splittedRow, Weight, by.x="splittedMovies", by.y="movieID")
  rulesWeight <- c(rulesWeight,sum(splittedRow$weight)/ max(as.numeric(rownames(splittedRow))))
}

weightedSupport <-as.data.frame(eclat.rules.df$support * rulesWeight)
weightedSupport <- apply(weightedSupport,MARGIN = 2,FUN = function(x)  (x- min(x))/(max(x) - min(x)))
eclat.rules.df$weightedSupport <- weightedSupport
Final <- eclat.rules.df%>% filter(weightedSupport > 0.22)

eclat.rules.df$rules <- as.character(eclat.rules.df$rules)
eclat.rules.df$rules

# Weclat --------------------------------------------------------------------

weclat.itemsets <- weclat(transactions.obj, parameter = parameters)
weclat.itemsets.df <-data.frame(weclat.itemsets = labels(weclat.itemsets)
                                , weclat.itemsets@quality)

weclat.itemsets.df
weclat.rules <- ruleInduction(weclat.itemsets, transactions.obj, confidence = 0.6)
weclat.rules.df <-data.frame(rules = labels(weclat.rules)
                             , weclat.rules@quality)
weclat.rules.df
weclat.rules.df$rules <- as.character(weclat.rules.df$rules)
#dev.off()

weclat.rules.df %>% filter(str_detect(rules,"Silent Hill")) %>% select(rules,support,confidence,lift) %>% head(20) #recommend

plot.graph(weclat.rules.df)
itemFrequencyPlot(transactions.obj,topN=20,type="absolute",col=brewer.pal(8,'Pastel2'), main="Absolute Item Frequency Plot")

