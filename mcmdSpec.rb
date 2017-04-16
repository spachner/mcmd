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

    def getSpecVersion
        @cfgSpec[$specVersionKey]
    end

    def abortOnWrongSpecFileVersion
        if getSpecVersion != $specVersion
            abort "Wrong specfile version. Is #{getSpecVersion}, expected #{$specVersion}"
        end
    end

    def readSpec aFileName
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

    def writeSpec fileName, spec
        File.open(fileName, 'w') { |f| f.write spec.to_yaml }
        puts "Writing spec to >#{fileName}<" if @debug
    end

    def createDefaultSpecFile filename
        puts "Spec.createDefaultSpecFile >#{filename}<" if @debug
        @filename = filename
        writeSpec @filename, $exampleSpec
        readSpec  @filename
    end

    def updateSpecFileOnDisk
        puts "updateSpecFileOnDisk #{@filename}" if @debug
        writeSpec @filename, @cfgSpec
    end

    def getSpecBaseDir
        @cfgSpec[$specBaseDirKey]
    end

    def setSpecBaseDir dir, write
        puts "setSpecBaseDir #{dir}" if @debug
        if @cfgSpec[$specBaseDirKey] != dir
            @cfgSpec[$specBaseDirKey] = dir
        end
        updateSpecFileOnDisk if write
    end

    def getSpecCmds
        @cfgSpec[$specCommandKey]
    end

    def getSpecCmdByIdx cmdIdx
        @cfgSpec[$specCommandKey][cmdIdx]
    end

    def getSpecButtonTextByIdx cmdIdx
        getSpecCmdByIdx(cmdIdx)[0]
    end

    def getSpecCmdTextByIdx cmdIdx
        getSpecCmdByIdx(cmdIdx)[1]
    end

    def setSpecCmdButtonText cmdIdx, text, write
        puts "setSpecCommamdButtonText [#{cmdIdx}]=#{text}" if @debug
        if getSpecCmdByIdx(cmdIdx)[0] != text
            getSpecCmdByIdx(cmdIdx)[0] = text
        end
        updateSpecFileOnDisk if write
    end

    def setSpecCmdText cmdIdx, text, write
        puts "setSpecCmdText [#{cmdIdx}]=#{text}" if @debug
        if getSpecCmdByIdx(cmdIdx)[1] != text
            puts "-------"
            getSpecCmdByIdx(cmdIdx)[1] = text
        end
        updateSpecFileOnDisk if write
    end

    def dumpSpec
        puts "Version: #{getSpecVersion}"
        puts "BaseDir: #{getSpecBaseDir}"
        puts "Commands"
        getSpecCmds.size.times do |cmdIdx|
            puts "\tButtonText >#{getSpecButtonTextByIdx(cmdIdx)}<,\tCmdText >#{getSpecCmdTextByIdx(cmdIdx)}<"
        end
    end
end
