#!/usr/bin/perl
use strict;
use warnings;
use File::Copy;
use File::Basename;
use File::Path qw(make_path);
use Getopt::Long;
use Cwd 'abs_path';
use Digest::MD5;

# Version
our $VERSION = "2.0.1";

# Configuration
my $backup_root = $ENV{HOME} . "/.butr";

# Command line options
my $help = 0;
my $backup = 0;
my $recover = 0;
my $version = 0;

# Get command line options
GetOptions(
    "help|h" => \$help,
    "backup|b" => \$backup,
    "recover|r" => \$recover,
    "version|v" => \$version
) or die "Error in command line arguments\n";

# Show help
if ($help) {
    show_help();
    exit 0;
}

# Show version
if ($version) {
    print "butr version $VERSION\n";
    exit 0;
}

# Ensure we have a source file
if (!@ARGV) {
    die "Error: No source file specified\n";
}

my $source_file = abs_path($ARGV[0]);

# Create backup root directory if it doesn't exist
unless (-d $backup_root) {
    make_path($backup_root, { mode => 0700 }) or die "Cannot create backup directory: $!\n";
}

# Main operation
if ($backup) {
    backup_file($source_file);
} elsif ($recover) {
    recover_file($source_file);
} else {
    die "Error: Must specify either -b (backup) or -r (recover)\n";
}

# Get backup directory for a file
sub get_backup_dir {
    my ($source) = @_;
    my $abs_path = abs_path($source);
    my $rel_path = $abs_path;
    
    # Remove leading / from absolute path
    $rel_path =~ s/^\///;
    
    # Create backup directory path
    my $backup_dir = "$backup_root/$rel_path";
    $backup_dir =~ s/\/[^\/]+$//; # Remove filename
    
    return $backup_dir;
}

# Calculate MD5 hash of a file
sub get_file_hash {
    my ($filename) = @_;
    my $md5 = Digest::MD5->new;
    open(my $fh, '<', $filename) or die "Cannot open file: $!\n";
    binmode($fh);
    $md5->addfile($fh);
    close($fh);
    return $md5->hexdigest;
}

# Get latest backup file if exists
sub get_latest_backup {
    my ($source) = @_;
    my $backup_dir = get_backup_dir($source);
    my ($name, undef, $suffix) = fileparse($source, qr/\.[^.]*$/);
    my $pattern = "$backup_dir/$name$suffix.butr.*";
    my @backups = glob($pattern);
    
    return undef if @backups == 0;
    
    # Sort by version number (newest first)
    @backups = sort {
        my ($ver_a) = $a =~ /\.v(\d+)\./;
        my ($ver_b) = $b =~ /\.v(\d+)\./;
        $ver_b <=> $ver_a;
    } @backups;
    
    return $backups[0];
}

# Get next version number for a file
sub get_next_version {
    my ($source) = @_;
    my $backup_dir = get_backup_dir($source);
    my ($name, undef, $suffix) = fileparse($source, qr/\.[^.]*$/);
    my $pattern = "$backup_dir/$name$suffix.butr.*";
    my @existing_backups = glob($pattern);
    
    my $max_version = 0;
    foreach my $backup (@existing_backups) {
        if ($backup =~ /\.v(\d+)\./) {
            $max_version = $1 if $1 > $max_version;
        }
    }
    
    return $max_version + 1;
}

