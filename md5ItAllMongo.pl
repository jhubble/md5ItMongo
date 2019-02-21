#!/usr/bin/perl

use Cwd;
use File::Find;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Digest::Nilsimsa;
use Image::Info qw(image_info image_type dim);
use File::stat;
use Data::Dumper;
use MongoDB;
use strict;
use warnings;
use Image::ExifTool;
use Data::Structure::Util qw( unbless );
use Archive::Tar;
use Archive::Zip;
use Archive::Extract;
my $exifTool = new Image::ExifTool;
$exifTool->Options('List');
my ($startdir) = @ARGV;
my $skipuntildir = '';
my $tmpdir = "/tmp/md5itTmp";
my $dir = getcwd;
use Cwd 'abs_path';
$startdir = abs_path($startdir);

## set go=0 and a startfile, and it will not do anything until it reaches the file
my $go = 1;
my $startfile = "/cygdrive/x/statements_work/creditcard/amex/blue/2012/Statement_Dec 2012.pdf";

## set skipuntildir to a directory, and it wont processes any directories until it gets to this one.
## (The pruning is generally much more efficient than the "go")
#$skipuntildir ="/cygdrive/y/C_/Users/jh/Downloads/algorithms";
#$skipuntildir ="/cygdrive/y/C_/Users/jh/Downloads/character/output";
#$skipuntildir = "/cygdrive/y/G_/Music/iTunes/iTunes Music/10,000 Maniacs/In My Tribe";
#$skipuntildir = "/cygdrive/w/all_cd_backup/cds/scans2005_17_01/scans/journal_misc";
#$skipuntildir = '/cygdrive/w/all_cd_backup/photocds2/Picasa CD/[I]/$My Pictures/2011/2011-12-26';
#$skipuntildir = '/cygdrive/w/all_cd_backup/photocds2/Picasa CD.017/$My Pictures/finalmonsters';
#$skipuntildir = '/cygdrive/w/all_cd_backup/photocds2/Picasa CD.017';

## force processing of zips (even if file already processed)
my $reprocessZips = 1;
if (!$startdir) {
	die "USAGE:\n$0 startdir\nWhere startdir is the directory to start walking\n".
	"Outputs list of file\tsize\tmd5\tnilsimsa\tcreatetime\tmodtime\timagedetails\n";
}
my $collection = initMongo();
find ({
	wanted =>  
        sub {
		print STDERR ".";
		my $file = $File::Find::name;
		print STDERR "=-->$file\n";
		if (-d $file) {
			return 1;
		}
		if ($go) {
			if ($reprocessZips && ($file =~ /\.zip$/i)) {
				## don't do mongo check if we do reprocess zips
			}
			elsif ($collection->count({fileName => $file})) {
				print STDERR "+";
				print "--".$file."\n";
				return 1;
			}
		}
		eval  {
		if ($go) {
			if (!-f $file) {
				print "Cannot open: $file\n";
				print STDERR "Cannot open: $file\n";
				return 1;
			}
			print STDERR "#";

			my $size = -s $file;
			print STDERR "$file\t$size\n";
			my $md5 = calculateMd5($file);
			print STDERR "+";
			my $nilsimsa = undef;
			## don't try to read files larger than half a gig
			if ($size < 500000000) {
				$nilsimsa = calculateNilsimsa($file);
			}
			print STDERR "%";
			my $imageData = getImageInfo($file);
			print  STDERR "-";
			my $imageInfo = $exifTool->ImageInfo($file);
			print STDERR "@";
			$imageInfo = fixKeys($imageInfo);
			print STDERR ">";
			$imageData = fixKeys($imageData);

			print STDERR "=";
			my $st = stat($file);
			my $statObj = {
				"size" => $st->size,
				"atime" => $st->atime,
				"mtime" => $st->mtime,
				"ctime" => $st->ctime
			};

			my $tarinfo = processTar($file);
			print STDERR "!";
			my $mongoData = {
				fileName => $file,
				md5 => $md5,
				nilsimsa => $nilsimsa,
				imageData => $imageData,
				imageInfo => $imageInfo,
				stat => $statObj,
				tarinfo => $tarinfo
			};

			print Dumper($mongoData);
			$collection->update({"fileName"=>$file},$mongoData, {"upsert"=>1});
				

			print STDERR "+";
			print "$file\t$size\t$md5\t$nilsimsa\t".localtime($st->ctime)."\t".localtime($st->mtime)."\n";
			if ($file =~ /\.zip$/i) {
				processZip($file,$tmpdir);
			}

		}
		else {
			#print STDERR $file," - x\n";
			## start at last known good file
			if ($file eq $startfile) {
				$go = 1;
			}
		}

		};
		if ($@) {
			print STDERR "OOF:",$@,"\n";
		}

		print "S";
                return 1;
        }, 

	preprocess => sub {
                my @files = @_;
		my $dir = $File::Find::dir;
                print STDERR "DIR: $dir\n";
		if ($skipuntildir && ($skipuntildir !~ /$dir/)) {
			print STDERR "skipping pruning: $skipuntildir !~ $dir\n";
			return [];
		}
		elsif ($dir eq $skipuntildir) {
			$skipuntildir = '';
		}
		if ($dir =~ /\$RECYCLE.BIN/) {
			print STDERR "skipping recycle\n";
			return [];
		}
		if ($dir =~ /RECYCLER/) {
			print STDERR "skipping recycle\n";
			return [];
		}
		print "DS:";
                return @files;
        }
	}, $startdir);


