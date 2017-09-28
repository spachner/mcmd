# MacOS: start with 'jruby -J-XstartOnFirstThread mcmd.rb'

require 'shoes' # needed by shoes4 to be run by jruby
require 'open3'
require 'yaml'
require_relative 'lib/mcmdSpec'
require_relative 'lib/mcmdExe'
require_relative 'lib/oscheck'

# Bugs

# Usage:
#   /absolute/path/to/cshoes /absolute/path/to/mcmd.rb [/absolute/path/to/<my-conf-file>.yaml]
#   /absolute/path/to/cshoes /absolute/path/to/mcmd.rb [`pwd`/<my-conf-file>.yaml]

$debug         = false  # true for a little debug
$cfgUseLog     = true   # default state of option
$cfgShowModify = false  # default state of option
# default spec file name, may be overritten by command line argument
$specFileName  = File.expand_path('./', 'mcmd-conf.yaml')

os = OSCheck.new $debug

# this allows to stop mcmd by CTRL-C in shell where cshoes has been startet. Unfottunalely an additional
# mouse click is needed, seems to be a bug in Shoes
#trap("SIGINT") {
#    puts "Exit pending. Please click into GUI window to finalize exit" if os.isMacOS
#    Shoes.quit
#}

$spec = Spec.new $debug
$exe  = Exe.new  $debug
#COLORS = Shoes::COLORS

if ARGV.size < 1
    if !File.file? $specFileName
        puts "No arg given, creating default specFile >#{$specFileName}<"
        $spec.createDefaultFile $specFileName
    else
        puts "No arg given, reading default specFile >#{$specFileName}<"
        $spec.read $specFileName
    end
else
    $specFileName = ARGV[0]
    puts "Arg given, using spec file >#{$specFileName}<"
    $spec.read $specFileName
end

puts "Spec: #{$spec}" if $debug

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

# Linux (Windows?) behaves different and window cannot be resized smaller than initial size, so start with a small window
if os.isMacOS
    $mainWidth  = 800
    $mainHeight = 500
elsif os.isWindows
    $mainWidth  = 100
    $mainHeight = 100
elsif os.isLinux
    $mainWidth  = 100
    $mainHeight = 100
end

#--- Shoes main ----------------------------------------------------------------
Shoes.app(title: "mcmd", resizable: true, width: $mainWidth, height: $mainHeight) do
    @useLog  = $cfgUseLog   # init value, changed by checkbox click

    def clearLog
        @log.text = '' if @useLog
    end

    def appendLog str
        puts str
        @log.text = @log.text + str    if @useLog
        #@log.scroll_to_end if @useLog
        # force redraw slot, slows down execution but command output is seen immediately in log
        #@mainStack.refresh_slot if @logOnOff.checked?
    end

    @lrStackMarginTop = 10
    @tableHeight      = 30
    @lstackWidth      = $spec.getButtonWidth
    @rstackWidth      = 350
    @paraSize         = 9
    @checkMarginTop   = 4
    @checkMarginLeft  = 10
    @paraMarginTop    = @tableHeight/2 - 7
    @paraMarginLeft   = 0
    @paraMarginRight  = 10
    @logMarginTop     = 10
    @logMarginLeft    = 6
    @logHeight        = 100
    @logWidth         = $mainWidth
    @workersHandleRatePerSec = 3

    @logQueueWorker = animate @workersHandleRatePerSec do
        puts "logQueueWorker" if $debug
        #appendLog "logQueue queue.length #{@logQueue.length}\n" if @logQueue.length > 0

        i = 0
        while @logQueue.length > 0 do
            i = i + 1
            s = @logQueue.pop(true)
            puts "logQueue pop #{i} >#{s}<" if $debug
            appendLog s
        end
    end

    @exeStatusQueue = Queue.new
    $exe.setExeStatusQueue @exeStatusQueue

    @exeStatusQueueWorker = animate @workersHandleRatePerSec do
        puts "exeStatusQueueWorker" if $debug
        #appendLog "exeStatusQueue queue.length #{@exeStatusQueue.length}\n" if @exeStatusQueue.length > 0

        j = 0
        while @exeStatusQueue.length > 0 do
            j = j + 1
            s = @exeStatusQueue.pop(true)
            puts "exeStatusQueue: pop #{j} >#{s}<" if $debug
            #appendLog "exeStatusQueue exit status #{s}"
            if s.is_a? Integer
                if s == 0
                    signalCmdEndSuccessful
                else
                    signalCmdEndError
                end
                stopWorkers
            elsif s == 'started'
                signalCmdRun
            elsif s == 'killed'
                signalCmdEndError
                stopWorkers
            else
                puts "***exeStatusQueue: Unknown code >#{s}<"
                stopWorkers
            end
        end
    end

    def startWorkers
        puts "startWorkers--------------" if $debug
        @logQueueWorker.start
        @exeStatusQueueWorker.start
    end

    def stopWorkers
        sleep 2*1/(@workersHandleRatePerSec) # make sure queued event gets handled
        puts "stopWorkers----------------" if $debug
        @logQueueWorker.stop
        @exeStatusQueueWorker.stop
    end

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
                    startWorkers
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
            #stack width: @lstackWidth, margin: 0 do
            #    #background send(COLORS.keys[rand(COLORS.keys.size)])
            #    #@lstack = stack :margin_top => lrStackMarginTop, :width => lstackWidth do
            #    #---------------------------------------------------------------
            #    @sethd = button "Set home dir" do #, :width => @lstackWidth do
            #        #checkAndSetNewBaseDir @hd.text
            #    end
