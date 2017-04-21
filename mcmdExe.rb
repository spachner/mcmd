require 'test/unit'

class Exe
    def initialize debug
        @debug = debug
        puts "Exe.initialize " if @debug
    end

    def substitute str, vars
        if str == nil
            return ""
        end
        _str = str.clone # do not modify orig string
        search  = ""
        replace = ""
        vars.each do |s|
            search  = s[0] if s[0] != nil
            replace = s[1] if s[1] != nil
            puts "substitute before: replace variable named >#{search}< with >#{replace}< in >#{str}<: >#{_str}<" if @debug
            _str.gsub!(/\$\(#{search}\)/, replace)
            puts "substitute after : replace variable named >#{search}< with >#{replace}< in >#{str}<: >#{_str}<" if @debug
        end
        puts "substitute return: >#{_str}<" if @debug
        _str
    end

    def getCmdExecutable cmd
        exe = cmd.split[0]   # make from e.g. "ls -1" -> "ls"
        if exe.start_with?'./'
            exe = $spec.getBaseDir + '/' + exe
        end
        puts "getCmdExecutable >#{cmd}< is >#{exe}<" if $debug
        exe
    end

    def isCmdExecutable executable
        system "which #{executable} >> /dev/null"
    end

    def setLogCB cb
        @logCB = cb
    end

    def setExeCB cbRun, cbEndSuccess, cbEndError
        @exeRunCB = cbRun
        @exeSucCB = cbEndSuccess
        @exeErrCB = cbEndError
    end

    def logMessage str
        @logCB.call "********** #{str} ******\n"
    end

    def exeCmd cmd
        if @cmdActive
            @logCB.call "Other cmd active, ignored"
        else
            puts "exeCmd before var sub >#{cmd}<" if $debug
            cmd = $exe.substitute cmd, $spec.getCmds
            puts "exeCmd after  var sub >#{cmd}<" if $debug
            @cmdActive = true
            @exeRunCB.call
            @thread = Thread.new do
                Open3.popen2e(cmd, :chdir => $spec.getBaseDir) do
                    | stdin, stdout_and_stderr, wait_thr |
                    #stdin.close
                    prependStr = "pid #{wait_thr[:pid]}: "
                    stdout_and_stderr.each do |line|
                        @logCB.call prependStr + line
                    end
                    @exit_status = wait_thr.value.exitstatus
                end
                puts "success #{@exit_status}"
                if @exit_status == 0
                    logMessage 'Command finished with success'
                    @exeSucCB.call
                else
                    logMessage "Command finished with error"
                    @exeErrCB.call
                end
                @cmdActive = false
                @thread    = nil
            end
            # @thread.join # wait for end of thread
        end
    end

    def kill
        alive = @thread != nil && @thread.alive?
        if alive
            puts "Killing #{@thread}" if @debug
            Thread.kill @thread
            @thread    = nil
            @cmdActive = false
            @exeErrCB.call
            logMessage 'Command killed'
        else
            logMessage 'No command active to kill'
        end
    end
end

class MyTest < Test::Unit::TestCase
    @@testDebug = true
    def test_1
        assert_equal(2, 2)
        assert_not_same('2', '33')
    end

    def test_first_in_vars
        @exe = Exe.new @@testDebug
        inCmd = 'test1$(var1)'
        @vars = [
            ['var1', '2'],
            ['var2', 'abc'],
        ]
        outCmd = @exe.substitute inCmd, @vars
        assert_equal('test12', outCmd)
    end

    def test_last_in_vars
        @exe = Exe.new @@testDebug
        inCmd = 'test1$(var1)'
        @vars = [
            ['var3', '33'],
            ['var2', 'abc'],
            ['var1', '2'],
        ]
        outCmd = @exe.substitute inCmd, @vars
        assert_equal('test12', outCmd)
    end

    def test_orig_str_unmodified
        @exe = Exe.new @@testDebug
        inCmd = 'test1$(var1)'

        #1st replace
        @vars = [
            ['var1', '2'],
        ]
        outCmd = @exe.substitute inCmd, @vars
        assert_equal('test12', outCmd)

        assert_equal('test1$(var1)', inCmd)

        #2nd replace # test whether orig string is modified
        @vars = [
            ['var1', '3'],
        ]
        outCmd = @exe.substitute inCmd, @vars
        assert_equal('test13', outCmd)
    end

    def test_not_int_in_vars
        @exe = Exe.new @@testDebug
        inCmd = 'test1$(var4)'
        @vars = [
            ['var3', '33'],
            ['var2', 'abc'],
            ['var1', '2'],
        ]
        outCmd = @exe.substitute inCmd, @vars
        assert_equal('test1$(var4)', outCmd)
        assert_equal(inCmd, 'test1$(var4)') # test whether orig string is modified
    end

    def test_multiple_vars
        @exe = Exe.new @@testDebug
        inCmd = 'sta-$(var1)-$(var1)-$(var2)-end'
        @vars = [
            ['var1', '2'],
            ['var2', 'abc'],
        ]
        outCmd = @exe.substitute inCmd, @vars
        assert_equal('sta-2-2-abc-end', outCmd)
    end

    def test_replace_inplace
        @exe = Exe.new @@testDebug
        inCmd = 'sta-$(var1)-$(var1)-$(var2)-end'
        @vars = [
            ['var1', '2'],
            ['var2', 'abc'],
        ]
        inCmd = @exe.substitute inCmd, @vars
        assert_equal('sta-2-2-abc-end', inCmd)
    end

    def test_empty_string
        @exe = Exe.new @@testDebug
        inCmd = 'sta-$(var1)-$(var1)-$(var2)-end'
        @vars = [
            ['var1', ''],
            ['var2', ''],
        ]
        inCmd = @exe.substitute inCmd, @vars
        assert_equal('sta----end', inCmd)
    end

    def test_empty_string2
        @exe = Exe.new @@testDebug
        inCmd = 'sta-$(var1)-$(var1)-$(var2)-end'
        @vars = [
            ['', ''],
            ['', ''],
        ]
        inCmd = @exe.substitute inCmd, @vars
        assert_equal('sta-$(var1)-$(var1)-$(var2)-end', inCmd)
    end

end
