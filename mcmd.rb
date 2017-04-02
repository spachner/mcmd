require 'open3'
require 'yaml'

# Usage:
#   cshoes mcmd.rb [<my-conf-file>.yaml]
#

$cfgUseLog     = false # Experimental: Log widget will hang app sometimes
$cfgShowModify = false
$cfgHomeDir    = "/Users/spachner/Documents/dev/spr/mcmd"
$specFileName  = 'mcmd-conf.yaml' # defaile file name, my be overritten by command line argument
$exampleSpec   =
[
    ['ls -1',                'ls -1'],
    ['ls -l',                'ls -l'],
    ['stdout err test',      './testcmd.bash'],
    ['pwd',                  'pwd'],
    ['cat large',            'cat /var/log/monthly.out'],
    ['edit mcmd.rb',         'atom /Users/spachner/Documents/dev/spr/mcmd/mcmd.rb']
]

trap("SIGINT") {
    puts "Exit pending. Please click into GUI window to finalize exit"
    Shoes.quit
}

def dumpSpec s
    s.size.times do |c|
        puts "CmdText >#{s[c][0]}<,\tcmd >#{s[c][1]}<"
    end
end

def readSpec fileName
    if !File.file? fileName
        abort "Cannot read file >#{fileName}<"
    end
    $cfgSpec = YAML.load_file fileName
    puts "Read spec from >#{fileName}<"
end

def writeSpec fileName, spec
    File.open(fileName, 'w') { |f| f.write spec.to_yaml }
    puts "Wrote spec to >#{fileName}<"
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
    puts "Arg given, reading spec from file >#{$specFileName}<"
    readSpec $specFileName
end

#dumpSpec $cfgSpec

Shoes.app(title: "mcmd",  resizable: true) do #width: 1000, height: 500,
    @spec    = $cfgSpec
    @homeDir = $cfgHomeDir
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
    lstackWidth      = 150
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
                @spec.size.times do |c|
                    stack :height => tableHeight do
                        @button[c] = button @spec[c][0], :width => lstackWidth
                    end
                end
            end

            @rstack = stack :margin_top => lrStackMarginTop, :width => rstackWidth do
                #---------------------------------------------------------------
                stack :height => tableHeight do
                    @hd = edit_line :width => rstackWidth do
                        puts "New homeDir >#{@hd.text}<\n"
                        @homeDir = @hd.text
                    end
                end
                @hd.text = @homeDir
                @hd.finish = proc { |slf|
                    puts "New homeDir >#{slf.text}<\n"
                    @homeDir = slf.text
                }
                #---------------------------------------------------------------
                @cmd = Array.new
                @spec.size.times do |c|
                    stack :height => tableHeight do
                        @cmd[c] = edit_line(:width => rstackWidth) do | edit |
                            @spec[c][1] = edit.text
                            dumpSpec @spec
                        end
                        @cmd[c].text = @spec[c][1]
                    end
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
            puts "----------Answer #{@useLog }"
            @logOnOff.checked = @useLog
            @log.show
        else
            @useLog = false
            @log.hide
        end
    end

    # Event handler ------------------------------------------------------------
    @spec.size.times do |c|
        @button[c].click do
            appendLog "execute >#{@spec[c][1]}<\n"

            clearLog
            exe = @spec[c][1].split[0]   # make from e.g. "ls -1" -> "ls"
            if exe.start_with?'./'
                exe = @homeDir + '/' + exe
            end
            ok = system "which #{exe}"
            if !ok
                appendLog ">#{@spec[c][1]}< -> >#{exe}< not executable"
            else
                if @cmdActive
                    appendLog "Other cmd active, ignored"
                    return
                end
                @cmdActive = true
                t = Thread.new do
                    Open3.popen2e(@spec[c][1], :chdir => @homeDir) do
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
    end

    # init ---------------------------------------------------------------------
    initThread = Thread.new do
        sleep 0.5
        modifyCheckState
        logOnOffCheckState
    end
end
