#--- mcmd spec file handling

$specVersion    = 1      # Just in case the spec file format will change in future
$specVersionKey = 'version'
$specBaseDirKey = 'baseDir'
$specCommandKey = 'commands'

$exampleSpec = {
    $specVersionKey => $specVersion,
    $specBaseDirKey => Dir.pwd,
    $specCommandKey => [
        ['ls -1',           'ls -1'],                       # arguments (here '-1') as just added to command string
        ['ls -l',           'ls -l'],
        ['ls var arg',      '$(lscmd) $(lsarg)'],
        ['stdout err test', './testcmd.bash'],              # preceed command with './' when baseDir would be used,
                                                            # otherwise PATH is used to locate command. testcmd.bash
                                                            # outputs to strout and stderr which both are replied on
                                                            # console where mcmd has been started from. And on log widget
                                                            # when enabled
        ['pwd',             'pwd'],
        ['cat large',       'cat /var/log/monthly.out'],    # test which output a large file
        ['edit mcmd.rb',    "atom #{Dir.pwd}/mcmd.rb"],
        ['lscmd',           "ls"],
        ['lsarg',           "-la"],
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

    def setBaseDir dir, write
        puts "setSpecBaseDir #{dir}" if @debug
        if @cfgSpec[$specBaseDirKey] != dir
            @cfgSpec[$specBaseDirKey] = dir
        end
        updateSpecFileOnDisk if write
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
            puts "setCmdTxt executed -----------"
            getCmdByIdx(cmdIdx)[1] = text
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
