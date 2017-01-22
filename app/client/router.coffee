BlazeLayout.setRoot('body')

FlowRouter.route '/',
  action: ->
    BlazeLayout.render 'layout',
      main: 'map'

FlowRouter.route '/:page',
  action: ->
    BlazeLayout.render 'layout',
      main: 'map'