print "DONE\n";
print STDERR "DONE!\n";


sub calculateMd5 {
        my ($file) = @_;
        open FILE, $file or print STDERR '#$&^#%# office scan Cant open dim der file: '.$file."\n";
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
			return "__NO_IMAGE__";
		}
		elsif ($ft->{'file_type'} eq 'BMP') {
			return "__BMP__";
		}
	  	my $badTag = '';
	 	my $info = image_info($filename);
	 	if (my $error = $info->{error}) {
	     		die "Can't parse image info: $error\n";
	 	}
		# my ($w, $h) = dim($info);

		return $info;
	};
	if ($@) {
		print STDERR $@,"\n";
		return "__ERR__";
	}

	return $ret;
}

sub fixKeys {
	my ($lm) = @_;
	my $delnums = 0;
		
	if (ref $lm) {
		if (exists $lm->{'MIMEType'} && $lm->{'MIMEType'} eq 'application/xml') {
			print STDERR "XML -> removing tag data\n";
			$delnums = 1;
		}
		#print "LM:",ref $lm,"\n";
		foreach my $k (keys %$lm) {
			if ($delnums && ($k =~ /\d/)) {
				#print STDERR "deleting: $k\n";
				delete $lm->{$k};
				next;
			}
			#print "$k:",ref $lm->{$k},"\n";
			## remove scalar refs
			if (ref $lm->{$k} eq 'SCALAR') {
				$lm->{$k} = ${$lm->{$k}};
				#print "R2:",ref $lm->{$k},"\n";
			}
			my $oldref = ref $lm->{$k};
			## unbless object refs
			if ($oldref =~ m/:/) {
				unbless($lm->{$k});
				if (ref $lm->{$k} eq 'HASH') {
					$lm->{$k}{originalObjectType} = $oldref;
				}
				else {
					$lm->{$k} = {"originalObjectType" => $oldref,
							"data" => $lm->{$k}
							};
					#print "NOT HASH\n";
				}
				#print "NEWREF:",ref $lm->{$k},"\n";
			}
			## if we have refs nested in arrays, unbless them also
			if ($oldref eq 'ARRAY') {
				my @thing = @{$lm->{$k}};
				for (my $i=0;$i<=$#thing;$i++) {
					my $newRef2 = ref $thing[$i];
					if ($newRef2 =~ /:/) {
						print STDERR "unblessing\n";
						unbless($thing[$i]);
					}
				}
			}

			## change . to _
			if ($k =~ m/\./) {
				my $k2 = $k;
				$k2 =~ s/\./_/g;
				$lm->{$k2} = $lm->{$k};
				delete $lm->{$k};
				
			}

			## remove control characters
			if ($k =~ /[[:cntrl:]]/) {
				my $k2 = $k;
				$k2 =~ s/[[:cntrl:]]/_/g;
				$lm->{$k2} = $lm->{$k};
				delete $lm->{$k};
			}

			## max of 999 keys
			if ($k =~ /\(\d{3,}\)/) {
				delete $lm->{$k};
			}
					
		}
	}
	#print STDERR Dumper ($lm);	
	return $lm;
}

