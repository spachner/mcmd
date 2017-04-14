require 'open3'
require 'yaml'

# Usage:
#   /absolute/path/to/cshoes /absolute/path/to/mcmd.rb [/absolute/path/to/<my-conf-file>.yaml]
#   /absolute/path/to/cshoes /absolute/path/to/mcmd.rb [`pwd`/<my-conf-file>.yaml]

$specVersion   = 1      # Just in case the spec file format will change in future
$debug         = false  # true for a litte debug
$cfgUseLog     = false  # default state of option. Experimental! Log widget will hang app sometimes
$cfgShowModify = false  # default state of option
$specFileName  = File.expand_path('./', 'mcmd-conf.yaml') # default spec file name, may be overritten by command line argument

# this allows to stop mcmd by CTRL-C in shell where cshoes has been startet. Unfottunalely an additional
# mouse click is needed, seems to be a bug in Shoes
trap("SIGINT") {
    puts "Exit pending. Please click into GUI window to finalize exit"
    Shoes.quit
}

#--- spec file handling --------------------------------------------------------
$specVersionKey = 'version'
$specBaseDirKey = 'baseDir'
$specCommandKey = 'commands'

$exampleSpec = {
    $specVersionKey => $specVersion,
    $specBaseDirKey => Dir.pwd,
    $specCommandKey => [
        ['ls -1',           'ls -1'],                       # arguments (here '-1') as just added to command string
        ['ls -l',           'ls -l'],
        ['stdout err test', './testcmd.bash'],              # preceed command with './' when baseDir would be used,
                                                            # otherwise PATH is used to locate command. testcmd.bash
                                                            # outputs to strout and stderr which both are replied on
                                                            # console where mcmd has been started from. And on log widget
                                                            # when enabled
        ['pwd',             'pwd'],
        ['cat large',       'cat /var/log/monthly.out'],    # test which output a large file
        ['edit mcmd.rb',    "atom #{Dir.pwd}/mcmd.rb"]
    ]
}

def readSpec fileName
    if !File.file? fileName
        #puts "conf dir = >#{File.expand_path('./', fileName)}<" if $debug
        abort "Cannot read file >#{fileName}<"
    end
    $cfgSpec = YAML.load_file fileName
    puts "Reading spec from >#{fileName}<"
end

def writeSpec fileName, spec
    File.open(fileName, 'w') { |f| f.write spec.to_yaml }
    puts "Writing spec to >#{fileName}<"
end

if ARGV.size-1 < 1
    if !File.file? $specFileName
        puts "No arg given, creating default specFile >#{$specFileName}<"
        writeSpec $specFileName, $exampleSpec
        readSpec  $specFileName
    else
        puts "No arg given, reading default specFile >#{$specFileName}<"
        readSpec  $specFileName
    end
else
    $specFileName = ARGV[1]
    puts "Arg given, using spec file >#{$specFileName}<"
    readSpec $specFileName
end

def updateSpecFileOnDisk
    puts "updateSpecFileOnDisk #{$specFileName}" if $debug
    writeSpec $specFileName, $cfgSpec
end

def getSpecVersion
    $cfgSpec[$specVersionKey]
end

def getSpecBaseDir
    $cfgSpec[$specBaseDirKey]
end

def setSpecBaseDir b
    puts "setSpecBaseDir #{b}" if $debug
    if $cfgSpec[$specBaseDirKey] != b
        $cfgSpec[$specBaseDirKey] = b
        updateSpecFileOnDisk
    end
end

def getSpecCommands
    $cfgSpec[$specCommandKey]
end

def getSpecCommandSet cmdIdx
    $cfgSpec[$specCommandKey][cmdIdx]
end

def setSpecCommandButtonText cmdIdx, text
    puts "setSpecCommandButtonText [#{cmdIdx}]=#{text}" if $debug
    #$cfgSpec[$specCommandKey][cmdIdx][0] = text
    if getSpecCommandSet(cmdIdx)[0] != text
        getSpecCommandSet(cmdIdx)[0] = text
        updateSpecFileOnDisk
    end
end

def setSpecCommandText cmdIdx, text
    puts "setSpecCommandText [#{cmdIdx}]=#{text}" if $debug
    #$cfgSpec[$specCommandKey][cmdIdx][1] = text
    if getSpecCommandSet(cmdIdx)[1] != text
        getSpecCommandSet(cmdIdx)[1] = text
        updateSpecFileOnDisk
    end
end

def dumpSpec s
    puts "Version: #{getSpecVersion}"
    puts "BaseDir: #{getSpecBaseDir}"
    puts "Commands"
    s.size.times do |cmdIdx|
        # puts "CmdText >#{s[cmdIdx][0]}<,\tcmd >#{s[cmdIdx][1]}<"
    end
end

if getSpecVersion != $specVersion
    abort "Wrong spec version. Is #{getSpecVersion}, expected #{$specVersion}"
end

dumpSpec getSpecCommands if $debug

