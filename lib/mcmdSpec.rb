#--- mcmd spec file handling

$specVersion     = 2      # 1: initial, 2: with color
$specVersionKey  = 'version'
$specButtonWidth = 'buttonWidth'
$specBaseDirKey  = 'baseDir'
$specEditor      = 'editor'
$specColors      = 'colors'
$specColorGradientPercent = 'colorsGradientPercent'
$specCommandKey  = 'commands'

$exampleSpec = {
    $specVersionKey  => $specVersion,
    $specButtonWidth => 250,
    $specBaseDirKey  => Dir.pwd,
    $specEditor      => 'subl',
    $specColors      => ['#00FFFF', '#0000FF', '#FF8000', '#FFFF00'],  # see Shoes::COLORS
    $specColorGradientPercent => 30,
    $specCommandKey  => [
        ['ls -1',                'ls -1', 0],                      # arguments (here '-1') as just added to command string
        ['ls -l',                'ls -l', 1],
        ['ls var arg',           '$(lscmd) $(lsarg)', 2],
        ['stdout err test succ', './test/testcmd.bash 0', 3],
        ['stdout err test fail', './test/testcmd.bash 1', 0],  # preceed command with './' when baseDir would be used,
                                                               # otherwise PATH is used to locate command. testcmd.bash
                                                               # outputs to strout and stderr which both are replied on
                                                               # console where mcmd has been started from. And on log widget
                                                               # when enabled
        ['pwd',                  'pwd', 1],
        ['cat large',            'cat /var/log/monthly.out', 2],    # test which output a large file
        ['edit mcmd.rb',         "atom #{Dir.pwd}/mcmd.rb",  3],
        ['lscmd',                "ls",  0],
        ['lsarg',                "-la", 1],
    ]
}

class Spec
    def initialize debug
        @debug = debug
        puts "Spec.initialize " if @debug
    end

    def getVersion
        @cfgSpec[$specVersionKey]
    end

    def getButtonWidth
        @cfgSpec[$specButtonWidth]
    end

    def abortOnWrongSpecFileVersion
        if getVersion != $specVersion
            abort "Wrong specfile version. Is #{getVersion}, expected #{$specVersion}"
        end
    end

    def read aFileName
        puts "Spec.readSpec >#{aFileName}<" if @debug
        @filename = aFileName
        if !File.file? @filename
            #puts "conf dir = >#{File.expand_path('./', @filename)}<" if @debug
            abort "Cannot read file >#{@filename}<"
        end
        @cfgSpec = YAML.load_file @filename
        puts "Reading spec from >#{@filename}<" if @debug
        abortOnWrongSpecFileVersion
    end

    def write fileName, spec
        File.open(fileName, 'w') { |f| f.write spec.to_yaml }
        puts "Writing spec to >#{fileName}<" if @debug
    end

    def createDefaultFile filename
        puts "Spec.createDefaultSpecFile >#{filename}<" if @debug
        @filename = filename
        write @filename, $exampleSpec
        read @filename
    end

    def updateSpecFileOnDisk
        puts "updateSpecFileOnDisk #{@filename}" if @debug
        write @filename, @cfgSpec
    end

    def getBaseDir
        @cfgSpec[$specBaseDirKey]
    end

    def getEditor
        @cfgSpec[$specEditor]
    end

    def setBaseDir dir, write
        puts "setSpecBaseDir #{dir}" if @debug
        if @cfgSpec[$specBaseDirKey] != dir
            @cfgSpec[$specBaseDirKey] = dir
        end
        updateSpecFileOnDisk if write
    end

    def getColors
        @cfgSpec[$specColors]
    end

    def getColorGradientPercent
        @cfgSpec[$specColorGradientPercent]
    end

    def getCmds
        @cfgSpec[$specCommandKey]
    end

    def getCmdByIdx cmdIdx
        @cfgSpec[$specCommandKey][cmdIdx]
    end

    def getBtnTxtByIdx cmdIdx
        getCmdByIdx(cmdIdx)[0]
    end

    def getCmdTxtByIdx cmdIdx
        getCmdByIdx(cmdIdx)[1]
    end

    def getColorByIdx cmdIdx
        getCmdByIdx(cmdIdx)[2]
    end

    def number_or_nil(v)
        puts "number_or_nil #{v}" if @debug
        if v.class == Fixnum
            puts "number_or_nil is Fixnum" if @debug
            return v
        end
        num = v.to_i
        num if num.to_s == v    # return nil if v.to_i failed
    end

    def getColorResolvedByIdx cmdIdx
        color_index_or_hex_value = getCmdByIdx(cmdIdx)[2]
        puts "color_index_or_hex_value #{color_index_or_hex_value}" if @debug
        c = number_or_nil(color_index_or_hex_value)
        if c == nil
            puts "#{color_index_or_hex_value} is string" if @debug
            color_index_or_hex_value       # return hex string
        else
            puts "#{color_index_or_hex_value} is int" if @debug
            getColors[c]                    # return color index by number
        end
    end

    def setCmdBtnTxt cmdIdx, text, write
        puts "setSpecCommamdButtonText [#{cmdIdx}]=#{text}" if @debug
        if getCmdByIdx(cmdIdx)[0] != text
            getCmdByIdx(cmdIdx)[0] = text
        end
        updateSpecFileOnDisk if write
    end

    def setCmdTxt cmdIdx, text, write
        puts "setSpecCmdText [#{cmdIdx}]=#{text}" if @debug
        if getCmdByIdx(cmdIdx)[1] != text
            getCmdByIdx(cmdIdx)[1] = text
        end
        updateSpecFileOnDisk if write
    end

    def setColor cmdIdx, color, write
        puts "setSpecColor [#{cmdIdx}]=#{color}" if @debug
        if getCmdByIdx(cmdIdx)[2] != color
            getCmdByIdx(cmdIdx)[2] = color
        end
        updateSpecFileOnDisk if write
    end

    def to_s
        puts "Version: #{getVersion}"
        puts "BaseDir: #{getBaseDir}"
        puts "Commands"
        getCmds.size.times do |cmdIdx|
            puts "\tButtonText >#{getBtnTxtByIdx(cmdIdx)}<,\tCmdText >#{getCmdTxtByIdx(cmdIdx)}<"
        end
    end
end
