require 'metasploit/framework/tcp/client'

module Metasploit
  module Framework
    module Telnet
      module Client
        include Metasploit::Framework::Tcp::Client
        include Msf::Auxiliary::Login

        attr_accessor :banner

        #
        # CONSTANTS
        #
        # Borrowing constants from Ruby's Net::Telnet class (ruby license)
        IAC   = 255.chr # "\377" # "\xff" # interpret as command
        DONT  = 254.chr # "\376" # "\xfe" # you are not to use option
        DO    = 253.chr # "\375" # "\xfd" # please, you use option
        WONT  = 252.chr # "\374" # "\xfc" # I won't use option
        WILL  = 251.chr # "\373" # "\xfb" # I will use option
        SB    = 250.chr # "\372" # "\xfa" # interpret as subnegotiation
        GA    = 249.chr # "\371" # "\xf9" # you may reverse the line
        EL    = 248.chr # "\370" # "\xf8" # erase the current line
        EC    = 247.chr # "\367" # "\xf7" # erase the current character
        AYT   = 246.chr # "\366" # "\xf6" # are you there
        AO    = 245.chr # "\365" # "\xf5" # abort output--but let prog finish
        IP    = 244.chr # "\364" # "\xf4" # interrupt process--permanently
        BREAK = 243.chr # "\363" # "\xf3" # break
        DM    = 242.chr # "\362" # "\xf2" # data mark--for connect. cleaning
        NOP   = 241.chr # "\361" # "\xf1" # nop
        SE    = 240.chr # "\360" # "\xf0" # end sub negotiation
        EOR   = 239.chr # "\357" # "\xef" # end of record (transparent mode)
        ABORT = 238.chr # "\356" # "\xee" # Abort process
        SUSP  = 237.chr # "\355" # "\xed" # Suspend process
        EOF   = 236.chr # "\354" # "\xec" # End of file
        SYNCH = 242.chr # "\362" # "\xf2" # for telfunc calls

        OPT_BINARY         =   0.chr # "\000" # "\x00" # Binary Transmission
        OPT_ECHO           =   1.chr # "\001" # "\x01" # Echo
        OPT_RCP            =   2.chr # "\002" # "\x02" # Reconnection
        OPT_SGA            =   3.chr # "\003" # "\x03" # Suppress Go Ahead
        OPT_NAMS           =   4.chr # "\004" # "\x04" # Approx Message Size Negotiation
        OPT_STATUS         =   5.chr # "\005" # "\x05" # Status
        OPT_TM             =   6.chr # "\006" # "\x06" # Timing Mark
        OPT_RCTE           =   7.chr # "\a"   # "\x07" # Remote Controlled Trans and Echo
        OPT_NAOL           =   8.chr # "\010" # "\x08" # Output Line Width
        OPT_NAOP           =   9.chr # "\t"   # "\x09" # Output Page Size
        OPT_NAOCRD         =  10.chr # "\n"   # "\x0a" # Output Carriage-Return Disposition
        OPT_NAOHTS         =  11.chr # "\v"   # "\x0b" # Output Horizontal Tab Stops
        OPT_NAOHTD         =  12.chr # "\f"   # "\x0c" # Output Horizontal Tab Disposition
        OPT_NAOFFD         =  13.chr # "\r"   # "\x0d" # Output Formfeed Disposition
        OPT_NAOVTS         =  14.chr # "\016" # "\x0e" # Output Vertical Tabstops
        OPT_NAOVTD         =  15.chr # "\017" # "\x0f" # Output Vertical Tab Disposition
        OPT_NAOLFD         =  16.chr # "\020" # "\x10" # Output Linefeed Disposition
        OPT_XASCII         =  17.chr # "\021" # "\x11" # Extended ASCII
        OPT_LOGOUT         =  18.chr # "\022" # "\x12" # Logout
        OPT_BM             =  19.chr # "\023" # "\x13" # Byte Macro
        OPT_DET            =  20.chr # "\024" # "\x14" # Data Entry Terminal
        OPT_SUPDUP         =  21.chr # "\025" # "\x15" # SUPDUP
        OPT_SUPDUPOUTPUT   =  22.chr # "\026" # "\x16" # SUPDUP Output
        OPT_SNDLOC         =  23.chr # "\027" # "\x17" # Send Location
        OPT_TTYPE          =  24.chr # "\030" # "\x18" # Terminal Type
        OPT_EOR            =  25.chr # "\031" # "\x19" # End of Record
        OPT_TUID           =  26.chr # "\032" # "\x1a" # TACACS User Identification
        OPT_OUTMRK         =  27.chr # "\e"   # "\x1b" # Output Marking
        OPT_TTYLOC         =  28.chr # "\034" # "\x1c" # Terminal Location Number
        OPT_3270REGIME     =  29.chr # "\035" # "\x1d" # Telnet 3270 Regime
        OPT_X3PAD          =  30.chr # "\036" # "\x1e" # X.3 PAD
        OPT_NAWS           =  31.chr # "\037" # "\x1f" # Negotiate About Window Size
        OPT_TSPEED         =  32.chr # " "    # "\x20" # Terminal Speed
        OPT_LFLOW          =  33.chr # "!"    # "\x21" # Remote Flow Control
        OPT_LINEMODE       =  34.chr # "\""   # "\x22" # Linemode
        OPT_XDISPLOC       =  35.chr # "#"    # "\x23" # X Display Location
        OPT_OLD_ENVIRON    =  36.chr # "$"    # "\x24" # Environment Option
        OPT_AUTHENTICATION =  37.chr # "%"    # "\x25" # Authentication Option
        OPT_ENCRYPT        =  38.chr # "&"    # "\x26" # Encryption Option
        OPT_NEW_ENVIRON    =  39.chr # "'"    # "\x27" # New Environment Option
        OPT_EXOPL          = 255.chr # "\377" # "\xff" # Extended-Options-List

        #
        # This method establishes an Telnet connection to host and port specified by
        # the RHOST and RPORT options, respectively.  After connecting, the banner
        # message is read in and stored in the 'banner' attribute. This method has the
        # benefit of handling telnet option negotiation.
        #
        def connect(global = true, verbose = true)
          @trace = ''
          @recvd = ''
          fd = super(global)

          self.banner = ''
          # Wait for a banner to arrive...
          begin
            Timeout.timeout(banner_timeout) do
              while(true)
                buff = recv(fd)
                self.banner << buff if buff
                if(self.banner =~ @login_regex or self.banner =~ @password_regex)
                  break
                elsif self.banner =~ @busy_regex
                  # It's about to drop connection anyway -- seen on HP JetDirect telnet server
                  break
                end
              end
            end
          rescue ::Timeout::Error
          end

          self.banner.strip!

          # Return the file descriptor to the caller
          fd
        end

        # Sometimes telnet servers start RSTing if you get them angry.
        # This is a short term fix; the problem is that we don't know
        # if it's going to reset forever, or just this time, or randomly.
        # A better solution is to get the socket connect to try again
        # with a little backoff.
        def connect_reset_safe
          begin
            connect
          rescue Rex::ConnectionRefused
            return :refused
          end
          return :connected
        end

        def recv(fd=self.sock, timeout=telnet_timeout)
          recv_telnet(fd, timeout.to_f)
        end

        #
        # Handle telnet option negotiation
        #
        # Appends to the @recvd buffer which is used to tell us whether we're at a
        # login prompt, a password prompt, or a working shell.
        #
        def recv_telnet(fd, timeout)

          data = ''

          begin
            data = fd.get_once(-1, timeout)
            return nil if not data or data.length == 0

            # combine CR+NULL into CR
            data.gsub!(/#{CR}#{NULL}/no, CR)

            # combine EOL into "\n"
            data.gsub!(/#{EOL}/no, "\n")

            data.gsub!(/#{IAC}(
          [#{IAC}#{AO}#{AYT}#{DM}#{IP}#{NOP}]|[#{DO}#{DONT}#{WILL}#{WONT}]
          [#{OPT_BINARY}-#{OPT_NEW_ENVIRON}#{OPT_EXOPL}]|#{SB}[^#{IAC}]*#{IAC}#{SE}
          )/xno) do
              m = $1

              if m == IAC
                IAC
              elsif m == AYT
                fd.write("YES" + EOL)
                ''
              elsif m[0,1] == DO
                if(m[1,1] == OPT_BINARY)
                  fd.write(IAC + WILL + OPT_BINARY)
                else
                  fd.write(IAC + WONT + m[1,1])
                end
                ''
              elsif m[0,1] == DONT
                fd.write(IAC + WONT + m[1,1])
                ''
              elsif m[0,1] == WILL
                if m[1,1] == OPT_BINARY
                  fd.write(IAC + DO + OPT_BINARY)
                  # Disable Echo
                elsif m[1,1] == OPT_ECHO
                  fd.write(IAC + DONT + OPT_ECHO)
                elsif m[1,1] == OPT_SGA
                  fd.write(IAC + DO + OPT_SGA)
                else
                  fd.write(IAC + DONT + m[1,1])
                end
                ''
              elsif m[0,1] == WONT
                fd.write(IAC + DONT + m[1,1])
                ''
              else
                ''
              end
            end

            @trace << data
            @recvd << data
            fd.flush

          rescue ::EOFError, ::Errno::EPIPE
          end

          data
        end

        #
        # Wrappers for getters
        #

        def banner_timeout
          raise NotImplementedError
        end

        def telnet_timeout
          raise NotImplementedError
        end

      end
    end
  end
end