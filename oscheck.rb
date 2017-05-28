class OSCheck
    attr_reader :isMacOS
    attr_reader :isLinux
    attr_reader :isWindows

    def initialize debug
        @debug = debug
        #MacOS "x86_64-darwin13"
        puts "RUBY_PLATFORM: #{RUBY_PLATFORM}" if @debug
        @isMacOS   = RUBY_PLATFORM.include? 'darwin'
        @isLinux   = RUBY_PLATFORM.include? 'linux'
        @isWindows = RUBY_PLATFORM.include? 'win'

        if !@isMacOS && !@isLinux  && !@isWindows
            errString = "Cannot determine OS type from unexpected string >#{RUBY_PLATFORM}<"
            puts errString
            raise TypeError, errString
        end
    end

end