#
            #    #---------------------------------------------------------------
            #    #stack :height => tableHeight do
            #    if withEditLines
            #        # new base dir is stored by return or button click
            #        #@hd = edit_line $spec.getBaseDir, width: @rstackWidth do
            #        @hd = edit_line $spec.getBaseDir do
            #            puts "New base dir >#{@hd.text}<\n" if $debug
            #            checkAndSetNewBaseDir @hd.text
            #        end
            #        #@hd.text = $spec.getBaseDir
#
            #        #@hd = edit_line :width => @rstackWidth # new base dir is stored by return or button click
            #        #@hd.text = $spec.getBaseDir
            #        #@hd.finish = proc { |slf|
            #        #    puts "New base dir >#{slf.text}<\n" if $debug
            #        #    checkAndSetNewBaseDir slf.text
            #        #}
            #    end
            #end
            #---------------------------------------------------------------
            @button = Array.new
            @cmd    = Array.new
            @color  = Array.new
            $spec.getCmds.size.times do |cmdIdx|
                #stack :height => tableHeight do
                stack width: @lstackWidth, margin: 0 do
                    #background send(COLORS.keys[rand(COLORS.keys.size)])
                    background $spec.getColorResolvedByIdx(cmdIdx)
                    buttonText = $exe.substitute $spec.getBtnTxtByIdx(cmdIdx), $spec.getCmds
                    @button[cmdIdx] = button buttonText #, :width => @lstackWidth
                    hover do
                        cmdText = $exe.substitute $spec.getCmdTxtByIdx(cmdIdx), $spec.getCmds
                        puts "hover, #{buttonText}, #{cmdText}" if $debug
                        @cmdText.text = "#{buttonText}: #{cmdText}"
                    end

                    if withEditLines
                        flow do
                            #@cmd[cmdIdx] = edit_line(:width => @rstackWidth) do | edit |
                            @cmd[cmdIdx] = edit_line do | edit |
                                $spec.setCmdTxt cmdIdx, edit.text, true
                            end
                            @cmd[cmdIdx].text = $spec.getCmdTxtByIdx cmdIdx
                            #@cmd[cmdIdx].finish = proc { |slf|
                            #    puts "New cmd >#{slf.text}<\n" if $debug
                            #    $spec.setCmdTxt cmdIdx, slf.text, true
                            #}
                            @color[cmdIdx] = edit_line do | edit |
                                $spec.setColor cmdIdx, edit.text, true
                            end
                            @color[cmdIdx].text = $spec.getColorByIdx cmdIdx
                        end
                    end
                end
            end
        end

        registerEventHandlers
        f
    end

    def createFlowCtrl
        #-----------------------------------------------------------------------
        @flowControl = flow do
