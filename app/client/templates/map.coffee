WorldGeoJSON = require '/imports/data/world.geo.json'
utils = require '/imports/utils.coffee'
UgandaGeoJSON = require '/imports/data/uganda-district-precipitation-2016-11.json'

OUTBREAK_RAMP = chroma.scale(['#287431', '#6fc236', '#f5e324']).colors(10)
PRECIPITATION_RAMP = chroma.scale(['#6fc236', '#2bb4f1', '#e0ecff']).colors(10)

UI.registerHelper 'percentage', (a, b, digits=0)->
  (100 * a / b).toFixed(digits)

UI.registerHelper 'formatNumber', (n, digits=0)->
  n.toFixed(digits).toLocaleString()

UI.registerHelper 'eq', (a, b)->
  a == b

Template.map.onCreated ->
  @sideBarLeftOpen = new ReactiveVar true
  @mapLoading = new ReactiveVar true
  @dataDate = new ReactiveVar()

Template.map.onRendered ->
  @$('[data-toggle="tooltip"]').tooltip()

  L.Icon.Default.imagePath = 'packages/bevanhunt_leaflet/images'
  @lMap = L.map(@$('.map')[0],
    zoomControl: false
    preferCanvas: true
  )

  maxValue = 0

  legend = L.control(position: 'bottomright')
  legend.onAdd = (map)->
    @_div = L.DomUtil.create('div', 'info legend')
    @update()
  legend.update = ()->
    switch FlowRouter.getParam('page')
      when 'precipitation'
        curRamp = PRECIPITATION_RAMP
        label = 'Weekly precipitation in millimeters'
        values = _.range(0, curRamp.length, 2).map (idx)->
          value: (maxValue * idx / curRamp.length).toFixed(0) + " mm"
          color: curRamp[idx]
      else
        curRamp = OUTBREAK_RAMP
        label = 'Risk of malaria outbreak in two months'
        values = _.range(0, curRamp.length, 2).map (idx)->
          value: utils.round(
            (idx / curRamp.length) * maxValue  * 100
          , 0) + "%"
          color: curRamp[idx]
    $(@_div).html(
      Blaze.toHTMLWithData(Template.legend, {
        label: label
        values: values
      })
    )
    @_div
  legend.addTo(@lMap)

  sidebar = L.control.sidebar('sidebar').addTo(@lMap)

  @baseCountryLayer = L.geoJson({
    features: WorldGeoJSON.features
    type: 'FeatureCollection'
  }, {
    style:
      fillColor: '#CCFF99'
      weight: 1
      opacity: 1
      color: '#BBBBBB'
      # dashArray: '3'
      #fillOpacity: 0.75
  }).addTo(@lMap)

  getColor = (val)->
    switch FlowRouter.getParam('page')
      when "precipitation"
        curRamp = PRECIPITATION_RAMP
      else
        curRamp = OUTBREAK_RAMP
    # return a color from the ramp based on a 0 to 1 value.
    # If the value exceeds one the last stop is used.
    curRamp[Math.floor(curRamp.length * Math.max(0, Math.min(val, 0.99)))]

  style = (feature)=>
    switch FlowRouter.getParam('page')
      when 'precipitation'
        if _.isNumber feature.properties.district_mean_rainfall_mm
          x = feature.properties.district_mean_rainfall_mm / maxValue
        else
          x = undefined
      else
        x = feature.properties.future_outbreaks / feature.properties.occurrences / maxValue
    return {
      fillColor: getColor(x)
      weight: 1
      opacity: 1
      color: '#DDDDDD'
      dashArray: '3'
      fillOpacity: 0.75
    }

  zoomToFeature = (e)=>
    @lMap.fitBounds(e.target.getBounds())

  highlightFeature = (e)=>
    layer = e.target
    layer.setStyle
      weight: 1
      color: '#2CBA74'
      dashArray: ''
      fillOpacity: 0.75
    if not L.Browser.ie and not L.Browser.opera
      layer.bringToFront()
    info.update(layer.feature.properties)

  resetHighlight = (e)=>
    @geoJsonLayer.resetStyle(e.target)
    info.update()

  info = L.control(position: 'topleft')
  info.onAdd = (map) ->
    @_div = L.DomUtil.create('div', 'info')
    @update()
    @_div
  info.update = (props) ->
    @_div.innerHTML = Blaze.toHTMLWithData(Template.infoBox, {
      props: props
    })
  info.addTo(@lMap)
  districtLayers = []
  Meteor.call "getUgandaGeoJSON", (err, UgandaGeoJSON)=>
    @dataDate.set(moment.utc(UgandaGeoJSON.asOfDate))
    @geoJsonLayer = L.geoJson({
      features: UgandaGeoJSON.features
      type: 'FeatureCollection'
    }, {
      style: style
      onEachFeature: (feature, layer)=>
        districtLayers.push(layer)
        layer.on
          mouseover: highlightFeature
          mouseout: resetHighlight
          click: (evt)=>
            zoomToFeature(evt)
            Modal.show('districtModal',
              feature: feature
              layer: layer
              medianCasesOverPopulation: UgandaGeoJSON.medianCasesOverPopulation
              medianWeeklyRainfallMm: UgandaGeoJSON.medianWeeklyRainfallMm
            )
    }).addTo(@lMap)

    updateMap = =>
      legend.update()
      districtLayers.forEach (layer)=>
        @geoJsonLayer.resetStyle(layer)
      @mapLoading.set false

    @lMap.fitBounds(@geoJsonLayer.getBounds())

    @autorun =>
      FlowRouter.getParam('page')
      values = UgandaGeoJSON.features
        .map (x)->
          switch FlowRouter.getParam('page')
            when 'precipitation'
              return x.properties.district_mean_rainfall_mm
            else
              return x.properties.future_outbreaks / x.properties.occurrences
        .filter (x)->x
        .sort (a, b)->a - b

      maxValue = values[values.length - 1]
      console.log values
      updateMap()

Template.map.helpers
  dataDate: ->
    Template.instance().dataDate.get()?.format('YYYY-MM-DD')
  page: ->
    FlowRouter.getParam('page') or "outbreakRisk"
  loading: ->
    console.log Template.instance().mapLoading.get()
    Template.instance().mapLoading.get()

Template.map.events
  'click #sidebar-plus-button': (event, instance) ->
    instance.lMap.zoomIn()

  'click #sidebar-minus-button': (event, instance) ->
    instance.lMap.zoomOut()

  'click #sidebar-collapse-tab': (event, instance) ->
    sideBarLeftOpen = instance.sideBarLeftOpen.get()
    $('body').toggleClass('sidebar-left-closed')
    instance.sideBarOpen.set not sideBarOpen
