#!/usr/bin/perl -w
#=================================================================================
# Demo script for reading Beaglebone UART
#=================================================================================
# Vers. Date      Comment
#---------------------------------------------------------------------------------
# 1.0   28/01/14  Creation
#=================================================================================
use Device::SerialPort qw( :PARAM :STAT 0.07 );

#---------------------------------------------------------------------------------
# Configuration for pH and ORP collection
my $dummy;
my $EOL="\r";     # this is the end of line for AtlasScientific stamps
$|=1;              

#=================================================================================
sub stampReadOutput() {
    my ($stamp,$timeout,$retry)=@_;
    
    if(!$timeout) { $timeout=1; }  # Defaulting timeout to 1s
    if(!$retry) { $retry=3; }      # Defaulting retry to 3

    my $output;                    # Serial output
    my $notFinished=1;             # Flag to know if we're done reading or not
    my $count=0;                   # Actual retry count

    # Until we're done or we are out if retry
    while($notFinished && $count < $retry) {
        my $startTime=time();
        
        # Until timeout expires or we're done
        while(time()-$startTime<$timeout && $notFinished) {
            my ($carRead, $readBuffer)=$stamp->read(1);      # Read 1 char 
            if($carRead) { $output=$output . $readBuffer; }  # Concatenating the results
            $notFinished = !($readBuffer=~/$EOL$/);          # Met EOL => we're done ! 
        }
    
        # Checking if we did get out properly
        if($output && !$notFinished) {
            $output =~ s/$EOL$//;     # Removing EOL
            print "[$count on $retry] Read buffer: $output\n";
        }
        # If not got out properly...
        else {
            print "[$count on $retry] Timeout while reading\n";
        }
        $count++;   # Increase retry count
    }
}

#=================================================================================
# catch signals and end the program if one is caught.
sub signalHandler {
    my $sig=shift;
    print "Received signal $sig, stopping...\n";
    exit 0;
}

#=================================================================================
my $pHPort;

# callback signal handler for signals.
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
$SIG{PIPE} = 'ignore';

# Let's try opening the serial port
$pHPort = new Device::SerialPort('/dev/ttyO1',$dummy) || die "Can't open serial port for pH\n";

# Configure it
$pHPort->databits(8);
$pHPort->baudrate(38400);
$pHPort->parity("none");
$pHPort->stopbits(1);

# Writing setting, if not, undef the variable
$pHPort->write_settings || undef $pHPort;

# Chacking we could write the settings
if(!defined $pHPort) {
   print "Could not write settings for serial port";
    $pHPort->close || print "Could not close serial port";
    die;
}

# Now, serial port shoud be up and running, let's try to communicate

# Sending some data through UART to the stamp
print "Sending command 'C' to enable continuous reading\n";
my $carWritten=$pHPort->write('C' . $EOL);
print "Wrote $carWritten bytes to port\n";

# If everything went ok, pH stamp should now blink  

# Now readind data every second
while(1) {
    &stampReadOutput($pHPort,3,3);
    sleep 1;
}

#=================================================================================
# do this stuff when exit() is called.
END {
    print "Sending command 'E' to exit continuous reading\n";
    my $carWritten=$pHPort->write('E' . $EOL);
    print "Wrote $carWritten bytes to port\n";
}