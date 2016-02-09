#!/usr/bin/perl -

use Date::Format;

my ($inputDir, $outputDir) = @ARGV;

if (not defined $inputDir) {
  die "Need input directory\nUsage extract_capture.pl inputdir outputdir";
}

if (not defined $outputDir) {
  die "Need output directory\nUsage extract_capture.pl inputdir outputdir";
}

$headerSize = 2816;
$maxRecords = 4096;
$recordSize = 80;

open (FH,$inputDir . "/index00p.bin") or die;
 read (FH,$buffer,1280);
  #read (FH,$buffer,-s "index00.bin");

($modifyTimes, $version, $picFiles, $nextFileRecNo, $lastFileRecNo, $curFileRec, $unknown, $checksum) = unpack("Q1I1I1I1I1C1176C76I1",$buffer);
#print "$modifyTimes, $version, $picFiles, $nextFileRecNo, $lastFileRecNo, $curFileRec, $unknown, $checksum\n";

$currentpos = tell (FH);
$offset = $maxRecords * $recordSize;


for ($i=0; $i<$picFiles; $i++) {
	$newOffset = $headerSize + ($offset * $i);
	seek (FH, $newOffset, 0);
	$picFileName = "hiv" . sprintf("%05d", $i) . ".pic";
	print "PicFile: $picFileName at $newOffset\n";
	#<STDIN>;
	open (PF, $inputDir . "/" . $picFileName) or die;
	binmode(PF);
		
	for ($j=0; $j<$maxRecords; $j++) {
		$recordOffset = $newOffset + ($j * $recordSize); #get the next record location
		seek (FH, $recordOffset, 0); #Use seek to make sure we are at the right location, 'read' was occasionally jumping a byte
		$currentpos = tell (FH);
		read (FH,$buffer,80); #Read 80 bytes for the record
		#print "************$currentpos***************\n";
		#read (FH,$buffer,80);
		
		#($field1, $field2, $capDate, $field4, $field5, $field6, $field7, $field8, $field9, $field10, $startOffset, $endOffset, $field13, $field14, $field15, $field16) = unpack("I*",$buffer);
		($field1, $field2, $capDate, $field4, $field5, $field6, $field7, $field8, $field9, $field10, $startOffset, $endOffset, $field13, $field14, $field15, $field16) = unpack("I*",$buffer);
		$formatted_start_time = time2str("%C", $capDate, -0005);
		$fileDate = time2str("%Y%m%d%H%M%S", $capDate, -0005);
		$fileDayofWeek = time2str("%w", $capDate, -0005);
		
		#print "$currentpos: $field1, $field2, $capDate, $field4, $field5, $field6, $field7, $field8, $field9, $field10, $startOffset, $endOffset, $field13, $field14, $field15, $field16\n";
		
		if ($capDate > 0) {
				$jpegLength = ($endOffset - $startOffset);
				$fileSize = $jpegLength / 1024;
				$fileName = "image_${fileDate}-${fileDayofWeek}.jpg";
				
				unless (-e $outputDir."/".$fileName) {
					if ($jpegLength > 0) {
						seek (PF, $startOffset, 0);
						read (PF, $singlejpeg, $jpegLength) or die;
						if ($singlejpeg =~ /[^\0]/) {
							print "IMAGE ($currentpos): $formatted_start_time - ($startOffset - $endOffset) FILE SIZE: ". int($fileSize)." kb FILE DATE: $fileDate FILE NAME: $fileName\n";
							open (OUTFILE, ">". $outputDir."/".$fileName);
							binmode(OUTFILE);
							print OUTFILE ${singlejpeg};
							close OUTFILE;
						}
						
					}
				}
				
				
		}
		
	}
	
	close (PF);
}


close FH;