require 'java'

class OSCheck
    attr_reader :isMacOS
    attr_reader :isLinux
    attr_reader :isWindows

    def initialize debug
        @debug = debug
        os = java.lang.System.get_property 'os.name'

        #MacOS "x86_64-darwin13"
        puts "os: #{os}" if @debug


        @isMacOS   = os.include? 'Mac OS X'
        @isLinux   = os.include? 'linux'    # to be checked
        @isWindows = os.include? 'win'      # to be checked

        if !@isMacOS && !@isLinux  && !@isWindows
            errString = "Cannot determine OS type from unexpected string >#{RUBY_PLATFORM}<"
            puts errString
            raise TypeError, errString
        end
    end

end
