require(rgdal)
require(RColorBrewer)

uganda<-readOGR(dsn="C:/Users/Spina/Desktop/imed2016/PuddlePredict/Mapping/Others/districts_2013_112_web_wgs84", layer="districts_2013_112_web_wgs84")

incidence<-read.csv("C:/Users/Spina/Desktop/imed2016/PuddlePredict/Mapping/Incidence.csv", sep=";", strip.white = T)

uganda@data$DNAME_2011<-as.character(uganda@data$DNAME_2011)
incidence$District<-as.character(incidence$District)

uganda@data<-merge(uganda@data, incidence, by.x="DNAME_2011", by.y="District")


cols <- brewer.pal(4, "Blues")
brks <- c(0, 300, 400, 500, 1500)
cut(uganda@data$Incidence, brks)

gs <- cols[findInterval(uganda@data$Incidence, vec = brks)]

png(filename="C:/Users/Spina/Desktop/imed2016/PuddlePredict/Mapping/map.png", width = 2000, height= 1483) # add to 
# save plot
plot(uganda, col = gs)

# legend("topleft", legend = c("<=300","301-400", "401-500", ">=500"), fill = cols, 
#        title = "Predicted incidence \n (per 1000 population)", bty="n", xpd=T)

dev.off()
