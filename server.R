# Server file for SSBM Smash Summit Analysis Tool 

library(shiny)
library(RSQLite)
library(ggplot2)
library(caret)
library(factoextra)
library(rpart) 
library(rpart.plot)

conn <- dbConnect(RSQLite::SQLite(), "SmashSummit.db")

# ss_players <- read.csv("data/ss_players.csv")
# dbWriteTable(conn, "full_data", ss_players)

# dbListTables(conn)

ss_players <- dbGetQuery(conn, "SELECT * FROM full_data") 

function(input, output, session){
 # 1. ABOUT 
 # 2. DATASET 
 output$table <- DT::renderDataTable(DT::datatable({
  data <- ss_players
  if (input$summit != "All") {
   data <- data[data$summit == input$summit,]
  }
  if (input$mainChar != "All") {
   data <- data[data$mainChar == input$mainChar,]
  }
  data
 }))

 # 3. EDA 
 ## 3.1 Histogram
 hist_df <- reactive({
  newdata <- subset(ss_players,ss_players$summit==input$summitHist)
 })
 
 output$hist <- renderPlot({
  n <-nrow(hist_df())
  binSize <-round(1+3.322*log(n))
  ggplot(hist_df(), aes(x=hist_df()[,input$var])) +
   geom_histogram(bins=binSize) + 
   labs(title=paste0("Histogram of ",input$var," for Smash Summit ",input$summitHist)) + 
   xlab(input$var)
 })
 
 ## 3.2 Scatterplot 
 output$scatter <- renderPlot({
  newdata <- subset(ss_players,ss_players$summit==input$summit)
  ggplot(newdata, aes(x=ss_players[,input$var1], y=ss_players[,input$var2])) + 
   geom_jitter() + 
   labs(title=paste0("Scatter Plot of ",input$var2," vs. ",input$var2)) +
   xlab(input$var1) + ylab(input$var2)
 })
 
 # 4. CLUSTERING
 ## 4.1. Sidebar 
 cluster_df <- reactive({
  # newdata <- ss_players[-c(1:16),]
  # newdata <- newdata[!is.na(newdata$sznAvgPlace),]
  # dbWriteTable(conn, "complete_data", newdata)
  # 
  # set.seed(11)
  # newdata <- newdata[,-c(1:4,21:25)] # removing unneeded/non-numeric rows
  # 
  # process <- preProcess(newdata[,c(1,10:16)],method=c("range")) # min-max scaling
  # norm_scale <- predict(process, newdata[,c(1,10:16)])
  # newdata <- newdata[,-c(1,10:16)]
  # newdata <- cbind(newdata, norm_scale)
  # dbWriteTable(conn, "cluster_data", newdata)
  dbGetQuery(conn, "SELECT * FROM cluster_data") 
 })
 
 clusters <- eventReactive(input$updateCluster, {
  kmeans(cluster_df(), centers=input$k) 
 })
 
 output$summitMembership <- renderTable({
   newdata <- dbGetQuery(conn, "SELECT tag, summit FROM complete_data")
   membership <- data.frame(Player=newdata$tag,
                            Summit=newdata$summit,
                            Cluster=clusters()$cluster)
   membership <- membership[membership$Summit == input$summitCluster,c(1,3)]
 })
 
 ## 4.2. Main Panel 
 output$cluster <- renderPlot({
  fviz_cluster(clusters(), geom = "point", cluster_df()) + ggtitle(paste0("k=",input$k))
 })
 
 
 # 5. TOP 8 PREDICTION
 ## 5.1. Sidebar
 seed <- eventReactive(input$generateDT,{
  if (!(is.numeric(input$seedNum)) || !(input$seedNum%%1==0)){
   print("Enter a positive integer.")
  }
 })
 output$numberCheck <- renderText(seed()) # prints warning 
 output$ssPlayers <- renderText({
  players <- ss_players[ss_players$summit==input$summitTop8,2]
  paste(players,'\n')
  })
 
 ## 5.2. Main Panel 
 output$dtTitle <- renderText(paste0("Decision Tree for Seed ",input$seedNum))
 ### A. Decision tree 
 trn_df <- reactive({
   if(!is.character(seed())){
    set.seed(input$seedNum)
     
    newdata <- dbGetQuery(conn, "SELECT * FROM complete_data") 
    trn_n <- round(.7*nrow(newdata))
    trn_index <- sample(1:nrow(newdata), trn_n, replace=FALSE)
     
    newdata$ssTop8 <- 0
    newdata[which(newdata$place<=8),24] <- 1
     
    # Splitting into train and test data sets 
    trn_df <- newdata[trn_index,-c(1:5,21,22)]
   }
 })
 
 output$dt <- renderPlot({
  if (length(trn_df())>0){
   dt <- rpart(ssTop8~., data=trn_df(), method="class")
   rpart.plot(dt)
  }
 })
 
 ### B. Predictions 
 top8Players <- reactive({
  ss_players[ss_players$summit==input$summitTop8 & ss_players$place<=8,2]
 })
 
 dtPred <- reactive({
  dt <- rpart(ssTop8~., data=trn_df(), method="class") 
  dtInput <- ss_players[ss_players$summit==input$summitTop8,]
  dtInput$ssTop8 <- 0 
  dtInput[which(dtInput$place<=8),24] <- 1
  dtInput <- dtInput[,-c(1:5,21,22)]
 
  dtPred <- predict(dt, dtInput, type = "class")
  dtPredTab <- table(dtPred, dtInput$ssTop8)
  dtPredCorrect <- round(((dtPredTab[4]*100)/8),2)  
 })
 
 accTable <- eventReactive(input$calcAcc,{ 
  userPredCorrect <- (sum(top8Players() %in% input$inPlayers)/8)*100
  
  predAcc <- data.frame("CPU"=dtPred(),
                        "User"=userPredCorrect)
 })
 
 generateLabel <- eventReactive(input$calcAcc,{
  "Correct Players:"
 })
 
 generatePlayers <- eventReactive(input$calcAcc,{
  top8Players()
 })
 
 output$acc <- renderTable(accTable())
 output$top8Label <- renderText(generateLabel())
 output$top8Players <- renderText(generatePlayers())
 
 session$onSessionEnded(function(){
  dbDisconnect(conn)
 })
}
