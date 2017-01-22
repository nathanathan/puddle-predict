Meteor.methods
  getUgandaGeoJSON: ->
    HTTP.get("http://localhost:3333/stats.json").data
