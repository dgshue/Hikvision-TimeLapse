#!/usr/bin/perl -
$script_name = "build_video.pl";
$script_version = "0.1";

#There are a number of sun heights to choose from. The default is -0.833 because this is what most countries use. Feel free to specify it if you need to. Here is the list of values to specify the sun height with:
#0 degrees
#Center of Sun's disk touches a mathematical horizon

#-0.25 degrees
#Sun's upper limb touches a mathematical horizon

#-0.583 degrees
#Center of Sun's disk touches the horizon; atmospheric refraction accounted for

#-0.833 degrees
#Sun's supper limb touches the horizon; atmospheric refraction accounted for

#-6 degrees
#Civil twilight (one can no longer read outside without artificial illumination)

#-12 degrees
#Nautical twilight (navigation using a sea horizon no longer possible)

#-15 degrees
#Amateur astronomical twilight (the sky is dark enough for most astronomical observations)

#-18 degrees
#Astronomical twilight (the sky is completely dark)

# Global variables
my $VERBOSE			= 0;
my $DEBUG			= 0;
my $RollingWindow	= 15;
my $Passes			= 2;
my @selectedFiles;
my $latitude		= +40.669443;
my $longitude		= -80.831500;
my $timezone		= 'America/New_York';


use feature "say";
use DateTime::Format::CLDR;
use DateTime::Event::Sunrise;
use Getopt::Long;
use File::Copy;
use Image::Magick;
use Data::Dumper;
use File::Type;
use Term::ProgressBar;
use Image::ExifTool qw(:Public);


#Define namespace and tag for luminance, to be used in the XMP files.
%Image::ExifTool::UserDefined::luminance = (
    GROUPS => { 0 => 'XMP', 1 => 'XMP-luminance', 2 => 'Image' },
    NAMESPACE => { 'luminance' => 'https://github.com/cyberang3l/timelapse-deflicker' }, #Sort of semi stable reference?
    WRITABLE => 'string',
    luminance => {}
);

%Image::ExifTool::UserDefined = (
    # new XMP namespaces (ie. XMP-xxx) must be added to the Main XMP table:
    'Image::ExifTool::XMP::Main' => {
        luminance => {
            SubDirectory => {
                TagTable => 'Image::ExifTool::UserDefined::luminance'
            },
        },
    }
);

Getopt::Long::Configure("bundling");

GetOptions(
	'h'	=> \$o_help,		'help'		=> \$o_help,
	's=s'	=> \$o_startDate,		'startDate=s'	=> \$o_startDate,
	'e=s'	=> \$o_endDate,		'endDate=s'		=> \$o_endDate,
	'x=s'	=> \$o_skip,	'skip=s'		=> \$o_skip,
	'w=s'	=> \$o_day,	'dayWeek=s'		=> \$o_day,
	'f'	=> \$o_deflicker,	'deflicker'		=> \$o_deflicker,
	'l'	=> \$o_sun,	'solar'		=> \$o_sun,
	'd'	=> \$o_debug,	'debug'		=> \$o_debug,
	'i=s'	=> \$inputDir,	'inputDir=s'		=> \$inputDir,
	'o=s'	=> \$outputDir,	'outputDir=s'		=> \$outputDirtDir
);

if(defined($o_debug)) {
	$DEBUG = 1;
}

if(defined($o_help)) {
	help(); 
	exit $ERRORS{'UNKNOWN'};
}

if(defined($o_version)) {
	version();
	exit $ERRORS{'UNKNOWN'};
}

if (not defined $inputDir) {
  die "Need input directory\n";
}

@selectedFiles = getDirFiles($inputDir);

if(defined($o_startDate) && defined($o_endDate)) {
	$startDate = parseDate($o_startDate);
	$endDate = parseDate($o_endDate);
	print "Running by Start-End date\n";
	#print "$inputDir\n";
	#print "$startDate\n";
	#print "$endDate\n";
	
	@selectedFiles = selectByDate($startDate, $endDate, \@selectedFiles)
}

if(defined($o_startDate) && (not defined $o_endDate)) {
	$startDate = parseDate($o_startDate);
	$endDate = '30000000000000';
	@selectedFiles = selectByDate($startDate, $endDate, \@selectedFiles)
}

