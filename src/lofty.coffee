#!/usr/bin/env node

###
 Settings
###

FILE_ENCODING	= 'utf-8'
EOL 			= '\n';

###
 Module dependencies
###

coffee			= require 'coffee-script'
colors			= require 'colors'
program			= require 'commander'
fs 				= require 'fs'
fse				= require 'fs-extra'
yaml			= require 'js-yaml'
less			= require 'less'
path 			= require 'path'
wrench			= require 'wrench'
exists			= fs.exists or path.exists
configuration	= {}


###
 Global vars
###

build_dir = '/_tmp/'
_allowed_extensions = [
	"css",
	"html",
	"js",
	"md",
	"php",
	"png",
	"po",
	"pot",
	"twig",
	"txt",
	"yml",
	"yaml"
]

_other_extensions = [
	"git",
	"gitattributes"
	"gitignore",
	"less",
	"coffee",
	"meta"
]

coffeeSources = []
queue = 0

###
 Logging
###

logging = Object
logging.log = (message) ->
	console.log(message)
logging.error = (message) ->
	console.error(message.red)
logging.verbose = (message) ->
	if program.verbose
		console.info(message.yellow)
logging.verboseGreen = (message) ->
	if program.verbose
		console.info(message.green)

logging.verboseRed = (message) ->
	if program.verbose
		console.info(message.red)


getAbsDir		= (filepath) ->
	path.join process.cwd(), filepath

exports.run = (done='run') ->

	program
		.version('1.0.0')
		.option('-d, --distribute', 'Build distribution version')
		.option('-v, --verbose', 'Prints debug stuff to screen')
		.option('-n, --nonamespacing', 'Does not change lava_ into plugin namespace if this flag is present')
		.parse(process.argv)

	program.parse(process.argv);
	checkConfiguration()







checkConfiguration = ->
	# Load configuration file
	logging.verbose('Checking file structure...')

	if not fs.existsSync getAbsDir( '/lofty.yaml' )
		logging.error "No lofty.yaml file found in current directory"
	if not fs.existsSync getAbsDir( '/src/' )
		logging.error "No /src/ directory found"
	if not fs.existsSync getAbsDir( '/libs/lava/classes/plugin.php' )
		logging.error "No /libs/lava/clases/plugin.php file found. Please ensure that git-submodules are initialised"

	try
		configuration = require( getAbsDir('/lofty.yaml') )
	catch e
		logging.error 'Error in lofty.yaml file'
		console.log(e)

	logging.verboseGreen 'Lofty.yaml file loaded'

	if program.distribute
		logging.verboseGreen 'Distribution Build'
		build_dir = "/dist/"
	else
		logging.verboseGreen 'Development Build'
		build_dir = '/build/'

	createTmpDir()



# Create temporary build directory

createTmpDir = (called=0)  ->
	called = called + 1

	if fs.existsSync getAbsDir( build_dir )
		try
			logging.verbose 'Old temporary directory exists'
			wrench.rmdirSyncRecursive getAbsDir( build_dir )
			logging.verbose 'Old temporary directory deleted'
		catch e
			if called < 10
				createTmpDir(called)
			else
				logging.error 'Error removing old build directory - have you got a file open?'

	try
		fs.mkdirSync getAbsDir( build_dir )
	catch e
		if called < 10
				createTmpDir(called)
		else
			logging.error 'Error creating new build directory'
	logging.verboseGreen 'New temporary directory created'

	copyLavaFiles()






# Copy files

copyLavaFiles = ->
	try
		logging.verboseGreen 'Copying Lava files'
		src = getAbsDir('/libs/lava/')
		dest = getAbsDir( build_dir )
		fse.copy src, dest, copyPluginFiles

	catch e
		logging.error 'Error copying files to build directory'
		console.error e
		process.exit()

copyPluginFiles = ->
	try
		logging.verboseGreen 'Copying Plugin files'
		src = getAbsDir('/src/')
		dest = getAbsDir( build_dir )
		fse.copy src, dest, changeDir
	catch e
		logging.error 'Error copying files to build directory'
		console.error e
		process.exit()

changeDir = ->
	logging.verbose 'Switching into build directory'
	process.chdir( getAbsDir( build_dir ) )

	compileAssets()

# Compile LESS

###
	Walk through LESS directory compiling to css
###

compileAssets = ->
	logging.verbose 'Compiling assets'
	compileLess()
	compileCoffee()


compileLess = ->
	compileLessDir( getAbsDir() )

compileLessDir = (dir) ->
	parser = new less.Parser
	prefix = dir + '/'
	files = fs.readdirSync( dir )
	for file in files
		absFile = prefix + file
		if fs.statSync(absFile).isDirectory()
			compileLessDir(absFile)
		else
			if file.substr(-5) == '.less'
				if file.substr(0,1) != '_'
					logging.verboseGreen "Compiling #{file}"
					outfile = absFile.replace /less/g, 'css'
					parser = new(less.Parser)({
						paths: [dir],
						filename: absFile
					})
					preCompile = fs.readFileSync( absFile, FILE_ENCODING )

					upQueue()

					parser.parse preCompile, (err, tree) ->
						if err
							return console.error err
						if program.distribute
							postCompile = tree.toCSS({compress: true})
						else
							postCompile = tree.toCSS()

						fs.writeFileSync outfile, postCompile, FILE_ENCODING

						if downQueue()
							compiledAssets()








