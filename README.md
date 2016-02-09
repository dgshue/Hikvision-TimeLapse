# Hikvision-TimeLapse
Tools for creating Time Lapse videos from Hikvision IP Cameras.

Perl Module Requirements:
Date::Format

On the IP Camera itself, setup remote storage or use SD card. Don't forget to 'format' the storage location.  Depending on the storage size you will be left with a folder/file structure of:
datadir0
datadir0/index00p.bin <- Bianry file containing index of JPG including metadata and more importantly capture date.
datadir0/hiv00000.pic <- Bianry file containing collection of JPG files

Configure camera to scheudule Snapshot on interval and schedule as required.

Usage:
extract_capture.pl ../datadir0 ../output/images

Script will extract the JPGs and name them by capture date in this format:
image_YYYYMMDDHHMMSS-d.jpg -> d in this case is the Day of the week 0 = Sunday

Use FFmpeg to build your video.  See other tools.
