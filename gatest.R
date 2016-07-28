# R script for creation of analytics blocking percentages as described here:
# https://www.quantable.com/analytics/how-many-users-block-google-analytics/
# (c) 2016 Quantable LLC

require(RGoogleAnalytics)
require(VennDiagram)

# your GA view table (ga-dev-tools.appspot.com/explorer/ can help here)
gatable <- 'ga:xxx'

start_date <- '2016-01-09'
end_date <- '2016-06-21'

# Authorize the Google Analytics account
# tutorial on how to connect here: analyticsdemystified.com/analysis/tutorial_pulling_google_analytics_data_with_r/
#token <- Auth("xxx.apps.googleusercontent.com","xxx")

# Save the token object for future sessions
save(token,file="./token_file")
ValidateToken(token)

# bot block list
# this is result of manual checking against web logs for bot domains or browser fingerprint ids
# a less manual way would be to use a good bot-blocking system
botfilter <- "ga:networkDomain!=maybe.spoofed;ga:networkDomain!=amazonaws.com;ga:networkDomain!=ewe-ip-backbone.de;ga:networkDomain!=leaseweb.com;ga:networkDomain!=rdsnet.ro;ga:networkDomain!=micfo.com;ga:networkDomain!=financialsbreakingnews.com;ga:networkDomain!=swisscom.ch;ga:networkDomain!=setaptr.net;ga:networkDomain!=choopa.net;ga:dimension2!=108512e3c0797ca5f7a126aea3020033;ga:dimension2!=619e56fd12df3298e5ca95b3659bed74;ga:networkDomain!=spro.net;ga:networkDomain!=gpotato.net;ga:networkDomain!=net;ga:networkDomain!=com;ga:networkDomain!=arnimit.com;ga:networkDomain!=google.com;ga:networkDomain!=kaspersky-labs.com;ga:networkDomain!=net.gt;ga:networkDomain!=netapp.com;ga:networkDomain!=enabler.ne.jp;ga:networkDomain!=blackoakcomputers.com"

# custom dims, setup in the Google Analytics account : measurementsource(1), browserid(2)

# full query into ga dataframe
query.list <- Init(start.date = start_date,
                   end.date = end_date,
                   dimensions = "ga:dimension1,ga:dimension2",
                   metrics = "ga:totalEvents",
                   max.results = 10000,
                   filters = botfilter,
                   table.id = gatable)

ga.query <- QueryBuilder(query.list)
ga.data <- GetReportData(ga.query, token, paginate_query = TRUE)

# with full dimensions for share data (null dimensions esp. for country will exclude some data)
query.list <- Init(start.date = start_date,
                   end.date = end_date,
                   dimensions = "ga:networkDomain,ga:dimension2,ga:dimension1,ga:browser,ga:deviceCategory,ga:operatingSystem,ga:countryIsoCode",
                   metrics = "ga:totalEvents",
                   max.results = 10000,
                   filters = botfilter,
                   table.id = gatable)
ga_with_dimensions.query <- QueryBuilder(query.list)
ga_with_dimensions.data <- GetReportData(ga_with_dimensions.query, token, paginate_query = TRUE)

clientbids <- unique(subset(ga.data, dimension1 == "clientside")[[2]])
serverbids <- unique(subset(ga.data, dimension1 == "serverside")[[2]])

venn.diagram(list("Server" = serverbids, "Client" = clientbids), 
             "venn.png",
             imagetype = "png",
             col = "transparent",
             fill = c("darkred", "darkblue"),
             cat.col = c("darksalmon", "cornflowerblue"),
             sigdigs = 2,
             alpha = .6,
             main = "GA Measurement Overlap",
             main.fontface = "bold",
             main.fontfamily = "sans",
             sub = "unique fingerprints: client-side vs. server-side ",
             print.mode = "percent"
             )

diff <- setdiff(serverbids, clientbids)

EU <- c("BE","BG","CZ","DK","DE","EE","IE","EL","ES","FR","HR","IT","CY","LV","LT","LU","HU","MT","NL","AT","PL","PT","RO","SI","SK","FI","SE","UK","GB")

# just the serverside data
serverside_list_bools <- ga_with_dimensions.data$dimension1 == "serverside"
serverside_data <- ga_with_dimensions.data[serverside_list_bools,]

# de-dupe based on browser fingerprint
serverside_data <- serverside_data[!duplicated(serverside_data$dimension2),]

# just the "blockers"
serverside_blockers <- serverside_data[serverside_data$dimension2 %in% diff,]

# country shares
us_count <- length(grep("US", serverside_data$countryIsoCode))
eu_count <- 0
for (i in EU) { eu_count <- eu_count + length(grep(i, serverside_data$countryIsoCode))}

us_share <- round(us_count/nrow(serverside_data)*100)
eu_share <- round(eu_count/nrow(serverside_data)*100)
other_share <- 100 - (us_share + eu_share)

