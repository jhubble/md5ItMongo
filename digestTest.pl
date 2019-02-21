#!/usr/bin/perl

use File::DirWalk;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Digest::Nilsimsa;
my $file = "/cygdrive/c/Users/jeremyh/photocds/jan082002/DVC00090.JPG";
print calculateNilsimsa($file);

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

