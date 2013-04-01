define (require) ->
  reqRes = require 'modules/core/messaging/appReqRes'
  utils = require "modules/core/utils/utils"
  CoffeeScript = require 'CoffeeScript'
  
  ##Inner workflow
  #- Compile
  #   - Preprocess (resolve includes, parameters (defines))
  #   - Compile Coffeescript to js
  #- rebuildSolid (convert data to geometry) : can be in sync mode (ui thread, simple) or async (web workers)
   
  class CsgProcessor
    #processes a csg script
    construtor:()->
      @async = false
      @debug = false
      
    processScript:(script, async=false, callback)-> 
      @script = script
      @async = async
      @callback = callback
      
      @rebuildSolid()
      
    rebuildSolid:() =>
      console.log "Using background rebuild:#{@async}"
      @processing = true
      paramValues = null
      try
        if @async
          @_prepareScriptASync()
          @parseScriptASync(@script, paramValues)
        else
          @_prepareScriptSync()
          @parseScriptSync(@script, paramValues)
        @processing = false
      catch error
        console.log error.stack
        @callback(null,null,null, error)
        @processing = false
      
    _prepareScriptASync:()=>
      #prepare the source for compiling : convert to coffeescript, inject dependencies etc
      @script = """
      {BaseMaterial,CAGBase,CSGBase,Circle,Connector,Cube,Cylinder,extend,Line2D,Line3D,log,Material,Matrix4x4,
      merge, OrthoNormalBasis,Part,Path2D,Plane,Polygon,PolygonShared,Properties, Rectangle,
      RoundedCube,RoundedCylinder,RoundedRectangle,Side,Sphere,Vector2D,Vector3D,
      Vertex,Vertex2D,classRegistry,hull,intersect, otherRegistry,register,rotate,
         scale, solve2Linear,subtract,translate,union}=csg
        
      assembly = new CSGBase();
        
      #{@script}
      
      """
      @script = CoffeeScript.compile(@script, {bare: true})
      #console.log "JSIFIED script"
      #console.log @script
    
    _prepareScriptSync:()=>
      #prepare the source for compiling : convert to coffeescript, inject dependencies etc
      @script = """
      {BaseMaterial,CAGBase,CSGBase,Circle,Connector,Cube,Cylinder,extend,Line2D,Line3D,log,Material,Matrix4x4,
      merge, OrthoNormalBasis,Part,Path2D,Plane,Polygon,PolygonShared,Properties, Rectangle,
      RoundedCube,RoundedCylinder,RoundedRectangle,Side,Sphere,Vector2D,Vector3D,
      Vertex,Vertex2D,classRegistry,hull,intersect, otherRegistry,register,rotate,
         scale, solve2Linear,subtract,translate,union}=csg
         
      #clear log entries
      log.entries = []
      
      #include script
      #{@script}
      
      #export data to the passed "partRegistry" object
      for klass of classRegistry
        partRegistry[klass] = classRegistry[klass]
      
      #export log entries to the passed in "logEntries" object
      for entry in log.entries
        logEntries.push(entry)
      """
      
      @script = CoffeeScript.compile(@script, {bare: true})
      #console.log "JSIFIED script"
      #console.log @script
    
    parseScriptSync: (script, mainParameters) -> 
      #Parse the given coffeescad script in the UI thread (blocking but simple)
      workerscript = script
      if @debug
        workerscript += "//Debugging;\n"
        workerscript += "debugger;\n"

      csg = require './csg'      
      class Assembly extends csg.CSGBase
        constructor:()->
          super
      rootAssembly = new Assembly()
      partRegistry = {}
      logEntries = []
      
      f = new Function("assembly","partRegistry", "logEntries","csg",workerscript)
      result = f(rootAssembly,partRegistry,logEntries, csg)
      
      @callback(rootAssembly,partRegistry,logEntries)
    
    parseScriptASync:(script, params)->
      #Parse the given coffeescad script in a seperate thread (web worker)
      rootUrl = window.location.protocol + '//' + window.location.host+ window.location.pathname
      rootUrl = rootUrl.replace('index.html','')
      console.log "rootUrl "+rootUrl
      workerScript = """
      var rootUrl = "#{rootUrl}";
      importScripts(rootUrl + '/assets/js/libs/require.min.js');
      csg = null;
      require(
        {baseUrl: rootUrl +"/app"},["require","modules/core/projects/csg/csg"],
        function(require,csg){
            try
            {
              #{script}
              var result_compact = assembly.toCompactBinary()
              postMessage({cmd: 'rendered', rootAssembly: result_compact, partRegistry:classRegistry,'logEntries':log.entries});
            }
            catch(error)
            {
              postMessage({cmd: 'error', err: {msg:error.message, lineNumber:error.lineNumber,stack:error.stack} });
            }
            
      });
      """
      
      ###
      onmessage = function(e) 
      { 
            var data = e.data;
            if(data == 'render')
            {
              try
              {
                #{script}
                var result_compact = assembly.toCompactBinary()
                postMessage({cmd: 'rendered', rootAssembly: result_compact, partRegistry:classRegistry});
              }
              catch(error)
              {
                postMessage({cmd: 'error', err: {msg:error.message, lineNumber:error.lineNumber,stack:error.stack} });
              }
            }
            if(data == 'stop')
            {
              postMessage('msg from worker: I WILL STOP'); 
            }
            if(data == 'msg')
            {
               //postMessage({txt: "Got", cmd:"log"});
            }
      }
      ###

      blobURL = utils.textToBlobUrl(workerScript)
      worker = new Worker(blobURL)
      worker.onmessage = (e) =>
        if e.data
          if e.data.cmd is 'rendered'
            logEntries = e.data.logEntries
            converters = require './converters' 
            rootAssembly = converters.fromCompactBinary(e.data.rootAssembly)
            partRegistry = e.data.partRegistry
            @callback(rootAssembly,partRegistry,logEntries)
          else if e.data.cmd is "error"
            err = e.data.err
            error = new Error(err.msg)#{"message":err.msg,"lineNumber":err.lineNumber, "stack":err.stack})
            error.lineNumber=err.lineNumber
            error.stack = err.stack
            #throw  error
            @callback(null, null,null, error)
          else if e.data.cmd is "log"
            console.log e.data.txt
      worker.onerror = (error) =>
        errtxt = "Error in line " + error.lineno + ": " + error.message
        @callback(null, null, null, errtxt) 
      worker.postMessage("render")
      return

  #######################
  ### 
    createParamControls: ->
      #@parameterstable.innerHTML = ""
      @paramControls = []
      paramControls = []
      tablerows = []
      for i in [0..@paramDefinitions.length]
        errorprefix = "Error in parameter definition #"+(i+1)+": "
        paramdef = @.paramDefinitions[i]
        if !('name' in paramdef) then throw new Error(errorprefix + "Should include a 'name' parameter")
        type = "text"
        type = if 'type' in paramdef then paramdef.type
  
        if( (type != "text") && (type != "int") && (type != "float") && (type != "choice") )
          throw new Error(errorprefix + "Unknown parameter type '"+type+"'")
        control = null
        if( (type == "text") || (type == "int") || (type == "float") )
          control = document.createElement("input")
          control.type = "text"
          if('default' in paramdef)
            control.value = paramdef.default
          else
            if( (type == "int") || (type == "float") )
              control.value = "0"
            else
              control.value = ""
        else if(type == "choice")
          if !('values' in paramdef) then throw new Error(errorprefix + "Should include a 'values' parameter") 
          control = document.createElement("select")
          values = paramdef.values
          captions=null
          if 'captions' in paramdef
            captions = paramdef.captions;
            if captions.length != values.length then throw new Error(errorprefix + "'captions' and 'values' should have the same number of items")
          else
            captions = values
          selectedindex = 0
          for valueindex in [0..values.length]
            option = document.createElement("option")
            option.value = values[valueindex]
            option.text = captions[valueindex]
            control.add(option)
            if 'default' in paramdef
              if paramdef.default == values[valueindex]
  
                selectedindex = valueindex
                
          if values.length > 0
            control.selectedIndex = selectedindex
  
        paramControls.push(control)
        tr = document.createElement("tr")
        td = document.createElement("td")
        label = paramdef.name + ":"
        if 'caption' in paramdef
          label = paramdef.caption
  
        td.innerHTML = label
        tr.appendChild(td)
        td = document.createElement("td")
        td.appendChild(control)
        tr.appendChild(td)
        tablerows.push(tr)
        
      tablerows.map((tr) ->
        @parameterstable.appendChild(tr)
      )
      @paramControls = paramControls
  
    getParamDefinitions: (script)->
      scriptisvalid = true
      try
        # first try to execute the script itself
        # this will catch any syntax errors
        f = new Function(script)
        f()
      catch e 
        scriptisvalid = false;
      params = []
      if(scriptisvalid)
        script1 = "if(typeof(getParameterDefinitions) == 'function') {return getParameterDefinitions();} else {return [];} "
        script1 += script
        f = new Function(script1)
        params = f()
        if( (typeof(params) != "object") || (typeof(params.length) != "number") )
          throw new Error("The getParameterDefinitions() function should return an array with the parameter definitions")
      return params
      
     getParamValues: ()->
       if @debug
         console.log("Getting param values")
         console.log("#{@paramDefinitions.length}")
       paramValues = {}
       for i in [0...@paramDefinitions.length]
          paramdef = @paramDefinitions[i]
          type = "text"
          if 'type' in paramdef
            type = paramdef.type
          control = @paramControls[i]
          value = ""
          if( (type == "text") || (type == "float") || (type == "int") )
            value = control.value;
            if( (type == "float") || (type == "int") )
              isnumber = !isNaN(parseFloat(value)) && isFinite(value)
              if(!isnumber)
                throw new Error("Not a number: "+value)
              if(type == "int")
                value = parseInt(value)
              else
                value = parseFloat(value);
  
          else if type == "choice"
            value = control.options[control.selectedIndex].value
          paramValues[paramdef.name] = value
       if @debug
         console.log("Finished getting param values")
       return paramValues
###
  return CsgProcessor