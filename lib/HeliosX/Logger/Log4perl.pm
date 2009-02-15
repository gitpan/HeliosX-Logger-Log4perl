package HeliosX::Logger::Log4perl;

use 5.008;
use base qw(HeliosX::Logger);
use strict;
use warnings;

use Log::Log4perl;

use HeliosX::LogEntry::Levels qw(:all);
use HeliosX::Logger::LoggingError;

our $VERSION = '0.02_0771';

=head1 NAME

HeliosX::Logger::Log4perl - HeliosX::Logger subclass implementing logging to Log4perl for Helios

=head1 SYNOPSIS

 # in your helios.ini
 loggers=HeliosX::Logger::Log4perl
 log4perl_conf=/path/to/log4perl.conf
 log4perl_category=logging.category
 log4perl_watch_interval=10
 
 # log4perl supports lots of options, so you can get creative
 # log everything to log4perl, but specify which services go to which categories
 [global]
 internal_logging=off
 loggers=HeliosX::Logger::Log4perl
 log4perl_conf=/etc/helios_log4perl.conf
 
 # log all the MyApp::* services to the same log4perl category 
 [MyApp::MetajobBurstService]
 log4perl_category=MyApp
 [MyApp::IndexerService]
 log4perl_category=MyApp
 [MyApp::ReportingService]
 log4perl_category=MyApp
 
 [YourApp]
 # we won't specify a category here, so Helios will default to category 'YourApp'

=head1 DESCRIPTION

This class extends the HeliosX::Logger class to provide a shim between HeliosX::ExtLoggerService 
and Log::Log4perl.  This allows Helios applications using HeliosX::ExtLoggerService to use 
Log4perl logging facilities.

For information about configuring Log4perl, see the L<Log::Log4perl> documentation.

=head1 HELIOS.INI CONFIGURATION

=head2 log4perl_conf [REQUIRED]

The location of the Log4perl configuration file.  This can be one conf file for all of your 
HeliosX::ExtLoggerService services (specified in the [global] section), or you can have 
different conf files for different services.  

See the Log4perl documentation for details about configuring Log4perl itself.

=head2 log4perl_category 

The Log4perl "category" to log messages for this service.  You can declare this only in the 
[global] section, which will cause all HeliosX::ExtLoggerService services to log to one 
category.  Or, you can declare it in the [global] section and in certain individual service 
sections, which will allow certain services to log to their own category but others to default
to the global one.  If not specified, the Log4perl category will default to the service 
name/jobtype (from getJobType()).

=head2 log4perl_watch_interval

If specified, Log4perl will reread the log4perl_conf file every specified number of seconds 
and update its configuration accordingly.  If this isn't specified, any changes to your conf file 
will require a service restart.

=head1 IMPLEMENTED METHODS

=head2 init($config, $jobType)

The init() method verifies log4perl_conf is set in helios.ini and can be read.  It then calls 
Log::Log4perl::init() or (if log4perl_watch_interval is set) Log::Log4perl::init_and_watch() to 
set up the Log4perl system for logging.

=cut

sub init {
    my $self = shift;
    my $config = $self->getConfig();

    unless ( defined($config->{log4perl_conf}) && (-r $config->{log4perl_conf}) ) {
        throw HeliosX::Logger::LoggingError('CONFIGURATION ERROR: log4perl_conf not defined');
    }
    
    if ( defined($config->{log4perl_watch_interval}) ) {
        Log::Log4perl::init_and_watch($config->{log4perl_conf}, $config->{log4perl_watch_interval});
    } else {
        Log::Log4perl::init($config->{log4perl_conf});
    }
    return 1;
}


=head2 logMsg($job, $priority_level, $message)

The logMsg() method logs the given message to the configured log4perl_category with the given 
$priority_level.

=head3 Priority Translation

Helios was originally developed using Sys::Syslog as its sole logging system.  It eventually 
developed its own internal logging subsystem, and HeliosX::ExtLoggingService and HeliosX::Logger 
are new developments to further modularize Helios's logging capabilities and make it useful 
in more environments.  Due to this history, however, the base Helios system and 
HeliosX::ExtLoggerService define 8 logging priorities versus Log4perl's 5.  
HeliosX::Logger::Log4perl translates on-the-fly several of the priority levels defined in 
HeliosX::LogEntry::Levels to Log4perl's levels:

 HeliosX::LogEntry::Levels  Log::Log4perl::Level
 LOG_EMERG                  $FATAL
 LOG_ALERT                  $FATAL
 LOG_CRIT                   $FATAL
 LOG_ERR                    $ERROR
 LOG_WARNING                $WARN
 LOG_NOTICE                 $INFO
 LOG_INFO                   $INFO
 LOG_DEBUG                  $DEBUG

=cut

sub logMsg {
    my $self = shift;
    my $job = shift;
    my $level = shift;
    my $msg = shift;
    my $config = $self->getConfig();
    my $logger;

    # has log4perl been initialized yet?
    unless ( Log::Log4perl->initialized() ) {
        $self->init();
    }

    # if a l4p category was specified, get a logger for it
    # otherwise, get a logger for the jobtype
    if ( defined($config->{log4perl_category}) ) {
        $logger = Log::Log4perl->get_logger($config->{log4perl_category});
    } else {
        $logger = Log::Log4perl->get_logger($self->getJobType());
    }   

    # assemble message from the parts we have
    $msg = $self->getJobType().' ('.$self->getHostname.') '.$msg;
    if ( defined($job) ) { $msg = 'Job:'.$job->getJobid().' '.$msg; }

    # we shouldn't have to do a level check, since 
    # HeliosX::ExtLoggerService->logMsg() will default the level to LOG_INFO
    # still, it can't hurt
    if ( defined($level) ) {
        SWITCH: {
            if ($level eq LOG_DEBUG) { $logger->debug($msg); last SWITCH; }
            if ($level eq LOG_INFO || $level eq LOG_NOTICE) { $logger->info($msg); last SWITCH; }
            if ($level eq LOG_WARNING) { $logger->warn($msg); last SWITCH; }
            if ($level eq LOG_ERR) { $logger->error($msg); last SWITCH; }
            if ($level eq LOG_CRIT || $level eq LOG_ALERT || $level eq LOG_EMERG) { 
                $logger->fatal($msg); 
                last SWITCH; 
            }
            throw HeliosX::Logger::LoggingError('Invalid log level '.$level);           
        }
    } else {
        # $level wasn't defined, so we'll default to INFO
        $logger->info($msg);
    }
    return 1;
}



1;
__END__


=head1 SEE ALSO

L<HeliosX::ExtLoggerService>, L<HeliosX::Logger>, L<Log::Log4perl>

=head1 AUTHOR

Andrew Johnson, E<lt>lajandy at cpan dotorgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Andrew Johnson

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 WARRANTY

This software comes with no warranty of any kind.

=cut
