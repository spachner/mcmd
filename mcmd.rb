require 'open3'
require 'yaml'
require 'mcmdSpec'
require 'mcmdExe'

# Bugs

# Usage:
#   /absolute/path/to/cshoes /absolute/path/to/mcmd.rb [/absolute/path/to/<my-conf-file>.yaml]
#   /absolute/path/to/cshoes /absolute/path/to/mcmd.rb [`pwd`/<my-conf-file>.yaml]

$debug         = false  # true for a little debug
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
        $spec.createDefaultFile $specFileName
    else
        puts "No arg given, reading default specFile >#{$specFileName}<"
        $spec.read $specFileName
    end
else
    $specFileName = ARGV[1]
    puts "Arg given, using spec file >#{$specFileName}<"
    $spec.read $specFileName
end

puts $spec if $debug

# ------------------------------------------------------------------------------
def checkAndSetNewBaseDir dir
    puts "checkAndSetNewBaseDir #{dir}" if $debug
    @useNewDir = true
    if !File.directory?(dir)
        @useNewDir = confirm("Sorry, dir >#{dir}< does no exist. Use anyway?")
    end
    if @useNewDir
        $spec.setBaseDir dir, true
    else
        puts "reset base dir to #{$spec.getBaseDir}" if $debug
        @hd.text = $spec.getBaseDir
    end
end

$mainWidth  = 800
$mainHeight = 500

#--- Shoes main ----------------------------------------------------------------
Shoes.app(title: "mcmd", resizable: true, width: $mainWidth, height: $mainHeight) do
    @useLog  = $cfgUseLog   # init value, changed by checkbox click

    def clearLog
        @log.text = '' if @useLog
    end

    def appendLog str
        puts str
        @log.append str    if @useLog
        @log.scroll_to_end if @useLog
        @mainStack.refresh_slot if @logOnOff.checked? # force redraw slot, slows down execution but command output is seen immediately in log
    end

    @lrStackMarginTop = 10
    @tableHeight      = 30
    @lstackWidth      = 250
    @rstackWidth      = 350
    @paraSize         = 9
    @checkMarginTop   = 4
    @checkMarginLeft  = 10
    @paraMarginTop    = @tableHeight/2 - 7
    @paraMarginLeft   = 0
    @paraMarginRight  = 10
    @logMarginLeft    = 6
    @logHeight        = 300
    @logWidth         = $mainWidth

    def registerEventHandlers
        # Event handler ------------------------------------------------------------
        $spec.getCmds.size.times do |cmdIdx|
            @button[cmdIdx].click do
                clearLog

                cmdWithVars = $spec.getCmdTxtByIdx(cmdIdx)
                cmd = cmdWithVars
                puts "before var sub >#{cmd}<" if $debug
                cmd = $exe.substitute cmd, $spec.getCmds
                puts "after  var sub >#{cmd}<" if $debug

                if cmdWithVars != cmd
                    appendLog "try to execute >#{cmdWithVars}< results in >#{cmd}<\n"
                else
                    appendLog "try to execute >#{cmd}<\n"
                end

                executable = $exe.getCmdExecutable cmd
                if $exe.isCmdExecutable executable
                    $exe.exeCmd cmd
                else
                    appendLog ">#{cmdWithVars}< results in >#{cmd}< is not executable"
                    signalCmdEndError
                end
            end
        end
    end

    def createFlowCmd withEditLines
        f = flow do
            #@lstack = stack :margin_top => lrStackMarginTop, :width => lstackWidth do
            #---------------------------------------------------------------
            #stack :height => tableHeight do
            @sethd = button "Set home dir", :width => @lstackWidth do
                checkAndSetNewBaseDir @hd.text
            end
            #end
            #---------------------------------------------------------------
            #stack :height => tableHeight do
            if withEditLines
                @hd = edit_line :width => @rstackWidth # new base dir is stored by return or button click
                #end
                @hd.text = $spec.getBaseDir
                @hd.finish = proc { |slf|
                    puts "New base dir >#{slf.text}<\n" if $debug
                    checkAndSetNewBaseDir slf.text
                }
            end

            #---------------------------------------------------------------
            @button = Array.new
            @cmd    = Array.new
            $spec.getCmds.size.times do |cmdIdx|
                #stack :height => tableHeight do

                buttonText = $exe.substitute $spec.getBtnTxtByIdx(cmdIdx), $spec.getCmds

                @button[cmdIdx] = button buttonText, :width => @lstackWidth
                #end

                if withEditLines
                    @cmd[cmdIdx] = edit_line(:width => @rstackWidth) do | edit |
                        $spec.setCmdTxt cmdIdx, edit.text, false
                    end
                    @cmd[cmdIdx].text = $spec.getCmdTxtByIdx cmdIdx
                    #end
                    @cmd[cmdIdx].finish = proc { |slf|
                        puts "New cmd >#{slf.text}<\n" if $debug
                        $spec.setCmdTxt cmdIdx, slf.text, true
                    }
                end
            end
        end
        registerEventHandlers
        f
    end

    def createFlowCtrl
        #-----------------------------------------------------------------------
        @flowControl = flow do
            button("Quit")          { Shoes.quit }
            button("Kill Command")  { $exe.kill }
            button("Clear Log")     { clearLog   }
            #button "Test" do
            #    puts '-------set @mainStack height'
            #    #Window.style(:width => 100)#:height => 100,
            #    self.resize(100,100)
            #end
        end

        flow do
            @modify = check checked: $cfgShowModify, :margin_left => @checkMarginLeft, :margin_top => @checkMarginTop do
                modifyCheckState
            end
            para "Modify", size: @paraSize, :margin_top => @paraMarginTop, :margin_left => @paraMarginLeft, :margin_right => @paraMarginRight

            @logOnOff = check checked: $cfgUseLog, :margin_left => @checkMarginLeft, :margin_top => @checkMarginTop do
                logOnOffCheckState
            end
            para "Log", size: @paraSize, :margin_top => @paraMarginTop, :margin_left => @paraMarginLeft, :margin_right => @paraMarginRight
        end

        #-----------------------------------------------------------------------
        @log = edit_box :resizable => true, :margin_left => @logMarginLeft, :width => @logWidth, :height => @logHeight
        #-----------------------------------------------------------------------
    end

    @mainStack = stack do
        @flowCmd  = createFlowCmd true
        createFlowCtrl
    end # stack

    def modifyCheckState
        if @modify.checked?
            #@rstack.show
            @flowCmd.clear {
                createFlowCmd true
            }
        else
            #@rstack.hide
            @flowCmd.clear {
                createFlowCmd false
            }
        end
    end

    def logOnOffCheckState
        if @logOnOff.checked?
            @useLog = confirm("Sorry, Log widget is experimental. Expect freezing app on large output?")
            @logOnOff.checked = @useLog
            @log.show if @useLog
        else
            @useLog = false
            @log.hide
        end
    end

    def signalCmdRun
        @flowCmd.background yellow
    end

    def signalCmdEndSuccessful
        @flowCmd.background green
    end

    def signalCmdEndError
        @flowCmd.background red
    end

    $exe.setLogCB lambda {|str| appendLog str}
    $exe.setExeCB lambda {signalCmdRun}, lambda {signalCmdEndSuccessful}, lambda {signalCmdEndError}

    # init ---------------------------------------------------------------------
    initThread = Thread.new do
        sleep 0.5
        modifyCheckState
        logOnOffCheckState
    end
end