#            button("Quit")          { Shoes.quit }
            button("Quit")          { exit 0 }
            button("Kill Command")  { $exe.kill }
            button("Clear Log")     {
                clearLog
                signalCmdIdle
            }
            @modify = check checked: $cfgShowModify do
                modifyCheckState
            end
            para "Modify", size: @paraSize

            @logOnOff = check checked: $cfgUseLog do
                logOnOffCheckState
            end
            para "Log", size: @paraSize

            #button "Test" do
            #    puts '-------set @mainStack height'
            #    #Window.style(:width => 100)#:height => 100,
            #    self.resize(100,100)
            #end
        #end

        #flow do
            #@modify = check checked: $cfgShowModify, :margin_left => @checkMarginLeft, :margin_top => @checkMarginTop do
            #    modifyCheckState
            #end
            #para "Modify", size: @paraSize, :margin_top => @paraMarginTop, :margin_left => @paraMarginLeft, :margin_right => @paraMarginRight
#
            #@logOnOff = check checked: $cfgUseLog, :margin_left => @checkMarginLeft, :margin_top => @checkMarginTop do
            #    logOnOffCheckState
            #end
            #para "Log", size: @paraSize, :margin_top => @paraMarginTop, :margin_left => @paraMarginLeft, :margin_right => @paraMarginRight

            @cmdText = edit_line \
                :resizable => true,
                :margin_left  => 0.01,
                :margin_right => 0.01,
                :width        => 1.0


        end

        #-----------------------------------------------------------------------
        @log = edit_box \
            :resizable    => true,
            :margin_top   => @logMarginTop,
            :margin_left  => 0.01,
            :margin_right => 0.01,
            :width        => 1.0,
            :height       => @logHeight
        #-----------------------------------------------------------------------
    end

    @mainStack = stack do
        fill system_background
        #@mainBack = background rgb(100,100,100)..rgb(200,200,200)
        #     @back  = background green

        #@flowCmd  = createFlowCmd true
        @flowCmd  = createFlowCmd false
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
            #@useLog = confirm("Sorry, Log widget is experimental. Expect freezing app on large output?")
            #@logOnOff.checked = @useLog
            #@log.show if @useLog
            @useLog = true
            @log.show
        else
            @useLog = false
            @log.hide
        end
    end

    def signalCmdIdle
        #background rgb(100,100,100)..rgb(200,200,200)
    end

    def signalCmdRun
        @r = 204
        @g = 153
        @b =  51
        #background rgb(204,153,51)..rgb(@r,@g,@b)

        if (false)
            @dir = 1
            @step = 0
            @ani = animate 10 do |frame|
                factor = 1
                @step = 10#@step + 1
                if @r == 0 || @g == 0 || @b == 0
                    @dir = @dir * -1
                end

                if @r == 255 || @g == 255 || @b == 255
                    @dir = @dir * -1
                end

                if @r <= 255
                    @r = @r+@dir*@step*factor
                end
                if @g <= 255
                    @g = @g+@dir*@step*factor
                end
                if @b <= 255
                    @b = @b+@dir*@step*factor
                end

                if @r < 0
                    @r = 0
                end
                if @g < 0
                    @g = 0
                end
                if @b < 0
                    @b = 0
                end

                if @r >= 255
                    @r = 255
                end
                if @g >= 255
                    @g = 255
                end
                if @b >= 255
                    @b = 255
                end

                puts "#{@dir}, #{@r}, #{@g}, #{@b}" if @debug
                #@flowCmd.background rgb(204,153,51)..rgb(@r,@g,@b)
            end
        end
    end

    def signalCmdEndSuccessful
        #@ani.stop
        #@mainBack = background green..lightgreen
    end

    def signalCmdEndError
        #@ani.stop
        #@mainBack = background red..orange
    end

    #$exe.setLogCB lambda {|str| appendLog str}
    @logQueue = Queue.new
    $exe.setLogQueue @logQueue
    #$exe.setExeCB lambda {signalCmdRun}, lambda {signalCmdEndSuccessful}, lambda {signalCmdEndError}
    #$exe.setExeCB lambda {signalCmdRun}


    stopWorkers

    # init ---------------------------------------------------------------------
    #initThread = Thread.new do
    #    sleep 0.5
    #    modifyCheckState
    #    logOnOffCheckState
    #    signalCmdIdle
    #end
end