if(defined($o_endDate) && (not defined $o_startDate)) {
	$startDate = '00000000000000';
	$endDate = parseDate($o_endDate);
	
	@selectedFiles = selectByDate($startDate, $endDate, \@selectedFiles)

}

if(defined($o_day)) {

	@selectedFiles = selectByDay($o_day, \@selectedFiles);

}

if(defined($o_sun)) {

	say "Filtering by Sunrise/Sunset";
	@selectedFiles = filterDaytime(\@selectedFiles);

}

if(defined($o_skip)) {

	@selectedFiles = skipByX($o_skip, \@selectedFiles);

}


if(defined($outputDir)) {
	my $fileCount = $#selectedFiles;
	#my $progress    = Term::ProgressBar->new( { count => $fileCount } );
	say "Copying $filecount file(s) to output folder.";
	$c = 0;
	for ($i = 0; $i < @selectedFiles; $i++) {
		$imageFile = $inputDir."\\".$selectedFiles[$i];
		$outputFile = $outputDir."\\".$c.".jpg";
		if (-s $imageFile > 0) {
			copy ($imageFile, $outputFile);
			#$progress->update( $i + 1 );
			$c = $c + 1;
		}
		
	}

}



if(defined($o_deflicker)) {
	# Create hash to hold luminance values.
	my %luminance;
	my $count = 0;
	my $prevfmt = "";
	my $max_entries;

	my $data_dir = $outputDir;
	opendir( DATA_DIR, $data_dir ) || die "Cannot open $data_dir\n";
	#Put list of files in the directory into an array:
	my @files = grep {/.jpg$/} readdir(DATA_DIR);
	#Assume that the files are named in dictionary sequence - they will be processed as such.
	@files = sort @files;
	
	if ( scalar @files != 0 ) {
	  foreach my $filename (@files) {
		$luminance{$count}{filename} = $outputDir."\\".$filename;
		$count++;
	  }
	}
	
	$max_entries = scalar( keys %luminance );

	if ( $max_entries < 2 ) { die "Cannot process less than two files.\n" }

	say "$max_entries image files to be processed.";
	say "Original luminance of Images is being calculated";
	#Determine luminance of each file and add to the hash.
	
	%luminance = luminance_det($max_entries, \%luminance);

	my $CurrentPass = 1;

	while ( $CurrentPass <= $Passes ) {
	  say "\n-------------- LUMINANCE SMOOTHING PASS $CurrentPass/$Passes --------------\n";
	  %luminance = new_luminance_calculation($max_entries, \%luminance);
	  $CurrentPass++;
	}

	say "\n\n-------------- CHANGING OF BRIGHTNESS WITH THE CALCULATED VALUES --------------\n";
	%luminance = luminance_change($max_entries, \%luminance);

	say "\n\nJob completed";
	say "$max_entries files have been processed";


}


sub filterDaytime {
	my @selectedFiles = @{$_[0]};
	my @filtselectedFiles;
	my $file;

	say "Running Filter: Sunrise/Sunset\n";	
	foreach $file (@selectedFiles) {
		if ($file =~ m/(\d{4})(\d{2})(\d{2})(\d{6})/) {
			my $year = $1;
			my $month = $2;
			my $day = $3;
			my $timestamp = $4;
			
			#say "$year $month $day $timestamp";
			
			# generating DateTime objects from a DateTime::Event::Sunrise object
			my $sun_Local = DateTime::Event::Sunrise->new(longitude => $longitude,
														   latitude  => $latitude,
														   altitude => '-6');

			my $imageDate = DateTime->new(year      => $year,
												month     =>    $month,
												day       =>   $day,
												time_zone => $timezone);
												

			
			#say "At $latitude/$longitude on ", $imageDate->ymd, " sunrise occurs at ", $sun_Local->sunrise_datetime($imageDate)->hms ," and sunset occurs at ", $sun_Local->sunset_datetime ($imageDate)->hms;
								
			$sunsetTime = $sun_Local->sunset_datetime($imageDate)->hms;
			$sunriseTime = $sun_Local->sunrise_datetime($imageDate)->hms;		
			$sunsetTime =~ tr/://d;
			$sunriseTime =~ tr/://d;
			
			#say "$sunriseTime $sunsetTime\n";
			
			if ($imageDate->is_dst()) {
				#say "Before: $sunriseTime $sunsetTime\n";
				$sunriseTime = substr('00' . ($sunriseTime - 10000), -6);
				$sunsetTime = substr('00' . ($sunsetTime - 10000), -6);
				#say "After: $sunriseTime $sunsetTime\n";
			}

			
			if ($timestamp >= $sunriseTime && $timestamp <= $sunsetTime) {
				#say "$file\n";
				push @filtselectedFiles, $file;
			}
		}
	}
	return @filtselectedFiles;


}