# Backup function
sub backup_file {
    my ($source) = @_;
    
    # Check if source file exists
    die "Error: Source file '$source' does not exist\n" unless -f $source;
    
    # Get backup directory and create if needed
    my $backup_dir = get_backup_dir($source);
    unless (-d $backup_dir) {
        make_path($backup_dir, { mode => 0700 }) or die "Cannot create backup directory: $!\n";
    }
    
    # Get file information
    my ($name, undef, $suffix) = fileparse($source, qr/\.[^.]*$/);
    
    # Check if there's an existing backup
    my $latest_backup = get_latest_backup($source);
    
    # If there's a previous backup, compare contents
    if ($latest_backup) {
        my $source_hash = get_file_hash($source);
        my $backup_hash = get_file_hash($latest_backup);
        
        if ($source_hash eq $backup_hash) {
            print "No backup created: File is identical to latest backup '$latest_backup'\n";
            return;
        }
    }
    
    my $timestamp = get_timestamp();
    my $version = get_next_version($source);
    
    # Create backup filename (backup_dir/filename.ext.butr.v1.YYYYMMDD_HHMMSS)
    my $backup_file = sprintf("%s/%s%s.butr.v%d.%s", 
        $backup_dir, $name, $suffix, $version, $timestamp);
    
    # Perform backup
    copy($source, $backup_file) or die "Backup failed: $!\n";
    print "Successfully backed up '$source' to '$backup_file'\n";
}

# Recovery function
sub recover_file {
    my ($source) = @_;
    
    # Get backup directory
    my $backup_dir = get_backup_dir($source);
    my ($name, undef, $suffix) = fileparse($source, qr/\.[^.]*$/);
    
    # Find all backups for this file
    my $backup_pattern = "$backup_dir/$name$suffix.butr.*";
    my @backups = glob($backup_pattern);
    
    if (@backups == 0) {
        die "Error: No backups found for '$source'\n";
    }
    
    # Sort backups by version number (newest first)
    @backups = sort {
        my ($ver_a) = $a =~ /\.v(\d+)\./;
        my ($ver_b) = $b =~ /\.v(\d+)\./;
        $ver_b <=> $ver_a;
    } @backups;
    
    # Show available backups
    print "Available backups:\n";
    for (my $i = 0; $i < @backups; $i++) {
        my $backup_time = (stat($backups[$i]))[9];
        my ($sec,$min,$hour,$mday,$mon,$year) = localtime($backup_time);
        my ($version) = $backups[$i] =~ /\.v(\d+)\./;
        printf("%d: %s (Version %d, %04d-%02d-%02d %02d:%02d:%02d)\n",
            $i + 1,
            basename($backups[$i]),
            $version,
            $year + 1900, $mon + 1, $mday,
            $hour, $min, $sec);
    }
    
    # Let user select which backup to recover
    print "\nEnter backup number to recover (1-" . scalar(@backups) . ") [1]: ";
    my $choice = <STDIN>;
    chomp($choice);
    $choice = 1 if $choice eq "";
    
    if ($choice < 1 || $choice > @backups) {
        die "Error: Invalid backup number\n";
    }
    
    my $selected_backup = $backups[$choice - 1];
    
    # If current file exists, create a backup before recovery
    if (-f $source) {
        print "Creating backup of current file before recovery...\n";
        backup_file($source);
    }
    
    # Perform recovery
    copy($selected_backup, $source) or die "Recovery failed: $!\n";
    print "Successfully recovered '$source' from '$selected_backup'\n";
}

# Helper function to get timestamp
sub get_timestamp {
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
    return sprintf("%04d%02d%02d_%02d%02d%02d",
        $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
}

# Help function
sub show_help {
    print <<'END_HELP';
butr - Backup and Recovery Tool

Usage:
    butr -b <source_file>    Backup a file
    butr -r <source_file>    Recover a file
    butr -h                  Show this help message
    butr -v                  Show version

Options:
    -b, --backup            Backup mode
    -r, --recover          Recovery mode
    -h, --help             Show this help message
    -v, --version          Show version

Example:
    butr -b /path/to/document.txt    # Creates backup in ~/.butr/path/to/
    butr -r /path/to/document.txt    # Recovers from selected backup version

Notes:
    - All backups are stored in ~/.butr, maintaining original path structure
    - The backup directory is hidden and restricted to owner access (700)
    - Backup files use the format: filename.ext.butr.vN.YYYYMMDD_HHMMSS
      where N is an incrementing version number
    - Only creates new backups when file content has changed
    - Automatically backs up current file before recovery
    - Recovery shows all available backups with versions and lets you choose
END_HELP
}
