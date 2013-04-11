define (require)->
  $ = require 'jquery'
  _ = require 'underscore'
  marionette = require 'marionette'
  modelBinder = require 'modelbinder'
  require 'bootstrap'
  require 'bootbox'
  require 'notify'
  
  vent = require 'core/messaging/appVent'
  
  mainMenuMasterTemplate = require "text!core/mainMenu.tmpl"
  
  mainMenuTemplate = _.template($(mainMenuMasterTemplate).filter('#mainMenuTmpl').html())
  recentFileTemplate = _.template($(mainMenuMasterTemplate).filter('#recentFileTmpl').html())
  
  
  class MainMenuView extends Backbone.Marionette.Layout
    template: mainMenuTemplate
    regions:
      recentProjects:   "#recentProjects"
      examplesStub:         "#examples"
      exportersStub:        "#exporters"
    
    ui: 
      exportersStub: "#exporters"
      storesStub: "#stores"
      
    events:
      "click .newProject":    ()->vent.trigger("project:new")
      "click .newFile":       ()->vent.trigger("project:file:new")
      "click .saveProjectAs": ()->vent.trigger("project:saveAs")
      "click .saveProject":   ()->vent.trigger("project:save")
      "click .loadProject":   ()->vent.trigger("project:load")
      "click .deleteProject": ()->vent.trigger("project:delete")
      "click .undo":          "onUndoClicked"
      "click .redo":          "onRedoClicked"
      
      "click .settings":      ()->vent.trigger("settings:show")
      "click .showEditor":    ()->vent.trigger("codeEditor:show")
      
      "click .compileProject"  : ()->vent.trigger("project:compile")
      
      "click .geometryCreator" : ()->vent.trigger("geometryEditor:show")
      
      "click .about" : "showAbout"
  
    constructor:(options)->
      super options
      @vent = vent
      @stores= options.stores ? {}
      @exporters= options.exporters ? {}
      
      #TODO: move this to data binding
      @vent.on("file:undoAvailable", @_onUndoAvailable)
      @vent.on("file:redoAvailable", @_onRedoAvailable)
      @vent.on("file:undoUnAvailable", @_onNoUndoAvailable)
      @vent.on("file:redoUnAvailable", @_onNoRedoAvailable)
      @vent.on("clearUndoRedo", @_clearUndoRedo)
        
      @vent.on("notify",@onNotificationRequested)
      @vent.on("project:loaded",()=>@_onNotificationRequested("Project:loaded"))
      @vent.on("project:saved",()=>@_onNotificationRequested("Project:saved"))
      @vent.on("project:autoSaved",()=>@_onNotificationRequested("Project:autosave"))
      @vent.on("project:compiled",()=>@_onNotificationRequested("Project:compiled"))
      @vent.on("project:compile:error",()=>@_onNotificationRequested("Project:compile ERROR check console for details!"))
      @vent.on("project:loaded", @onProjectLoaded)
    
    _onNotificationRequested:(message)=>
      $('.notifications').notify(message: { text:message },fadeOut:{enabled:true, delay: 1000 }).show()
      
    _clearUndoRedo:=>
      $('#undoBtn').addClass("disabled")
      $('#redoBtn').addClass("disabled")
    _onUndoAvailable:=>
      $('#undoBtn').removeClass("disabled")
    _onRedoAvailable:=>
      $('#redoBtn').removeClass("disabled")
    _onNoUndoAvailable:=>
      $('#undoBtn').addClass("disabled")
    _onNoRedoAvailable:=>
      $('#redoBtn').addClass("disabled")
    
    _addExporterEntries:=>
      #add exporter entries to menu, and their event handlers
      for index, exporterName of @exporters
         className = "start#{index[0].toUpperCase() + index[1..-1]}Exporter"
         event = "#{index}Exporter:start"
         @events["click .#{className}"] = do(event)-> ->@vent.trigger(event)
         #see http://www.mennovanslooten.nl/blog/post/62 and http://rzrsharp.net/2011/06/27/what-does-coffeescripts-do-do.html
         #for more explanation (or lookup "anonymous functions inside loops")
         @ui.exportersStub.append("<li ><a href='#' class='#{className}'>#{index}</li>") 
           
    _addStoreEntries:=>
      #add store entries to menu, and their event handlers
      for index, store of @stores
         if store.isLogginRequired
           loginClassName = "login#{index[0].toUpperCase() + index[1..-1]}"
           loginEvent = "#{index}Store:login"
           @events["click .#{loginClassName}"] = do(loginEvent)-> ->@vent.trigger(loginEvent)
           
           logoutClassName = "logout#{index[0].toUpperCase() + index[1..-1]}"
           logoutEvent = "#{index}Store:logout"
           @events["click .#{logoutClassName}"] = do(logoutEvent)-> ->@vent.trigger(logoutEvent)
           
           do(index)=>
             onLoggedIn=()=>
               selector = "##{loginClassName}"
               $('.notifications').notify
                message: { text: "#{index}: logged IN" }
                fadeOut:{enabled:true, delay: 1000 }
               .show()
               
               $(selector).replaceWith("<li id='#{logoutClassName}' ><a href='#' class='#{logoutClassName}'><i class='icon-signout' style='color:green'/>  #{index} - Signed In</a></li>")
             
             onLoggedOut=()=>
               selector = "##{logoutClassName}"
               $('.notifications').notify
                message: { text: "#{index}: logged OUT" }
                fadeOut:{enabled:true, delay: 1000 }
               .show()
               $(selector).replaceWith("<li id='#{loginClassName}' ><a href='#' class='#{loginClassName}'><i class='icon-signin' style='color:red'/>  #{index} - Signed out</a></li>")
             
             @vent.on("#{index}Store:loggedIn",()->onLoggedIn())
             @vent.on("#{index}Store:loggedOut",()->onLoggedOut())
           
           @ui.storesStub.append("<li id='#{loginClassName}'><a href='#' class='#{loginClassName}'><i class='icon-signin' style='color:red'/>  #{index} - Signed Out</a></li>") 
    
    onDomRefresh:=>
      @$el.find('[rel=tooltip]').tooltip({'placement': 'bottom'})
      @_addExporterEntries()
      @_addStoreEntries()
      @delegateEvents()
      
      @examplesStub.show( new ExamplesView())
    
    onRedoClicked:=>
      if not ($('#redoBtn').hasClass("disabled"))
        @vent.trigger("file:redoRequest")
    
    onUndoClicked:->
      if not ($('#undoBtn').hasClass("disabled"))
        console.log "triggering undo Request"
        @vent.trigger("file:undoRequest")
    
    _fetchFiles:=>
      #just experimenting
      serverUrl = window.location.href
      examplesUrl = "#{serverUrl}/examples"
      console.log "ServerURL : #{serverUrl}"
      $.get "#{examplesUrl}", (data) =>
        console.log "totot"
        console.log data
        
    showAbout:(ev)=>
      bootbox.dialog """<b>Coffeescad v0.31</b> (pre-alpha)<br/><br/>
      Licenced under the MIT Licence<br/>
      @2012-2013 by Mark 'kaosat-dev' Moissette
      """, [
          label: "Ok"
          class: "btn-inverse"
        ],
        "backdrop" : false
        "keyboard":   true
        "animate":false

  class RecentFileView extends Backbone.Marionette.ItemView
    template: recentFileTemplate
    tagName:  "li"
    
    onRender:()=>
      @$el.attr("id",@model.name)
  
  class RecentFilesView extends Backbone.Marionette.ItemView
    
    
  class ExamplesView extends Backbone.Marionette.ItemView
    tagName:  "li"
    className: "dropdown-submenu examplesTree"
      
    events:
      "click .example":          "onLoadExampleClicked"
      
    constructor:(options)->
      super options
      @examplesData= null
      @examplesHash = {}
      
      @appBaseUrl = window.location.protocol + '//' + window.location.host + window.location.pathname
      @examplesUrl = "#{@appBaseUrl}examples/examples.json"
      $.get "#{@examplesUrl}", (data) =>
        @examplesData = data
        @render()
    
    onLoadExampleClicked:(e)=>
      exampleFullPath = $(e.currentTarget).data("id")
      Project = require "core/projects/project"
      
      exampleName = exampleFullPath.split('/').pop()
      deferredList = []
      
      project = new Project({name:exampleName}) 
      for fileName in @examplesHash[exampleFullPath]
        do(fileName)=>
          projectFile = project.addFile
            name: fileName
            content: ""
          #we need to do ajax request to fetch the files, so lets use deferreds, to make it more practical
          filePath = "#{@appBaseUrl}examples#{exampleFullPath}/#{fileName}"
          deferred = $.get(filePath)
          deferredList.push(deferred)
          $.when(deferred).done (fileContent)=>
            projectFile.content = fileContent
      
      $.when.apply($, deferredList).done ()=>
        project._clearFlags()
        vent.trigger("project:loaded",project) 
   
    render:()=>
      @isClosed = false
      @triggerMethod("before:render", @)
      @triggerMethod("item:before:render", @)
  
      rootEl = @_generateExamplesTree()
      @$el.html("")
      @$el.append(rootEl)
      
      @bindUIElements()
      @triggerMethod("render", @)
      @triggerMethod("item:rendered", @)
      return @
      
    _generateExamplesTree:()=>
      
      createItem=(jsonObj, $obj)=>
        $obj = $obj? null
        if jsonObj.name
          $obj = $('<a>').attr('href', "#").text(jsonObj.name)
          #is this a project?
          if "files" of jsonObj
            $obj= $obj.prepend($("<i class='icon-file'></i>"))
          else
            $obj= $obj.prepend($("<i class='icon-folder-open'></i>"))
          $obj = $('<li>').append($obj)
          
        if jsonObj.length
          $obj = $('<ul>')
          for elem in jsonObj
            $obj.append(createItem(elem))
            
        if jsonObj.categories #array  
          sub = $('<ul>')
          for elem in jsonObj.categories
            sub.append(createItem(elem))
          $obj = $obj.append(sub)
          sub.addClass("dropdown-menu")
        
        if "files" of jsonObj
          $obj.attr("data-id",jsonObj.path)
          $obj.addClass("example")
          #awfull hack
          @examplesHash[jsonObj.path] = jsonObj.files
        else
          $obj.addClass("dropdown-submenu")
        return $obj
      
      result = ""
      if @examplesData
        result = createItem(@examplesData["categories"],@$el)
      return result

  return MainMenuView