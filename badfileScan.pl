#!/usr/bin/perl

use Image::Info qw(image_info dim);
use Data::Dumper;
use File::stat;
use POSIX qw(strftime);

my $ifile = "badfiles.txt";

open FILELIST, "$ifile" ||  die "cannot open $ifile\n";

while (<FILELIST>) {
	chomp; 
	my ($tag,$filename,$more) = split("\t",$_);

	my $fsize = -s $filename;
	print "$filename, $fsize\n";
	if ($fsize <1000) {
		next;
	}
	my $st = stat($filename) or die "No $file: $!";;
	print "C:".localtime($st->ctime);
	print "  M:".localtime($st->mtime)."\n";
	eval {
	  my $badTag = '';
	 my $info = image_info($filename);
	 if (my $error = $info->{error}) {
	     die "Can't parse image info: $error\n";
	 }
	 if ($info->{'width'} < 400) {
		next;
	}
	if (!$info->{ImageDescription}) {
		 #print "$filename",Dumper($info);
		#last;
		 #print "$filename",Dumper($info);
		$badTag = "BADFILE(no desc)\t";
	}
	if (!$info->{DateTime}) {
		 #print "$filename",Dumper($info);
		#last;
		$badTag = "BADFILENOTIME\t";
	}
	 my ($w, $h) = dim($info);
	 print "W, $w - H; $h\n";	 

	 print $badTag.$filename,"\t$fsize\t",$info->{ImageDescription},"\t", $info->{DateTime},"\t",$info->{DateTimeOriginal},"\t",$info->{DateTimeDigitized},"\n";
	};
	if ($@) {
		my $fsize = -s $filename;
		print "BADFILE(error): $filename => $fsize\n";
	}

}

print "Done\n";