sub skipByX {
	my $skipBy = $_[0];
	my @selectedFiles = @{$_[1]};
	my @filtselectedFiles;
	print "Skip by: $skipBy\n";
	for ($i = 0; $i < @selectedFiles; $i += $skipBy) {
		push @filtselectedFiles, $selectedFiles[$i];
	}
	
	return @filtselectedFiles;
	
}


sub selectByDay {
	my $dayofweek = $_[0];
	my @selectedFiles = @{$_[1]};
	my @filtselectedFiles;
	
	@filtselectedFiles = grep {/image_(\d{14})\-[$dayofweek]\.jpg$/} @selectedFiles;
	
	return @filtselectedFiles;
	
}


sub selectByDate {

	my $startDateSeq = $_[0];
	my $endDateSeq = $_[1];
	my @selectedFiles = @{$_[2]};
	my @filtselectedFiles;
	my $file;

	print "Running: $startDateSeq - $endDateSeq\n";	
	foreach $file (@selectedFiles) {
		if ($file =~ m/(\d{14})/) {
			if ($1 >= $startDateSeq && $1 <= $endDateSeq) {
				push @filtselectedFiles, $file;
			}
		}
	}
	return @filtselectedFiles;
}



sub getDirFiles {
	my $inputDir = $_[0];
	say "$inputDir\n";
	opendir(DIR, $inputDir) or die $!;
	@files = grep {/image_(\d{14})\-[0-6]\.jpg$/} readdir(DIR);
	closedir(DIR);
	@files = sort {$a cmp $b} @files;
	
	return @files;
}


sub parseDate {
	my ($dateStr) = @_;
	my $cldr1 = new DateTime::Format::CLDR(
		pattern     => 'M/d/yyyy HH:mm',
	);
	
	my $dt1 = $cldr1->parse_datetime($dateStr);
	
	my $cldr2 = new DateTime::Format::CLDR(
		pattern     => 'yyyyMMddHHmmss',
	);
	
	return $cldr2->format_datetime($dt1);
}

#####################
# Helper routines

#Determine luminance of each image; add to hash.
sub luminance_det {
	my $max_entries = $_[0];
	my %luminance = %{$_[1]};
	
  my $progress    = Term::ProgressBar->new( { count => $max_entries } );

  for ( my $i = 0; $i < $max_entries; $i++ ) {
    verbose("Original luminance of Image $luminance{$i}{filename} is being processed...\n");
    
    #Create exifTool object for the image
    my $exifTool = new Image::ExifTool;
    my $exifinfo; #variable to hold info read from xmp file if present.

    #If there's already an xmp file for this filename, read it.
    if (-e $luminance{$i}{filename}.".xmp") { 
      $exifinfo = $exifTool->ImageInfo($luminance{$i}{filename}.".xmp");
      debug("Found xmp file: $luminance{$i}{filename}.xmp\n")
    }
    #Now, if it already has a luminance value, just use that:
    if ( length $$exifinfo{Luminance} ) {
      # Set it as the original and target value to start out with.
      $luminance{$i}{value} = $luminance{$i}{original} = $$exifinfo{Luminance};
      debug("Read luminance $$exifinfo{Luminance} from xmp file: $luminance{$i}{filename}.xmp\n")
    }
    else {
      #Create ImageMagick object for the image
      my $image = Image::Magick->new;
      #Evaluate the image using ImageMagick.
      $image->Read($luminance{$i}{filename});
      my @statistics = $image->Statistics();
      # Use the command "identify -verbose <some image file>" in order to see why $R, $G and $B
      # are read from the following index in the statistics array
      # This is the average R, G and B for the whole image.
      my $R          = @statistics[ ( 0 * 7 ) + 3 ];
      my $G          = @statistics[ ( 1 * 7 ) + 3 ];
      my $B          = @statistics[ ( 2 * 7 ) + 3 ];

      # We use the following formula to get the perceived luminance.
      # Set it as the original and target value to start out with.
      $luminance{$i}{value} = $luminance{$i}{original} = 0.299 * $R + 0.587 * $G + 0.114 * $B;

      #Write luminance info to an xmp file.
      #This is the xmp for the input file, so it contains the original luminance.
      $exifTool->SetNewValue(luminance => $luminance{$i}{original}); 
      #If there is already an xmp file, just update it:
      if (-e $luminance{$i}{filename}.".xmp") { 
        $exifTool->WriteInfo($luminance{$i}{filename} . ".xmp")
      }
      #Otherwise, create a new one:
      else {
        $exifTool->WriteInfo(undef, $luminance{$i}{filename} . ".xmp", 'XMP'); #Write the XMP file
      }
    }
    $progress->update( $i + 1 );
  }
  return %luminance;
}

