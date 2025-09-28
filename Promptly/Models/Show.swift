import Foundation
import SwiftData

@Model
class PerformanceDate {
   var date: Date
   var show: Show?
   
   init(date: Date) {
       self.date = date
   }
}

@Model
class Show: Identifiable {
   var id: UUID
   
   var title: String
   var locationString: String
   
   @Relationship(deleteRule: .cascade) var performanceDates: [PerformanceDate] = []
   var script: Script?
   @Relationship(deleteRule: .cascade) var peformances: [Performance] = []
   
   init() {
       self.id = UUID()
       self.title = ""
       self.locationString = ""
       self.performanceDates = []
       self.script = nil
       self.peformances = []
   }
   
   init(id: UUID, title: String, dates: [Date], locationString: String, script: Script, peformances: [Performance]) {
       self.id = id
       self.title = title
       self.locationString = locationString
       self.script = script
       self.peformances = peformances
       
       self.performanceDates = dates.map { date in
           let perfDate = PerformanceDate(date: date)
           perfDate.show = self
           return perfDate
       }
   }
   
   var dates: [Date] {
       get {
           performanceDates.map { $0.date }
       }
       set {
           performanceDates.removeAll()
           performanceDates = newValue.map { date in
               let perfDate = PerformanceDate(date: date)
               perfDate.show = self
               return perfDate
           }
       }
   }
   
   func addPerformanceDate(_ date: Date) {
       let perfDate = PerformanceDate(date: date)
       perfDate.show = self
       performanceDates.append(perfDate)
   }
   
   func removePerformanceDate(at index: Int) {
       guard index < performanceDates.count else { return }
       performanceDates.remove(at: index)
   }
   
   func updatePerformanceDate(at index: Int, to newDate: Date) {
       guard index < performanceDates.count else { return }
       performanceDates[index].date = newDate
   }
}
