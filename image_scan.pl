#!/usr/bin/perl

use Image::Info qw(image_info dim);
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my %md5 = Digest::MD5->new();
my $ifile = "hub160jpeg.txt";

open FILELIST, "$ifile" ||  die "cannot open $ifile\n";

while (<FILELIST>) {
	my $filename = $_;
	chomp $filename;

	my $fsize = -s $filename;
	if ($fsize <1000) {
		next;
	}
	eval {
	  my $badTag = '';
	 my $info = image_info($filename);
	 if (my $error = $info->{error}) {
	     die "Can't parse image info: $error\n";
	 }
	if (!$info->{ImageDescription}) {
		 #print "$filename",Dumper($info);
		#last;
		$badTag = "BADFILE\t";
	}
	if (!$info->{DateTime}) {
		 #print "$filename",Dumper($info);
		#last;
		$badTag = "BADFILENOTIME\t";
	}
	 #my ($w, $h) = dim($info);
	 #print "W, $w - H; $h\n";	 

	if (!$badTag) {
	 my $md5 = calculateMd5($filename);
	 print $badTag.$filename,"\t$md5\t$fsize\t",$info->{ImageDescription},"\t", $info->{DateTime},"\t",$info->{DateTimeOriginal},"\t",$info->{DateTimeDigitized},"\n";
	}
	};
	if ($@) {
		my $fsize = -s $filename;
		print "BADFILE: $filename => $fsize\n";
	}

}

sub calculateMd5 {
	my ($file) = @_;
	open FILE, $file or die "Can't open dim der file: $file\n";
	binmode(FILE);
	my $digest = Digest::MD5->new->addfile(*FILE)->hexdigest;
	return $digest;
}	

print "Done\n";
