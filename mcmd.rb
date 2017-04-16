require 'open3'
require 'yaml'
require 'mcmdSpec'
require 'mcmdExe'

# Usage:
#   /absolute/path/to/cshoes /absolute/path/to/mcmd.rb [/absolute/path/to/<my-conf-file>.yaml]
#   /absolute/path/to/cshoes /absolute/path/to/mcmd.rb [`pwd`/<my-conf-file>.yaml]

$debug         = true   # true for a litte debug
$cfgUseLog     = false  # default state of option. Experimental! Log widget will hang app sometimes
$cfgShowModify = false  # default state of option
$specFileName  = File.expand_path('./', 'mcmd-conf.yaml') # default spec file name, may be overritten by command line argument

# this allows to stop mcmd by CTRL-C in shell where cshoes has been startet. Unfottunalely an additional
# mouse click is needed, seems to be a bug in Shoes
trap("SIGINT") {
    puts "Exit pending. Please click into GUI window to finalize exit"
    Shoes.quit
}

$spec = Spec.new $debug
$exe  = Exe.new  $debug

if ARGV.size-1 < 1
    if !File.file? $specFileName
        puts "No arg given, creating default specFile >#{$specFileName}<"
        $spec.createDefaultSpecFile $specFileName
    else
        puts "No arg given, reading default specFile >#{$specFileName}<"
        $spec.readSpec $specFileName
    end
else
    $specFileName = ARGV[1]
    puts "Arg given, using spec file >#{$specFileName}<"
    $spec.readSpec $specFileName
end

$spec.dumpSpec if $debug

# ------------------------------------------------------------------------------
def checkAndSetNewBaseDir dir
    puts "checkAndSetNewBaseDir #{dir}" if $debug
    @useNewDir = true
    if !File.directory?(dir)
        @useNewDir = confirm("Sorry, dir >#{dir}< does no exist. Use anyway?")
    end
    if @useNewDir
        $spec.setSpecBaseDir dir, true
    else
        puts "reset base dir to #{$spec.getSpecBaseDir}" if $debug
        @hd.text = $spec.getSpecBaseDir
    end
end

def getCmdExecutable cmdIdx
    cmd = $spec.getSpecCmdTextByIdx(cmdIdx)
    puts "getCmdExecutable before var sub >#{cmd}<" if $debug
    cmd = $exe.substitute cmd, $spec.getSpecCmds
    puts "getCmdExecutable after  var sub >#{cmd}<" if $debug
    exe = cmd.split[0]   # make from e.g. "ls -1" -> "ls"
    if exe.start_with?'./'
        exe = $spec.getSpecBaseDir + '/' + exe
    end
    puts "getCmdExecutable >#{$spec.getSpecCmdTextByIdx(cmdIdx)}< is >#{exe}<" if $debug
    exe
end

def isCmdExecutable executable
    system "which #{executable}"
end

def exeCmd cmdIdx
    if @cmdActive
        appendLog "Other cmd active, ignored"
    else
        cmd = $spec.getSpecCmdTextByIdx(cmdIdx)
        puts "exeCmd before var sub >#{cmd}<" if $debug
        cmd = $exe.substitute cmd, $spec.getSpecCmds
        puts "exeCmd after  var sub >#{cmd}<" if $debug
        @cmdActive = true
        t = Thread.new do
            Open3.popen2e(cmd, :chdir => $spec.getSpecBaseDir) do
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

#--- Shoes main ----------------------------------------------------------------
Shoes.app(title: "mcmd", resizable: true, width: 700, height: 500) do
    @useLog  = $cfgUseLog   # init value, changed by checkbox click

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
                    @sethd = button "Set home dir", :width => lstackWidth do
                        checkAndSetNewBaseDir @hd.text
                    end
                end
                #---------------------------------------------------------------
                @button = Array.new
                $spec.getSpecCmds.size.times do |cmdIdx|
                    stack :height => tableHeight do
                        @button[cmdIdx] = button $spec.getSpecButtonTextByIdx(cmdIdx), :width => lstackWidth
                    end
                end
            end

            @rstack = stack :margin_top => lrStackMarginTop, :width => rstackWidth do
                #---------------------------------------------------------------
                stack :height => tableHeight do
                    @hd = edit_line :width => rstackWidth # new base dir is stored by return or button click
                end
                @hd.text = $spec.getSpecBaseDir
                @hd.finish = proc { |slf|
                    puts "New base dir >#{slf.text}<\n" if $debug
                    checkAndSetNewBaseDir slf.text
                }
                #---------------------------------------------------------------
                @cmd = Array.new
                $spec.getSpecCmds.size.times do |cmdIdx|
                    stack :height => tableHeight do
                        @cmd[cmdIdx] = edit_line(:width => rstackWidth) do | edit |
                            $spec.setSpecCmdText cmdIdx, edit.text, false
                        end
                        @cmd[cmdIdx].text = $spec.getSpecCmdTextByIdx cmdIdx
                    end
                    @cmd[cmdIdx].finish = proc { |slf|
                        puts "New cmd >#{slf.text}<\n" if $debug
                        $spec.setSpecCmdText cmdIdx, slf.text, true
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
            para "Log", size: paraSize, :margin_top => paraMarginTop, :margin_left => paraMarginLeft, :margin_right => paraMarginRight
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
            @useLog = confirm("Sorry, Log widget is experimental. Expect freezing app on large output?")
            @logOnOff.checked = @useLog
            @log.show
        else
            @useLog = false
            @log.hide
        end
    end

    # Event handler ------------------------------------------------------------
    $spec.getSpecCmds.size.times do |cmdIdx|
        @button[cmdIdx].click do
            clearLog
            appendLog "try to execute >#{$spec.getSpecCmdTextByIdx(cmdIdx)}<\n"
            executable = getCmdExecutable cmdIdx
            if isCmdExecutable executable
                exeCmd cmdIdx
            else
                appendLog ">#{$spec.getSpecCmdTextByIdx(cmdIdx)}< -> >#{executable}< not executable"
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
