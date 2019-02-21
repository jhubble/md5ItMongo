#!/usr/bin/perl

use File::DirWalk;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Digest::Nilsimsa;
use Image::Info qw(image_info image_type dim);
use File::stat;
use Data::Dumper;

my ($startdir) = @ARGV;

if (!$startdir) {
	die "USAGE:\n$0 startdir\nWhere startdir is the directory to start walking\n".
	"Outputs list of file\tsize\tmd5\tnilsimsa\tcreatetime\tmodtime\timagedetails\n";
}
my $go = 1;
my $dw = new File::DirWalk;
        $dw->onFile(sub {
		print STDERR ".";
		my ($file) = @_;
		if ($go) {
			if (!-f $file) {
				print "Cannot open: $file";
				return;
			}
			print STDERR "#";
			my $st = stat($file);
			#print "C:".localtime($st->ctime);
			#print "  M:".localtime($st->mtime)."\n";

			my $size = -s $file;
			print STDERR "$file\t$size\n";
			my $md5 = calculateMd5($file);
			print STDERR "+";
			my $nilsimsa = calculateNilsimsa($file);
			print STDERR "+";
			my $imageData = getImageInfo($file);
			print STDERR "+";
			print "$file\t$size\t$md5\t$nilsimsa\t".localtime($st->ctime)."\t".localtime($st->mtime)."\t$imageData\n";
		}
		else {
			print STDERR $file," - x\n";
			## start at last known good file
			if ($file eq '/cygdrive/e/old40GBdrive/software/linux/pax_2.2.beta5.tar.gz') {
				$go = 1;
			}
		}

                return File::DirWalk::SUCCESS;
        });

        $dw->walk("$startdir");



sub calculateMd5 {
        my ($file) = @_;
        open FILE, $file or print STDERR '#$&^#%# office scan Cant open dim der file: $file'."\n";
        binmode(FILE);
        my $digest = Digest::MD5->new->addfile(*FILE)->hexdigest;
        return $digest;
}


sub calculateNilsimsa {
        my ($file) = @_;

	my $data;
	{
	    open my $input_handle, '<', $file or die "Cannot open $file for reading: $!\n";
	    binmode $input_handle;
	    local $/;
	    $data = <$input_handle>;
	    close $input_handle;
	}

        my $digest = Digest::Nilsimsa->new->text2digest($data);
        return $digest;
}

sub getImageInfo {
	my ($filename) = @_;
	my $ret = eval {
		my $ft = image_type($filename);
		if (!exists $ft->{'file_type'}) {
			return "__NO_IMAGE__\t\t\t\t\t";
		}
		elsif ($ft->{'file_type'} eq 'BMP') {
			return "__BMP__\t\t\t\t\t";
		}
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
		 my ($w, $h) = dim($info);

		print STDERR "-";
		 my $infs = $info->{ImageDescription}."\t". $info->{DateTime}."\t".$info->{DateTimeOriginal}."\t".$info->{DateTimeDigitized}."\t$w\t$h";
		#print STDERR $infs;
		return $infs;
	};
	if ($@) {
		print STDERR $@,"\n";
		return "__NONE__\t\t\t\t\t";
	}

	#return "__NONE__\t\t\t\t\t";
	return $ret;
}

