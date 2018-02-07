# Hikvision-TimeLapse
Tools for creating Time Lapse videos from Hikvision IP Cameras.

# extract_capture
exctract_capture.pl - Script will extract the JPGs and name them by capture date in this format:
image_YYYYMMDDHHMMSS-d.jpg -> d in this case is the Day of the week 0 = Sunday

Perl Module Requirements:
Date::Format

On the IP Camera itself, setup remote storage or use SD card. Don't forget to 'format' the storage location.  Depending on the storage size you will be left with a folder/file structure of:
datadir0
datadir0/index00p.bin <- Bianry file containing index of JPG including metadata and more importantly capture date.
datadir0/hiv00000.pic <- Bianry file containing collection of JPG files

Configure camera to scheudule Snapshot on interval and schedule as required.

Usage:
extract_capture.pl ../datadir0 ../output/images


# build_video
build_video.pl - Used to select JPG from the extract_catpure.pl to prepare in a format that can be injested by FFmpeg

Usage:
build_video.pl -i directory -s xx/xx/xxxx -e xx/xx/xxxx -sk X

-h, --help
-i, --inputDir=DIRECTORY OF IMAGES
-s, --startDate=START DATE TO FILTER
-e, --endDate=END DATE TO FILTER
-sk, --skip=SKIP X PHOTO
-d, --dayWeek=DAY OF WEEK (0=Sunday, 1-5=week days)
-l, --solar (Select only from Sunrise to Sunset, don't forget to update Lat Lon and TimeZone)
-f, --deflicker (An attempt to clean up the video))

Use FFmpeg to build your video.  See other tools.

# Full Example

extract_capture.pl \\server\share\datadir1 \\server\share\Output

build_video.pl -i \\server\share\Output -o \\server\share\\TimeLapse\Images -s "2/03/2016 00:00" -l -x 5

ffmpeg.exe -framerate 60 -i \\server\share\\TimeLapse\Images\%%d.jpg -c:v mjpeg -q:v 20 Ouput-Video.avi

Could be condesned into single script using FFmpeg perl module.
