#!/usr/bin/perl

use Archive::Zip;
use Archive::Extract;
 use Data::Dumper;


my $file = "test.zip";
my $tmp = "/tmp/ziptest";

sub extractAll {
	my ($file,$tmp) = @_;
	 my $ae = Archive::Extract->new( archive => $file );
	 my $ok = $ae->extract( to => $tmp );

	print $ae->error();
	print "OK:$ok\n";
	 my $files = $ae->files;


	 foreach my $f (reverse sort @$files) {
		print "$f\n";
		if (-d "$tmp/$f") {
			rmdir "$tmp/$f";
		}
		else {
			## do something before deleting
			unlink ("$tmp/$f");
		}
	  }

}

sub unzip {
    my ($archive,$tmp) = @_;
    my $zip = Archive::Zip->new($archive);
    foreach my $file ($zip->members) {
	next unless ($file->compressedSize);
	print $file->fileName."\n";
	my $fileName  = $file->fileName;
	$fileName =~ s|.+/||;
	print Dumper($file),"\n";
        $file->extractToFileNamed($tmp."/".$fileName);
    }
##    croak "There was a problem extracting $want from $archive" unless (-e $dir.$want);
    return 1;
}

unzip ($file,$tmp);
