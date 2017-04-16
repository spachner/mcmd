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
