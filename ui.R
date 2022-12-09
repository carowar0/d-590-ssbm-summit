# UI file for SSBM Smash Summit Analysis Tool 

library(markdown)
library(RSQLite)

conn <- dbConnect(RSQLite::SQLite(), "SmashSummit.db")
ss_players <- dbGetQuery(conn, "SELECT * FROM full_data") 

navbarPage("SSBM Smash Summit Analysis Tool",
           
 # 1. ABOUT          
 tabPanel("About",
  mainPanel(
   HTML('<center><img src="finaldestination.jpg"></center>'),
   HTML('<center><em>Figure 1.</em> Final Destination. (Source: Nintendo, 2001).</center>'),
   
   includeMarkdown("About.md") 
  )
 ),
 
 navbarMenu("Dataset",
  ## 2.1 Table  
   tabPanel("Table",
    fluidRow(
     column(4, selectInput("summit",
                           "Summit Number:",
                           c("All", unique(as.numeric(ss_players$summit))))
            ),
     column(4, offset=4, selectInput("mainChar",
                                     "Main Character:",
                                     c("All", unique(as.character(ss_players$mainChar))))
            )
   ), 
    DT::dataTableOutput("table")
  ),
            
  ## 2.2 Variables 
  tabPanel("Variables",
   includeMarkdown("Variables.md") 
  )
 ),
 
 
 # 3. EDA 
 navbarMenu("EDA",
  ## 3.1 Histogram 
  tabPanel("Histogram",
   sidebarLayout(
    sidebarPanel(
     selectInput("summitHist", "Summit Number:",
                 unique(as.numeric(ss_players$summit))[-1]),
     selectInput("var", "Variable:",
                 colnames(ss_players)[c(10:16)]),
     helpText("Note: Bin sizes are calculated with Sturge's rule.")
    ),
    mainPanel(
     plotOutput("hist")
    )
   )
   
  ),
  
  ## 3.2 Scatterplot 
  tabPanel("Scatterplot",
   sidebarLayout(
    sidebarPanel(
     selectInput("var1", "X Variable:",
                 colnames(ss_players)[c(5,10:20)]),
     selectInput("var2", "Y Variable:",
                 colnames(ss_players)[c(5,10:20)])
    ),
    mainPanel(
      plotOutput("scatter")
    )
   )
  )
 ),
 
 # 4. CLUSTERING 
 tabPanel("Clustering",
  sidebarPanel(
   sliderInput("k", "Number of Clusters:",
               min=2, max=5, value=2, step=1),
   actionButton("updateCluster","Generate"),
   hr(),
   selectInput("summitCluster", "Show Clusters by Summit:",
               unique(as.numeric(ss_players$summit))[-1]),
   tableOutput("summitMembership"),
   
  ), 
  mainPanel(
    plotOutput("cluster"),
  )
 ),
 
 # 5. TOP 8 PREDICTION
 tabPanel("Top 8 Prediction",
  sidebarPanel(
   selectInput("summitTop8", "Summit Number:",
               unique(as.numeric(ss_players$summit))[-c(1,5)]),  
   numericInput("seedNum", "Set seed:",value = "Enter positive integer",min=1),
   actionButton("generateDT", "Generate Tree"),
   textOutput("numberCheck"),
   tags$br(),
   HTML("<b> Invited Players </b>"),
   verbatimTextOutput("ssPlayers"),
  ), 
  
  mainPanel(
   textOutput("dtTitle"),
   plotOutput("dt"),
   selectizeInput("inPlayers","Select Top 8:", ss_players[,2], multiple=T, options=list(maxItems=8)),
   actionButton("calcAcc","Calculate Accuracy"),
   tableOutput("acc"),
   textOutput("top8Label"), 
   verbatimTextOutput("top8Players") 
  )
 ) 
)