sub new_luminance_calculation {
	my $max_entries = $_[0];
	my %luminance = %{$_[1]};
  my $progress    = Term::ProgressBar->new( { count => $max_entries } );
  my $low_window  = int( $RollingWindow / 2 );
  my $high_window = $RollingWindow - $low_window;

  for ( my $i = 0; $i < $max_entries; $i++ ) {
    my $sample_avg_count = 0;
    my $avg_lumi         = 0;
    for ( my $j = ( $i - $low_window ); $j < ( $i + $high_window ); $j++ ) {
      if ( $j >= 0 and $j < $max_entries ) {
        $sample_avg_count++;
        $avg_lumi += $luminance{$j}{value};
      }
    }
    $luminance{$i}{value} = $avg_lumi / $sample_avg_count;

    $progress->update( $i + 1 );
  }
  return %luminance;
}

sub luminance_change {
	my $max_entries = $_[0];
	my %luminance = %{$_[1]};
  my $progress = Term::ProgressBar->new( { count => $max_entries } );

  for ( my $i = 0; $i < $max_entries; $i++ ) {
    debug("Original luminance of $luminance{$i}{filename}: $luminance{$i}{original}\n");
    debug("Changed luminance of $luminance{$i}{filename}: $luminance{$i}{value}\n");

    my $brightness = ( 1 / ( $luminance{$i}{original} / $luminance{$i}{value} ) ) * 100;

    debug("Imagemagick will set brightness of $luminance{$i}{filename} to: $brightness\n");

    #if ( !-d "Deflickered" ) {
    #  mkdir("Deflickered") || die "Error creating directory: $!\n";
    #}
    #TODO: Create directory name with timestamp to avoid overwriting previous work.

    debug("Changing brightness of $luminance{$i}{filename} and saving to the destination directory...\n");
    my $image = Image::Magick->new;
    $image->Read( $luminance{$i}{filename} );

    $image->Mogrify( 'modulate', brightness => $brightness );

    $image->Write( $luminance{$i}{filename} );

    $progress->update( $i + 1 );
  }
  return %luminance;
}

sub help {
	version();
	usage();

	print <<HELP;
	-h, --help
   		print this help message
	-i, --inputDir=DIRECTORY OF IMAGES
	-s, --startDate=START DATE TO FILTER
	-e, --endDate=END DATE TO FILTER
	-sk, --skip=SKIP X PHOTO
	-d, --dayWeek=DAY OF WEEK (0=Sunday, 1-5=week days)
	-l, --solar (Select only from Sunrise to Sunset, don't forget to update Lat Lon and TimeZone)
	-f, --deflicker (An attempt to clean up the video))
	
	ex : 
	Images between Jan 1 and Feb 1 2016 skip every 5th image    : perl build_video.pl -i C:\Images -s 1/1/2016 00:00 -e 2/1/2016 00:00 -sk 5

HELP
}

sub usage {
	print "Usage: $0 -i directory -s xx/xx/xxxx -e xx/xx/xxxx -sk X \n";
}


sub version {
	print "$script_name v$script_version\n";
}

sub verbose {
  print $_[0] if ($VERBOSE);
}

sub debug {
  print $_[0] if ($DEBUG);
}