# Compile COFFEE

compileCoffee = ->
	logging.verbose 'Compiling coffee files'
	coffeeSources = [getAbsDir()]
	compileCoffeeDir getAbsDir(), yes, path.normalize getAbsDir()

compileCoffeeDir = (dir) ->
	files = fs.readdirSync(dir)
	for file in files
		absFile = dir + '/' + file
		if fs.statSync(absFile).isDirectory()
			if file.substr(-7) == '.coffee'
				code = getCoffeeFiles( absFile, {}, yes )
				code = coffee.compile code
				outfile = absFile.replace /coffee/g, 'js'
				fs.writeFileSync outfile, code, FILE_ENCODING
			else
				compileCoffeeDir(absFile)
		else
			if file.substr(-7) == '.coffee'
				if file.substr(0,1) != '_'
					logging.verboseGreen "Compiling #{file}"
					outfile = absFile.replace /coffee/g, 'js'
					preCompile = fs.readFileSync( absFile, FILE_ENCODING )

					upQueue()

					postCompile = coffee.compile code

					fs.writeFileSync outfile, postCompile, FILE_ENCODING

					if downQueue()
						compiledAssets()

getCoffeeFiles = (dir, coffeeFiles, concat=false) ->
	files = fs.readdirSync(dir)
	for file in files
		absFile = dir + '/' + file
		if fs.statSync(absFile).isDirectory()
			coffeeFiles = getCoffeeFiles(absFile, coffeeFiles)
		else
			if file.substr(-7) == '.coffee'
				if file.substr(0,4) == 'main'
					coffeeFiles['0'+absFile] = fs.readFileSync( absFile, FILE_ENCODING )
				else
					coffeeFiles[absFile] = fs.readFileSync( absFile, FILE_ENCODING )
	if concat
		returnCode = ''
		for i of coffeeFiles
			returnCode = returnCode + "\n" + coffeeFiles[i]
		return returnCode
	else
		return coffeeFiles


compiledAssets = ->
	namespaceClasses()




# Process class names

namespaceClasses = ->
	logging.verbose 'Namespacing php classes'
	namespaceClassesWorker getAbsDir()
	cleanUpDir()


namespaceClassesWorker = (dir) ->
	files = fs.readdirSync( dir )
	ns = configuration.class_namespace
	for file in files
		absFile = dir + '/' + file
		if fs.statSync(absFile).isDirectory()
			namespaceClassesWorker(absFile)
		else
			if file.substr(-4) == '.php'
				code = fs.readFileSync absFile, FILE_ENCODING
				# matches "class Lava_* extends Lava_*"

				code = code.replace /^\s*class\s+Lava(.*?)\s+extends\s+Lava(.*?)\s*{*\s*$/gm, "class #{ns}$1 extends #{ns}$2"
				code = code.replace /^\s*class\s+(.*?)\s+extends\s+Lava(.*?)\s*{*\s*$/gm, "class $1 extends #{ns}$2"
				code = code.replace /^\s*class\s+Lava(.*?)\s+extends\s+(.*?)\s*{*\s*$/gm, "class #{ns}$1 extends $2"

				code = code.replace "$the_plugin = new Lava( __FILE__ );", "$the_plugin = new #{ns}( __FILE__ );"

				fs.writeFileSync absFile, code


# Cleanup files

cleanUpDir = ->
	logging.verbose 'Cleaning up directory'
	cleanUpDirWorker( process.cwd() )

cleanUpDirWorker = (dir) ->
	if fs.existsSync dir
		upQueue()
		fs.readdir dir, (err, files) ->
			for file in files
				absFile = "#{dir}/#{file}"
				if fs.existsSync absFile
					if fs.statSync(absFile).isDirectory()
						cleanUpDirWorker(absFile)
					else
						ext = file.substr(file.lastIndexOf('.') + 1)
						if ext not in _allowed_extensions
							if ext in _other_extensions
								fs.unlinkSync absFile
							else
								logging.verboseRed "Un-handled extension '#{ext}'"
			if fs.existsSync(dir) and fs.readdirSync(dir).length == 0
				fs.rmdirSync dir
				new_dir = path.resolve dir, '../'
				cleanUpDirWorker(new_dir)
			if downQueue()
				copyToTestServer()

copyToTestServer = ->
	if configuration.test_server isnt undefined
		logging.verbose 'Copying to test server'
		src = getAbsDir()
		dest = configuration.test_server
		fse.copy src, dest, (err, other) ->








upQueue = ->
	queue = queue + 1

downQueue = ->
	queue = queue - 1
	if queue == 0
		return true