pct <- c(us_share, eu_share, other_share)
lbls <-  c("US", "EU", "Other")
lbls <- paste(lbls,": ",sep="")
lbls <- paste(lbls, pct, sep="")
lbls <- paste(lbls,"%",sep="")

pie(c(us_share,eu_share,other_share), labels = lbls, col=topo.colors(length(lbls)),
    main="Geographic Breakdown, All")

us_count <- length(grep("US", serverside_blockers$countryIsoCode))
eu_count <- 0
for (i in EU) { eu_count <- eu_count + length(grep(i, serverside_blockers$countryIsoCode))}

us_share <- round(us_count/nrow(serverside_blockers)*100)
eu_share <- round(eu_count/nrow(serverside_blockers)*100)
other_share <- 100 - (us_share + eu_share)

pct <- c(us_share, eu_share, other_share)
lbls <-  c("US", "EU", "Other")
lbls <- paste(lbls,": ",sep="")
lbls <- paste(lbls, pct, sep="")
lbls <- paste(lbls,"%",sep="")

pie(c(us_share,eu_share,other_share), labels = lbls, col=topo.colors(length(lbls)),
    main="Geographic Breakdown, Blockers")


# device shares
slices <- c(length((grep("desktop", serverside_data$deviceCategory))), 
                    length((grep("tablet", serverside_data$deviceCategory))), 
                    length((grep("mobile", serverside_data$deviceCategory))))

pct <- round(slices/sum(slices)*100)
lbls <-  c("Desktop", "Tablet", "Mobile")
lbls <- paste(lbls,": ",sep="")
lbls <- paste(lbls, pct, sep="")
lbls <- paste(lbls,"%",sep="")

pie(slices, labels = lbls, col=topo.colors(length(lbls)),
    main="Device Breakdown, All")

slices <- c(length((grep("desktop", serverside_blockers$deviceCategory))), 
                      length((grep("tablet", serverside_blockers$deviceCategory))), 
                      length((grep("mobile", serverside_blockers$deviceCategory))))

pct <- round(slices/sum(slices)*100)
lbls <-  c("Desktop", "Tablet", "Mobile")
lbls <- paste(lbls,": ",sep="")
lbls <- paste(lbls, pct, sep="")
lbls <- paste(lbls,"%",sep="")

pie(slices, labels = lbls, col=topo.colors(length(lbls)),
    main="Device Breakdown, Blockers")


# browser breakdown
slices <- c(length((grep("Firefox", serverside_data$browser))), 
                      length((grep("Chrome", serverside_data$browser))), 
                      length((grep("Safari", serverside_data$browser))), 
                      length((grep("Internet Explorer", serverside_data$browser))))

pct <- round(slices/sum(slices)*100)
lbls <-  c("Firefox", "Chrome", "Safari", "IE")
lbls <- paste(lbls,": ",sep="")
lbls <- paste(lbls, pct, sep="")
lbls <- paste(lbls,"%",sep="")

pie(slices, labels = lbls, col=topo.colors(length(lbls)),
    main="Browser Breakdown, All")


slices <- c(length((grep("Firefox", serverside_blockers$browser))), 
                      length((grep("Chrome", serverside_blockers$browser))), 
                      length((grep("Safari", serverside_blockers$browser))), 
                      length((grep("Internet Explorer", serverside_blockers$browser))))

pct <- round(slices/sum(slices)*100)
lbls <-  c("Firefox", "Chrome", "Safari", "IE")
lbls <- paste(lbls,": ",sep="")
lbls <- paste(lbls, pct, sep="")
lbls <- paste(lbls,"%",sep="")


pie(slices, labels = lbls, col=topo.colors(length(lbls)),
    main="Browser Breakdown, Blockers")

# os breakdown
slices <- c(length((grep("iOS", serverside_data$operatingSystem))), 
            length((grep("Android", serverside_data$operatingSystem))))

pct <- round(slices/sum(slices)*100)
lbls <- c("iOS", "Android")
lbls <- paste(lbls,": ",sep="")
lbls <- paste(lbls, pct, sep="")
lbls <- paste(lbls,"%",sep="")

pie(slices, labels = lbls, col=topo.colors(length(lbls)),
    main="OS Breakdown, All")

slices <- c(length((grep("iOS", serverside_blockers$operatingSystem))), 
                  length((grep("Android", serverside_blockers$operatingSystem))))
pct <- round(slices/sum(slices)*100)
lbls <- c("iOS", "Android")
lbls <- paste(lbls,": ",sep="")
lbls <- paste(lbls, pct, sep="")
lbls <- paste(lbls,"%",sep="")

pie(slices, labels = lbls, col=topo.colors(length(lbls)),
    main="OS Breakdown, Blockers")