sub processTar {
	my ($file) = @_;

	my $tarinfo = '';
	eval {
		if ($file =~ /\.tgz|\.tar/i) {
			my $tar = Archive::Tar->new();
			$tar->read($file);
			my @fls = $tar->get_files;
			for (my $i=0;$i<=$#fls;$i++) {
				if (ref $fls[$i]) {
					delete $fls[$i]->{'data'};
					delete $fls[$i]->{'raw'};
				}
				unbless($fls[$i]);
			}
			$tarinfo = {"tarcontents"=>\@fls};
		}
	};

	if ($@) {
		print STDERR "TAR error",$@,"\n";
	}
	return $tarinfo;


}

sub initMongo {
    my $client     = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
    my $database   = $client->get_database( 'cds' );
    my $collection = $database->get_collection( 'fileData' );

    return $collection;
    my $id         = $collection->insert({ some => 'data' });
    my $data       = $collection->find_one({ _id => $id });
print "ID:$id, DATA:$data\n";

}


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

sub processZip {
	## TODO: check to see if processed yet, process contents if zip processed, but contents not
	## TODO: only process contents of zip if not processed (is a mongo check worth it?)
	## TODO: skip java zip files with all of their gorp
	## 
    my ($archive,$tmp) = @_;
	print STDERR "PROCESSING ZIP: $archive\n";
	unless ($tmp) {
		die "Need a tmp dir for archive analysis\n";
	}
    my $zip = Archive::Zip->new($archive);
    foreach my $file ($zip->members) {
	## skip directories or empty files
        next unless ($file->compressedSize);
        print $file->fileName."\n";
        my $fileName  = $file->fileName;
	$fileName =~ s|.+/||;
	my $subFileName = $archive."/".$fileName;
	print "NEW FNAME:",$subFileName;
	my $statObj = {
		"size" => $file->uncompressedSize,
		"mtime" => $file->lastModFileDateTime
	};
	my $filePath = $tmp."/".$fileName;
	my $mongoData;
	if ($file->isEncrypted) {
		$mongoData = {
			fileName => $subFileName,
			stat => $statObj,
			encryptedZip => 1
		}
	}
	else {
		$file->extractToFileNamed($filePath);
		if (!-e $filePath) {
			print STDERR "Unable to extract $filePath\n";
			next;
		}
		print STDERR "\n>>".$filePath;
		print ">>>EXTRACTED PATH:".$filePath."\n";
		my $md5 = calculateMd5($filePath);
		print STDERR "+";
		my $nilsimsa = undef;
		## don't try to read files larger than a gig
		if ($statObj->{'size'} < 1000000000) {
			$nilsimsa = calculateNilsimsa($filePath);
		}
		print STDERR "%";
		my $imageData = getImageInfo($filePath);
		print  STDERR "-";
		my $imageInfo = $exifTool->ImageInfo($filePath);
		print STDERR "@";
		$imageInfo = fixKeys($imageInfo);
		print STDERR ">";
		$imageData = fixKeys($imageData);
		$mongoData = {
			fileName => $subFileName,
			md5 => $md5,
			nilsimsa => $nilsimsa,
			imageData => $imageData,
			imageInfo => $imageInfo,
			stat => $statObj,
		};
	}

	print Dumper($mongoData);
	$collection->update({fileName => $subFileName}, $mongoData, {'upsert' => 1});
	unlink($filePath);			
    }
     print STDERR "--- done with zip\n";
}

