define (require)->
  $ = require 'jquery'
  _ = require 'underscore'
  Backbone = require 'backbone'
  marionette = require 'marionette'
  
  vent = require 'core/messaging/appVent'
  reqRes = require 'core/messaging/appReqRes'
  Project = require 'core/projects/project'
  
  CodeEditorSettings = require './codeEditorSettings'
  CodeEditorSettingsView = require './codeEditorSettingsView'
  CodeEditorRouter = require "./codeEditorRouter"
  CodeEditorView = require './codeEditorView'

  DummyView = require 'core/utils/dummyView'
 
 
  class CodeEditor extends Backbone.Marionette.Application
    title: "CodeEditor"
    regions:
      mainRegion: "#code"
    
    constructor:(options)->
      super options
      @appSettings = options.appSettings ? null
      @settings = options.settings ? new CodeEditorSettings()
      @project= options.project ? new Project()
      @vent = vent
      @router = new CodeEditorRouter
        controller: @
        
      @vent.on("project:loaded",@resetEditor)
      @vent.on("project:created",@resetEditor)
      @init()

      @addRegions @regions
      
    init:=>
      if @appSettings?
        @appSettings.registerSettingClass("CodeEditor", CodeEditorSettings)
        
      @addInitializer ->
        @vent.trigger "app:started", "#{@title}"
      
      #if requested we send back the type of SettingsView to use for this specific sub app
      reqRes.addHandler "CodeEditorSettingsView", ()->
        return CodeEditorSettingsView
        
    onStart:()=>
      @settings = @appSettings.get("CodeEditor")
      @showRegions()
      
    showRegions:=>
      @codeEditorView = new CodeEditorView 
        model:    @project
        settings: @settings
      
      DialogView = require 'core/utils/dialogView'
      @dia = new DialogView({elName:"codeEdit", title: "CodeEditor", width:450, height:250,position:[25,125],dockable:true})
      @dia.render()
      @dia.show(@codeEditorView)
      
      #Setup keyBindings
      ### 
      $(document).bind('keydown', 'ctrl+a', (event)->
        console.log "I WANT TO SAVE"
        )
      ###
    resetEditor:(newProject)=>
      console.log "resetting code editor"
      @dia.hide()
      @codeEditorView.close()
      
      @project = newProject
      @codeEditorView = new CodeEditorView 
        model:    @project
        settings: @settings
      
      @dia.show(@codeEditorView)
  
  return CodeEditor