#--- Shoes main ----------------------------------------------------------------
Shoes.app(title: "mcmd",  resizable: true) do #width: 1000, height: 500,
    @spec    = getSpecCommands  #$cfgSpec
    @homeDir = getSpecBaseDir   #$cfgHomeDir
    @useLog  = $cfgUseLog

    def clearLog
        @log.text = '' if @useLog
    end

    def appendLog str
        puts str
        @log.append str    if @useLog
        @log.scroll_to_end if @useLog
    end

    lrStackMarginTop = 10
    tableHeight      = 30
    lstackWidth      = 250
    rstackWidth      = 350
    paraSize         = 9
    checkMarginTop   = 4
    checkMarginLeft  = 10
    paraMarginTop    = tableHeight/2 - 7
    paraMarginLeft   = 0
    paraMarginRight  = 10
    logMarginLeft    = 6

    @mainStack = stack do
        flow do
            @lstack = stack :margin_top => lrStackMarginTop, :width => lstackWidth do
                #---------------------------------------------------------------
                stack :height => tableHeight do
                    @sethd = button "Set home dir", :width => lstackWidth
                end
                #---------------------------------------------------------------
                @button = Array.new
                @spec.size.times do |cmdIdx|
                    stack :height => tableHeight do
                        @button[cmdIdx] = button @spec[cmdIdx][0], :width => lstackWidth
                    end
                end
            end

            @rstack = stack :margin_top => lrStackMarginTop, :width => rstackWidth do
                #---------------------------------------------------------------
                stack :height => tableHeight do
                    @hd = edit_line :width => rstackWidth do
                        puts "New homeDir >#{@hd.text}<\n" if $debug
                        @homeDir = @hd.text
                    end
                end
                @hd.text = @homeDir
                @hd.finish = proc { |slf|
                    puts "New homeDir >#{slf.text}<\n" if $debug
                    @homeDir = slf.text
                    setSpecBaseDir @homeDir
                }
                #---------------------------------------------------------------
                @cmd = Array.new
                @spec.size.times do |cmdIdx|
                    stack :height => tableHeight do
                        @cmd[cmdIdx] = edit_line(:width => rstackWidth) do | edit |
                            @spec[cmdIdx][1] = edit.text if $debug
                            #dumpSpec @spec if $debug
                        end
                        @cmd[cmdIdx].text = @spec[cmdIdx][1]
                    end
                    @cmd[cmdIdx].finish = proc { |slf|
                        puts "New cmd >#{slf.text}<\n" if $debug
                        setSpecCommandText cmdIdx, slf.text
                    }
                end
                #---------------------------------------------------------------
            end
        end

        #-----------------------------------------------------------------------
        flow do
            button("Quit")      { Shoes.quit }
            button("Clear Log") { clearLog   }
            #button "Test" do
            #    puts '-------set @mainStack height'
            #    #Window.style(:width => 100)#:height => 100,
            #    self.resize(100,100)
            #end
        end

        flow do
            @modify = check checked: $cfgShowModify, :margin_left => checkMarginLeft, :margin_top => checkMarginTop do
                modifyCheckState
            end
            para "Modify", size: paraSize, :margin_top => paraMarginTop, :margin_left => paraMarginLeft, :margin_right => paraMarginRight

            @logOnOff = check checked: $cfgUseLog, :margin_left => checkMarginLeft, :margin_top => checkMarginTop do
                logOnOffCheckState
            end
            para "Use Log", size: paraSize, :margin_top => paraMarginTop, :margin_left => paraMarginLeft, :margin_right => paraMarginRight
        end

        #-----------------------------------------------------------------------
        @log = edit_box :margin_left => logMarginLeft, :width => 600, :height => 600, :resizable => true
        #-----------------------------------------------------------------------
    end # stack

    def modifyCheckState
        if @modify.checked?
            @rstack.show
        else
            @rstack.hide
        end
    end

    def logOnOffCheckState
        if @logOnOff.checked?
            @useLog = confirm("Sorry, Log widget is expermental. Expect freezing app on large output?")
            @logOnOff.checked = @useLog
            @log.show
        else
            @useLog = false
            @log.hide
        end
    end

    def exeCmd cmdIdx
        if @cmdActive
            appendLog "Other cmd active, ignored"
        else
            @cmdActive = true
            t = Thread.new do
                Open3.popen2e(@spec[cmdIdx][1], :chdir => @homeDir) do
                    | stdin, stdout_and_stderr, wait_thr |
                    #stdin.close
                    prependStr = "pid #{wait_thr[:pid]}: "
                    stdout_and_stderr.each do |line|
                        appendLog prependStr + line
                    end
                end
                appendLog '********** Command finished ******'
                @cmdActive = false
            end
            #t.join # wait for end of thread
        end
    end

    def getCmdExecutable cmdIdx
        exe = @spec[cmdIdx][1].split[0]   # make from e.g. "ls -1" -> "ls"
        if exe.start_with?'./'
            exe = @homeDir + '/' + exe
        end
        exe
    end

    def isCmdExecutable executable
        system "which #{executable}"
    end

    # Event handler ------------------------------------------------------------
    @spec.size.times do |cmdIdx|
        @button[cmdIdx].click do
            clearLog
            appendLog "execute >#{@spec[cmdIdx][1]}<\n"
            executable = getCmdExecutable cmdIdx
            if isCmdExecutable executable
                exeCmd cmdIdx
            else
                appendLog ">#{@spec[cmdIdx][1]}< -> >#{executable}< not executable"
            end
        end
    end

    # init ---------------------------------------------------------------------
    initThread = Thread.new do
        sleep 0.5
        modifyCheckState
        logOnOffCheckState
    end
end
